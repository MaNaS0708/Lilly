package com.example.lilly
import android.app.ActivityManager
import android.app.NotificationManager
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.ExperimentalApi
import com.google.ai.edge.litertlm.LogSeverity
import com.google.ai.edge.litertlm.Message
import com.google.ai.edge.litertlm.MessageCallback
import com.google.ai.edge.litertlm.SamplerConfig
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors


class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "Lilly"

        init {
            try {
                System.loadLibrary("litertlm_jni")
            } catch (_: UnsatisfiedLinkError) {
                // surfaced later as readable initialization failure
            }
        }
    }

    private val modelChannelName = "lilly/model"
    private val modelStreamChannelName = "lilly/model_stream"
    private val triggerChannelName = "lilly/trigger"

    private val mainHandler = Handler(Looper.getMainLooper())
    private val modelExecutor = Executors.newSingleThreadExecutor()
    private val maxModelTokens = 1024
    private val maxInferenceImageDimension = 768
    private val maxModelImages = 1

    private data class BackendPlan(
        val name: String,
        val backend: Backend,
        val visionBackend: Backend?,
        val audioBackend: Backend?,
    )

    private var engine: Engine? = null
    private var modelReady = false
    private var modelLoading = false
    private var modelPath: String? = null
    private var modelError: String? = null
    private var activeBackend: String = "uninitialized"
    private var modelEventSink: EventChannel.EventSink? = null
    private val pendingModelEvents = mutableListOf<Map<String, Any?>>()
    private var activeConversation: ConversationHandle? = null
    private var pendingLaunchAction: String? = null

    private data class ConversationHandle(
        val id: String,
        val conversation: com.google.ai.edge.litertlm.Conversation,
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        updatePendingLaunchAction(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        updatePendingLaunchAction(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, modelChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initializeModel" -> {
                        val path = call.argument<String>("modelPath")
                        initializeModel(path, result)
                    }

                    "getModelStatus" -> {
                        val status = when {
                            modelLoading -> "loading"
                            modelReady -> "ready"
                            modelError != null -> "error"
                            else -> "uninitialized"
                        }

                        result.success(
                            mapOf(
                                "status" to status,
                                "backend" to activeBackend,
                                "errorMessage" to modelError,
                            )
                        )
                    }

                    "disposeModel" -> {
                        disposeModel()
                        result.success(null)
                    }

                    "generateResponse" -> {
                        val prompt = call.argument<String>("prompt").orEmpty()
                        val imagePath = call.argument<String>("imagePath")
                        val conversationId = call.argument<String>("conversationId")
                        val history = call.argument<List<*>>("history")
                        generateResponse(prompt, imagePath, conversationId, history, result)
                    }

                    "generateResponseStream" -> {
                        val requestId = call.argument<String>("requestId").orEmpty()
                        val prompt = call.argument<String>("prompt").orEmpty()
                        val imagePath = call.argument<String>("imagePath")
                        val conversationId = call.argument<String>("conversationId")
                        val history = call.argument<List<*>>("history")
                        generateResponseStream(
                            requestId,
                            prompt,
                            imagePath,
                            conversationId,
                            history,
                            result,
                        )
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, modelStreamChannelName)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        modelEventSink = events
                        if (events != null && pendingModelEvents.isNotEmpty()) {
                            pendingModelEvents.forEach { events.success(it) }
                            pendingModelEvents.clear()
                        }
                    }

                    override fun onCancel(arguments: Any?) {
                        modelEventSink = null
                    }
                }
            )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, triggerChannelName)
            .setMethodCallHandler { call, result ->
                val preferences = TriggerPreferences(this)

                when (call.method) {
                    "getTriggerCapabilities" -> {
                        val wakeWordReady = WakeWordConstants.isWakeWordReady(filesDir)

                        result.success(
                            mapOf(
                                "platformSupported" to true,
                                "backgroundServiceSupported" to true,
                                "wakeWordReady" to wakeWordReady,
                                "notificationPermissionRecommended" to (Build.VERSION.SDK_INT >= 33),
                                "microphonePermissionRecommended" to true,
                                "isRunning" to LillyTriggerService.isRunning,
                                "autostartEnabled" to preferences.isAutostartEnabled(),
                                "notes" to if (wakeWordReady) {
                                    "Say \"Hey Lilly\" to open Lilly directly in voice chat. While voice chat is active, the wake-word microphone is paused automatically and resumes when voice chat stops."
                                } else {
                                    "Say \"Hey Lilly\" to open Lilly directly in voice chat. The first time you enable the trigger, Lilly downloads the wake-word model automatically and then starts listening."
                                },
                            )
                        )
                    }

                    "getTriggerStatus" -> {
                        result.success(
                            mapOf(
                                "isRunning" to LillyTriggerService.isRunning,
                            )
                        )
                    }

                    "setTriggerAutostart" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        preferences.setAutostartEnabled(enabled)
                        result.success(
                            mapOf(
                                "success" to true,
                                "enabled" to enabled,
                            )
                        )
                    }

                    "consumePendingLaunchAction" -> {
                        val action = pendingLaunchAction
                        pendingLaunchAction = null
                        result.success(mapOf("action" to action))
                    }

                    "startTriggerService" -> {
                        try {
                            preferences.setAutostartEnabled(true)
                            val intent = Intent(this, LillyTriggerService::class.java)
                            ContextCompat.startForegroundService(this, intent)
                            result.success(mapOf("success" to true))
                        } catch (e: Exception) {
                            result.success(
                                mapOf(
                                    "success" to false,
                                    "errorMessage" to (e.message ?: "Failed to start trigger service."),
                                )
                            )
                        }
                    }

                    "stopTriggerService" -> {
                        try {
                            preferences.setAutostartEnabled(false)
                            val intent = Intent(this, LillyTriggerService::class.java)
                            stopService(intent)
                            result.success(mapOf("success" to true))
                        } catch (e: Exception) {
                            result.success(
                                mapOf(
                                    "success" to false,
                                    "errorMessage" to (e.message ?: "Failed to stop trigger service."),
                                )
                            )
                        }
                    }

                    "pauseTriggerForVoiceChat" -> {
                        try {
                            val intent = Intent(this, LillyTriggerService::class.java).apply {
                                action = LillyTriggerService.ACTION_PAUSE_FOR_VOICE_CHAT
                            }
                            ContextCompat.startForegroundService(this, intent)
                            result.success(mapOf("success" to true))
                        } catch (e: Exception) {
                            result.success(
                                mapOf(
                                    "success" to false,
                                    "errorMessage" to (e.message ?: "Failed to pause trigger service."),
                                )
                            )
                        }
                    }

                    "resumeTriggerAfterVoiceChat" -> {
                        try {
                            val intent = Intent(this, LillyTriggerService::class.java).apply {
                                action = LillyTriggerService.ACTION_RESUME_AFTER_VOICE_CHAT
                            }
                            ContextCompat.startForegroundService(this, intent)
                            result.success(mapOf("success" to true))
                        } catch (e: Exception) {
                            result.success(
                                mapOf(
                                    "success" to false,
                                    "errorMessage" to (e.message ?: "Failed to resume trigger service."),
                                )
                            )
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun updatePendingLaunchAction(intent: Intent?) {
        pendingLaunchAction = when {
            intent?.getBooleanExtra("open_voice_chat", false) == true -> "voice_chat"
            intent?.getBooleanExtra("open_app_only", false) == true -> "open_app"
            else -> pendingLaunchAction
        }
    }

    private fun initializeModel(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            modelReady = false
            modelLoading = false
            modelPath = null
            modelError = "No model path was provided."
            result.success(
                mapOf(
                    "success" to false,
                    "status" to "error",
                    "errorMessage" to modelError,
                )
            )
            return
        }

        if (!path.endsWith(".litertlm")) {
            modelReady = false
            modelLoading = false
            modelPath = null
            modelError = "Gemma 4 in Lilly requires a .litertlm model file."
            result.success(
                mapOf(
                    "success" to false,
                    "status" to "error",
                    "errorMessage" to modelError,
                )
            )
            return
        }

        val file = File(path)
        if (!file.exists()) {
            modelReady = false
            modelLoading = false
            modelPath = null
            modelError = "Model file not found at: $path"
            result.success(
                mapOf(
                    "success" to false,
                    "status" to "error",
                    "errorMessage" to modelError,
                )
            )
            return
        }

        if (file.length() <= 0L) {
            modelReady = false
            modelLoading = false
            modelPath = null
            modelError = "Model file is empty or invalid."
            result.success(
                mapOf(
                    "success" to false,
                    "status" to "error",
                    "errorMessage" to modelError,
                )
            )
            return
        }

        val selectedPlans = backendPlansForModel(file)

        if (modelReady && modelPath == path && engine != null) {
            result.success(
                mapOf(
                    "success" to true,
                    "status" to "ready",
                    "errorMessage" to null,
                )
            )
            return
        }

        modelReady = false
        modelLoading = true
        modelError = null
        modelPath = path
        activeBackend = "initializing"

        modelExecutor.execute {
            try {
                ensureNativeLibraryLoaded()
                closeEngine()
                Engine.setNativeMinLogSeverity(LogSeverity.ERROR)

                val initialized = createEngine(path, selectedPlans)
                engine = initialized.first
                activeBackend = initialized.second

                modelReady = true
                modelLoading = false
                modelError = null

                postResult(
                    result,
                    mapOf(
                        "success" to true,
                        "status" to "ready",
                        "errorMessage" to null,
                    )
                )
            } catch (e: Exception) {
                closeEngine()
                modelReady = false
                modelLoading = false
                modelPath = null
                activeBackend = "failed"
                modelError = buildInitializationErrorMessage(e, selectedPlans)

                postResult(
                    result,
                    mapOf(
                        "success" to false,
                        "status" to "error",
                        "errorMessage" to modelError,
                    )
                )
            }
        }
    }

    private fun ensureNativeLibraryLoaded() {
        try {
            System.loadLibrary("litertlm_jni")
        } catch (e: UnsatisfiedLinkError) {
            throw Exception(
                "LiteRT-LM native library could not be loaded on this device: ${e.message}"
            )
        }
    }

    private fun createEngine(
        path: String,
        plans: List<BackendPlan>,
    ): Pair<Engine, String> {
        val errors = mutableListOf<String>()

        for (plan in plans) {
            try {
                val newEngine = Engine(
                    EngineConfig(
                        modelPath = path,
                        backend = plan.backend,
                        visionBackend = plan.visionBackend,
                        audioBackend = plan.audioBackend,
                        maxNumTokens = maxModelTokens,
                        maxNumImages = maxModelImages,
                        cacheDir = cacheDir.absolutePath,
                    )
                )

                newEngine.initialize()
                return newEngine to plan.name
            } catch (e: Exception) {
                errors += "${plan.name}: ${e.message ?: e.javaClass.simpleName}"
            }
        }

        throw Exception(
            "Unable to initialize LiteRT-LM backend. ${errors.joinToString(" | ")}"
        )
    }

    private fun backendPlansForModel(file: File): List<BackendPlan> {
        val cpu = Backend.CPU(4)
        val gpu = Backend.GPU()
        val fileName = file.name.lowercase()

        // E2B model: efficient medium-sized model, prefer GPU then CPU
        val e2bPlans = listOf(
            BackendPlan(
                name = "gpu-core-vision-cpu",
                backend = gpu,
                visionBackend = cpu,
                audioBackend = null,
            ),
            BackendPlan(
                name = "cpu-safe",
                backend = cpu,
                visionBackend = cpu,
                audioBackend = null,
            ),
        )

        return when {
            fileName.contains("e2b") -> e2bPlans
            else -> e2bPlans // Default to E2B-style plans for unknown models
        }
    }

    private fun recoveryBackendPlans(
        file: File,
        currentBackend: String,
    ): List<BackendPlan> {
        val plans = backendPlansForModel(file)

        return when {
            currentBackend.startsWith("npu") ->
                plans.filterNot { it.name.startsWith("npu") } +
                    plans.filter { it.name.startsWith("npu") }
            currentBackend.startsWith("gpu") ->
                plans.filterNot { it.name.startsWith("gpu") } +
                    plans.filter { it.name.startsWith("gpu") }
            currentBackend.startsWith("cpu") ->
                plans.filterNot { it.name.startsWith("cpu") } +
                    plans.filter { it.name.startsWith("cpu") }
            else -> plans
        }
    }

    private fun generateResponse(
        prompt: String,
        imagePath: String?,
        conversationId: String?,
        history: List<*>?,
        result: MethodChannel.Result,
    ) {
        if (modelLoading) {
            result.success(
                mapOf(
                    "success" to false,
                    "text" to "",
                    "errorMessage" to "Model is still loading.",
                )
            )
            return
        }

        val activeEngine = engine
        if (!modelReady || activeEngine == null || modelPath.isNullOrBlank()) {
            result.success(
                mapOf(
                    "success" to false,
                    "text" to "",
                    "errorMessage" to "Model is not initialized on Android.",
                )
            )
            return
        }

        val normalizedImagePath = imagePath?.trim().orEmpty().ifEmpty { null }
        if (normalizedImagePath != null) {
            val imageFile = File(normalizedImagePath)
            if (!imageFile.exists()) {
                result.success(
                    mapOf(
                        "success" to false,
                        "text" to "",
                        "errorMessage" to "Selected image file was not found.",
                    )
                )
                return
            }
        }

        val trimmedPrompt = normalizePrompt(
            prompt = prompt,
            hasImage = normalizedImagePath != null,
        )
        if (trimmedPrompt.isEmpty()) {
            result.success(
                mapOf(
                    "success" to false,
                    "text" to "",
                    "errorMessage" to "Please enter a message.",
                )
            )
            return
        }

        val initialMessages = buildInitialMessages(history)

        modelExecutor.execute {
            try {
                val responseText = runInference(
                    activeEngine = activeEngine,
                    prompt = trimmedPrompt,
                    imagePath = normalizedImagePath,
                    conversationId = conversationId,
                    initialMessages = initialMessages,
                )

                postResult(
                    result,
                    mapOf(
                        "success" to true,
                        "text" to responseText,
                        "errorMessage" to null,
                    )
                )
            } catch (e: Exception) {
                val recoveredText = retryInferenceIfNeeded(
                    cause = e,
                    prompt = trimmedPrompt,
                    imagePath = normalizedImagePath,
                    conversationId = conversationId,
                    initialMessages = initialMessages,
                )

                if (recoveredText != null) {
                    postResult(
                        result,
                        mapOf(
                            "success" to true,
                            "text" to recoveredText,
                            "errorMessage" to null,
                        )
                    )
                    return@execute
                }

                val errorMessage = buildInferenceErrorMessage(e)
                modelError = errorMessage

                postResult(
                    result,
                    mapOf(
                        "success" to false,
                        "text" to "",
                        "errorMessage" to errorMessage,
                    )
                )
            }
        }
    }

    private fun generateResponseStream(
        requestId: String,
        prompt: String,
        imagePath: String?,
        conversationId: String?,
        history: List<*>?,
        result: MethodChannel.Result,
    ) {
        if (requestId.isBlank()) {
            result.success(
                mapOf(
                    "success" to false,
                    "errorMessage" to "Missing stream request id.",
                )
            )
            return
        }

        if (modelLoading) {
            result.success(
                mapOf(
                    "success" to false,
                    "errorMessage" to "Model is still loading.",
                )
            )
            return
        }

        val activeEngine = engine
        if (!modelReady || activeEngine == null || modelPath.isNullOrBlank()) {
            result.success(
                mapOf(
                    "success" to false,
                    "errorMessage" to "Model is not initialized on Android.",
                )
            )
            return
        }

        val normalizedImagePath = imagePath?.trim().orEmpty().ifEmpty { null }
        if (normalizedImagePath != null) {
            val imageFile = File(normalizedImagePath)
            if (!imageFile.exists()) {
                result.success(
                    mapOf(
                        "success" to false,
                        "errorMessage" to "Selected image file was not found.",
                    )
                )
                return
            }
        }

        val trimmedPrompt = normalizePrompt(
            prompt = prompt,
            hasImage = normalizedImagePath != null,
        )
        if (trimmedPrompt.isEmpty()) {
            result.success(
                mapOf(
                    "success" to false,
                    "errorMessage" to "Please enter a message.",
                )
            )
            return
        }

        val initialMessages = buildInitialMessages(history)
        result.success(
            mapOf(
                "success" to true,
                "requestId" to requestId,
            )
        )

        modelExecutor.execute {
            try {
                runStreamingInference(
                    activeEngine = activeEngine,
                    requestId = requestId,
                    prompt = trimmedPrompt,
                    imagePath = normalizedImagePath,
                    conversationId = conversationId,
                    initialMessages = initialMessages,
                )
            } catch (e: Exception) {
                val errorMessage = buildInferenceErrorMessage(e)
                modelError = errorMessage
                postStreamEvent(
                    mapOf(
                        "requestId" to requestId,
                        "type" to "error",
                        "errorMessage" to errorMessage,
                    )
                )
            }
        }
    }

    private fun buildInitialMessages(history: List<*>?): List<Message> {
        val messages = mutableListOf<Message>()

        history.orEmpty().forEach { item ->
            val map = item as? Map<*, *> ?: return@forEach
            val isUser = map["isUser"] as? Boolean ?: false
            val text = (map["text"] as? String)?.trim().orEmpty()

            if (text.isBlank()) return@forEach

            messages += if (isUser) {
                Message.user(text)
            } else {
                Message.model(text)
            }
        }

        return messages
    }

    private fun normalizePrompt(
        prompt: String,
        hasImage: Boolean,
    ): String {
        val trimmed = prompt.trim()
        if (trimmed.isEmpty() && hasImage) {
            return "Describe this image briefly. If there is readable text, include the important parts."
        }

        val maxPromptChars = if (hasImage) 900 else 1400
        if (trimmed.length <= maxPromptChars) {
            return trimmed
        }

        return trimmed.substring(0, maxPromptChars)
    }

    private fun prepareImageForInference(imagePath: String?): ByteArray? {
        if (imagePath.isNullOrBlank()) return null

        return try {
            val source = File(imagePath)
            if (!source.exists()) return null

            val bounds = BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            BitmapFactory.decodeFile(source.absolutePath, bounds)

            val width = bounds.outWidth
            val height = bounds.outHeight
            if (width <= 0 || height <= 0) {
                return readOriginalImageBytes(source)
            }

            val sourceMax = maxOf(width, height)
            var sampleSize = 1
            while (sourceMax / sampleSize > maxInferenceImageDimension * 2) {
                sampleSize *= 2
            }

            val decodeOptions = BitmapFactory.Options().apply {
                inSampleSize = sampleSize
            }

            val decoded = BitmapFactory.decodeFile(source.absolutePath, decodeOptions)
                ?: return readOriginalImageBytes(source)

            val oriented = rotateBitmapIfNeeded(decoded, source.absolutePath)
            val scaled = scaleBitmapIfNeeded(oriented)

            val output = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 90, output)
            val bytes = output.toByteArray()

            if (scaled !== oriented) scaled.recycle()
            if (oriented !== decoded) oriented.recycle()
            if (!decoded.isRecycled) decoded.recycle()

            bytes
        } catch (_: Throwable) {
            val source = File(imagePath)
            readOriginalImageBytes(source)
        }
    }

    private fun readOriginalImageBytes(file: File): ByteArray? {
        return try {
            if (file.exists()) file.readBytes() else null
        } catch (_: Throwable) {
            null
        }
    }


    private fun rotateBitmapIfNeeded(bitmap: Bitmap, imagePath: String): Bitmap {
        val orientation = try {
            ExifInterface(imagePath).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        } catch (_: Exception) {
            ExifInterface.ORIENTATION_NORMAL
        }

        val degrees = when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }

        if (degrees == 0f) return bitmap

        val matrix = Matrix().apply { postRotate(degrees) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }

    private fun scaleBitmapIfNeeded(bitmap: Bitmap): Bitmap {
        val currentMax = maxOf(bitmap.width, bitmap.height)
        if (currentMax <= maxInferenceImageDimension) return bitmap

        val ratio = maxInferenceImageDimension.toFloat() / currentMax.toFloat()
        val targetWidth = maxOf(1, (bitmap.width * ratio).toInt())
        val targetHeight = maxOf(1, (bitmap.height * ratio).toInt())
        return Bitmap.createScaledBitmap(bitmap, targetWidth, targetHeight, true)
    }

    private fun runInference(
        activeEngine: Engine,
        prompt: String,
        imagePath: String?,
        conversationId: String?,
        initialMessages: List<Message>,
    ): String {
        val hasImage = !imagePath.isNullOrBlank()
        val requestType = if (hasImage) "image" else "text"
        Log.d(TAG, "runInference: starting $requestType request (conversationId=$conversationId)")

        val preparedImageBytes = prepareImageForInference(imagePath)
        val keepConversationAlive = preparedImageBytes == null
        val acquired = acquireConversation(
            activeEngine = activeEngine,
            conversationId = conversationId,
            initialMessages = initialMessages,
            keepAlive = keepConversationAlive,
        )

        val response = try {
            if (preparedImageBytes == null) {
                acquired.conversation.sendMessage(prompt)
            } else {
                acquired.conversation.sendMessage(
                    Contents.of(
                        Content.Text(prompt),
                        Content.ImageBytes(preparedImageBytes),
                    )
                )
            }


        } catch (e: Exception) {
            Log.e(TAG, "runInference: $requestType request failed", e)
            if (!acquired.closeAfterUse) {
                closeActiveConversation()
            }
            throw e
        } finally {
            if (acquired.closeAfterUse) {
                Log.d(TAG, "runInference: closing temporary $requestType conversation")
                safeCloseConversation(acquired.conversation)
            }
        }

        Log.d(TAG, "runInference: $requestType request completed")
        return extractText(response)
    }

    private fun runStreamingInference(
        activeEngine: Engine,
        requestId: String,
        prompt: String,
        imagePath: String?,
        conversationId: String?,
        initialMessages: List<Message>,
    ) {
        val preparedImageBytes = prepareImageForInference(imagePath)
        val keepConversationAlive = preparedImageBytes == null
        val acquired = acquireConversation(
            activeEngine = activeEngine,
            conversationId = conversationId,
            initialMessages = initialMessages,
            keepAlive = keepConversationAlive,
        )

        val callback = object : MessageCallback {
            override fun onMessage(message: Message) {
                val text = extractText(message, preserveWhitespace = true)
                if (text.isBlank()) return

                postStreamEvent(
                    mapOf(
                        "requestId" to requestId,
                        "type" to "partial",
                        "text" to text,
                    )
                )
            }

            override fun onDone() {
                postBenchmarkMetrics(requestId, acquired.conversation)
                postStreamEvent(
                    mapOf(
                        "requestId" to requestId,
                        "type" to "done",
                        "text" to "",
                    )
                )

                if (acquired.closeAfterUse) {
                    safeCloseConversation(acquired.conversation)
                }
            }

            override fun onError(throwable: Throwable) {
                val exception = Exception(
                    throwable.message ?: throwable.javaClass.simpleName,
                    throwable,
                )
                val errorMessage = buildInferenceErrorMessage(exception)
                modelError = errorMessage

                if (acquired.closeAfterUse) {
                    safeCloseConversation(acquired.conversation)
                } else {
                    closeActiveConversation()
                }

                postStreamEvent(
                    mapOf(
                        "requestId" to requestId,
                        "type" to "error",
                        "errorMessage" to errorMessage,
                    )
                )
            }
        }

        try {
            if (preparedImageBytes == null) {
                acquired.conversation.sendMessageAsync(prompt, callback)
            } else {
                acquired.conversation.sendMessageAsync(
                    Contents.of(
                        Content.Text(prompt),
                        Content.ImageBytes(preparedImageBytes),
                    ),
                    callback,
                )
            }


        } catch (e: Exception) {
            if (acquired.closeAfterUse) {
                safeCloseConversation(acquired.conversation)
            } else {
                closeActiveConversation()
            }
            throw e
        }
    }

    private data class AcquiredConversation(
        val conversation: com.google.ai.edge.litertlm.Conversation,
        val closeAfterUse: Boolean,
    )

    private fun buildConversationConfig(initialMessages: List<Message>): ConversationConfig {
        return ConversationConfig(
            systemInstruction = Contents.of(
                """
                You are Lilly.
                Be warm, clear, and brief.
                Use short natural sentences unless the user asks for detail.
                Do not use emojis.
                If the user gives OCR text from the camera, rely on that text only and be honest when unsure.
                """.trimIndent()
            ),
            initialMessages = initialMessages,
            samplerConfig = SamplerConfig(
                topK = 24,
                topP = 0.90,
                temperature = 0.45,
                seed = 1,
            ),
        )
    }

    private fun acquireConversation(
        activeEngine: Engine,
        conversationId: String?,
        initialMessages: List<Message>,
        keepAlive: Boolean,
    ): AcquiredConversation {
        // If this is a temporary conversation (image inference), close any cached conversation first.
        // LiteRT-LM only supports one active conversation per engine at a time.
        if (!keepAlive) {
            Log.d(TAG, "acquireConversation: creating temporary conversation (image)")
            closeActiveConversation()
            return AcquiredConversation(
                conversation = activeEngine.createConversation(buildConversationConfig(initialMessages)),
                closeAfterUse = true,
            )
        }

        // For persistent conversations (text-only requests):
        if (conversationId.isNullOrBlank()) {
            Log.d(TAG, "acquireConversation: creating fresh persistent conversation (no id)")
            closeActiveConversation()
            val conversation = activeEngine.createConversation(buildConversationConfig(initialMessages))
            activeConversation = ConversationHandle("", conversation)
            return AcquiredConversation(conversation, closeAfterUse = false)
        }

        // Try to reuse the cached text conversation if it's still alive and has the same ID.
        val existing = activeConversation
        if (existing != null &&
            existing.id == conversationId &&
            existing.conversation.isAlive
        ) {
            Log.d(TAG, "acquireConversation: reusing cached conversation '$conversationId'")
            return AcquiredConversation(existing.conversation, closeAfterUse = false)
        }

        // Otherwise, close the old one and create a fresh persistent conversation.
        Log.d(TAG, "acquireConversation: closing old conversation and creating new one for '$conversationId'")
        closeActiveConversation()
        val conversation = activeEngine.createConversation(buildConversationConfig(initialMessages))
        activeConversation = ConversationHandle(conversationId, conversation)
        return AcquiredConversation(conversation, closeAfterUse = false)
    }

    private fun shouldRetryInference(
        cause: Exception,
        imagePath: String?,
    ): Boolean {
        // Only retry text requests with backend errors, not image requests.
        // Image failures should be handled by the Dart layer (e.g., OCR fallback).
        // If we rebuild the engine here, it permanently demotes the backend for all future requests.
        if (!imagePath.isNullOrBlank()) {
            return false
        }

        val message = cause.message?.lowercase().orEmpty()
        return message.contains("nativesendmessage") ||
            message.contains("failed to invoke the compiled model") ||
            message.contains("compiled_model_executor")
    }


    private fun retryInferenceIfNeeded(
        cause: Exception,
        prompt: String,
        imagePath: String?,
        conversationId: String?,
        initialMessages: List<Message>,
    ): String? {
        val path = modelPath ?: return null
        if (!shouldRetryInference(cause, imagePath)) {
            Log.d(TAG, "retryInferenceIfNeeded: no retry needed (image request or non-backend error)")
            return null
        }

        Log.w(TAG, "retryInferenceIfNeeded: text request failed with $activeBackend, rebuilding engine", cause)
        val file = File(path)
        val retryPlans = recoveryBackendPlans(file, activeBackend)

        return try {
            closeEngine()
            val rebuilt = createEngine(path, retryPlans)

            engine = rebuilt.first
            activeBackend = rebuilt.second
            modelReady = true
            modelLoading = false
            modelError = null

            Log.d(TAG, "retryInferenceIfNeeded: engine rebuilt with backend=$activeBackend, retrying text request")
            runInference(
                activeEngine = rebuilt.first,
                prompt = prompt,
                imagePath = imagePath,
                conversationId = conversationId,
                initialMessages = initialMessages,
            )
        } catch (e: Exception) {
            Log.e(TAG, "retryInferenceIfNeeded: retry also failed", e)
            null
        }
    }

    private fun buildInitializationErrorMessage(
        cause: Exception,
        selectedPlans: List<BackendPlan>,
    ): String {
        return buildString {
            append(cause.message ?: "Failed to initialize LiteRT-LM engine.")
            append(" ")
            append(deviceDiagnostics())
            append(" ")
            append("[plans=")
            append(selectedPlans.joinToString(separator = ",") { plan -> plan.name })
            append("]")
            append(" ")
            append("[device=")
            append(Build.MANUFACTURER)
            append("/")
            append(Build.MODEL)
            append("]")
        }.trim()
    }

    private fun buildInferenceErrorMessage(cause: Exception): String {
        return buildString {
            append(cause.message ?: "Gemma 4 inference failed on Android.")
            append(" ")
            append(deviceDiagnostics())
        }.trim()
    }

    @OptIn(ExperimentalApi::class)
    private fun postBenchmarkMetrics(
        requestId: String,
        conversation: com.google.ai.edge.litertlm.Conversation,
    ) {
        try {
            val info = conversation.getBenchmarkInfo()
            val summary =
                "backend=$activeBackend ttft=${info.timeToFirstTokenInSecond}s " +
                    "prefill=${info.lastPrefillTokenCount}@${info.lastPrefillTokensPerSecond}/s " +
                    "decode=${info.lastDecodeTokenCount}@${info.lastDecodeTokensPerSecond}/s"

            postStreamEvent(
                mapOf(
                    "requestId" to requestId,
                    "type" to "metrics",
                    "summary" to summary,
                    "backend" to activeBackend,
                    "timeToFirstTokenSeconds" to info.timeToFirstTokenInSecond,
                    "prefillTokenCount" to info.lastPrefillTokenCount,
                    "decodeTokenCount" to info.lastDecodeTokenCount,
                    "prefillTokensPerSecond" to info.lastPrefillTokensPerSecond,
                    "decodeTokensPerSecond" to info.lastDecodeTokensPerSecond,
                )
            )
        } catch (_: Exception) {
        }
    }

    private fun extractText(
        message: Message,
        preserveWhitespace: Boolean = false,
    ): String {
        val textParts = message.contents.contents
            .filterIsInstance<Content.Text>()
            .map { part ->
                if (preserveWhitespace) part.text else part.text.trim()
            }
            .filter { it.isNotEmpty() }

        return if (textParts.isNotEmpty()) {
            textParts.joinToString(separator = if (preserveWhitespace) "" else "\n")
        } else {
            message.toString()
        }
    }


    private fun deviceDiagnostics(): String {
        val activityManager = getSystemService(ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)

        val notificationsEnabled =
            getSystemService(NotificationManager::class.java)?.areNotificationsEnabled() ?: true

        val totalMemMb = memoryInfo.totalMem / (1024 * 1024)
        val availMemMb = memoryInfo.availMem / (1024 * 1024)

        return "[backend=$activeBackend totalMemMb=$totalMemMb availMemMb=$availMemMb lowRam=${activityManager.isLowRamDevice} notificationsEnabled=$notificationsEnabled sdk=${Build.VERSION.SDK_INT}]"
    }

    private fun disposeModel() {
        closeActiveConversation()
        closeEngine()
        modelReady = false
        modelLoading = false
        modelPath = null
        modelError = null
        activeBackend = "uninitialized"
    }

    private fun closeEngine() {
        closeActiveConversation()
        try {
            engine?.close()
        } catch (_: Exception) {
        } finally {
            engine = null
        }
    }

    private fun closeActiveConversation() {
        val existing = activeConversation
        activeConversation = null
        if (existing != null) {
            Log.d(TAG, "closeActiveConversation: closing conversation '${existing.id}'")
            safeCloseConversation(existing.conversation)
        }
    }

    private fun safeCloseConversation(conversation: com.google.ai.edge.litertlm.Conversation) {
        try {
            conversation.close()
        } catch (_: Exception) {
        }
    }

    private fun postResult(
        result: MethodChannel.Result,
        payload: Map<String, Any?>,
    ) {
        mainHandler.post {
            result.success(payload)
        }
    }

    private fun postStreamEvent(payload: Map<String, Any?>) {
        mainHandler.post {
            val sink = modelEventSink
            if (sink == null) {
                if (pendingModelEvents.size >= 64) {
                    pendingModelEvents.removeAt(0)
                }
                pendingModelEvents.add(payload)
            } else {
                sink.success(payload)
            }
        }
    }

    override fun onDestroy() {
        disposeModel()
        modelExecutor.shutdown()
        super.onDestroy()
    }
}
