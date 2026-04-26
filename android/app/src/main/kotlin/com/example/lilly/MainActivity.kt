package com.example.lilly

import android.app.ActivityManager
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.LogSeverity
import com.google.ai.edge.litertlm.Message
import com.google.ai.edge.litertlm.SamplerConfig
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        init {
            try {
                System.loadLibrary("litertlm_jni")
            } catch (_: UnsatisfiedLinkError) {
                // surfaced later as readable initialization failure
            }
        }
    }

    private val modelChannelName = "lilly/model"
    private val triggerChannelName = "lilly/trigger"

    private val mainHandler = Handler(Looper.getMainLooper())
    private val modelExecutor = Executors.newSingleThreadExecutor()
    private val maxModelTokens = 1024
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
    private var pendingLaunchAction: String? = null

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
                        val history = call.argument<List<*>>("history")
                        generateResponse(prompt, imagePath, history, result)
                    }

                    else -> result.notImplemented()
                }
            }

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
        val npu = Backend.NPU(applicationInfo.nativeLibraryDir)
        val fileName = file.name.lowercase()

        val tensorE4bPlans = listOf(
            BackendPlan(
                name = "npu-core-vision-cpu",
                backend = npu,
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

        val genericE4bPlans = listOf(
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

        val smallerModelPlans = listOf(
            BackendPlan(
                name = "cpu-safe",
                backend = cpu,
                visionBackend = cpu,
                audioBackend = null,
            ),
            BackendPlan(
                name = "gpu-core-vision-cpu",
                backend = gpu,
                visionBackend = cpu,
                audioBackend = null,
            ),
        )

        return when {
            fileName.contains("e4b") && isTensorPixel() -> tensorE4bPlans
            fileName.contains("e4b") -> genericE4bPlans
            else -> smallerModelPlans
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

    private fun isTensorPixel(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        val model = Build.MODEL.lowercase()
        val hardware = Build.HARDWARE.lowercase()
        val socManufacturer = if (Build.VERSION.SDK_INT >= 31) {
            Build.SOC_MANUFACTURER.lowercase()
        } else {
            ""
        }

        val looksLikePixelTensor =
            (manufacturer == "google" || brand == "google") &&
                (model.contains("pixel 6") ||
                    model.contains("pixel 7") ||
                    model.contains("pixel 8") ||
                    model.contains("pixel 9"))

        return looksLikePixelTensor ||
            hardware.contains("tensor") ||
            socManufacturer.contains("google")
    }

    private fun generateResponse(
        prompt: String,
        imagePath: String?,
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

    private fun runInference(
        activeEngine: Engine,
        prompt: String,
        imagePath: String?,
        initialMessages: List<Message>,
    ): String {
        val conversationConfig = ConversationConfig(
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

        val response = activeEngine.createConversation(conversationConfig).use { conversation ->
            if (imagePath.isNullOrBlank()) {
                conversation.sendMessage(prompt)
            } else {
                conversation.sendMessage(
                    Contents.of(
                        Content.Text(prompt),
                        Content.ImageFile(File(imagePath).absolutePath),
                    )
                )
            }
        }

        return extractText(response)
    }

    private fun shouldRetryInference(cause: Exception): Boolean {
        val message = cause.message?.lowercase().orEmpty()
        return message.contains("nativesendmessage") ||
            message.contains("failed to invoke the compiled model") ||
            message.contains("compiled_model_executor")
    }

    private fun retryInferenceIfNeeded(
        cause: Exception,
        prompt: String,
        imagePath: String?,
        initialMessages: List<Message>,
    ): String? {
        val path = modelPath ?: return null
        if (!shouldRetryInference(cause)) {
            return null
        }

        return try {
            closeEngine()
            val rebuilt = createEngine(path, recoveryBackendPlans(File(path), activeBackend))

            engine = rebuilt.first
            activeBackend = rebuilt.second
            modelReady = true
            modelLoading = false
            modelError = null

            runInference(
                activeEngine = rebuilt.first,
                prompt = prompt,
                imagePath = imagePath,
                initialMessages = initialMessages,
            )
        } catch (_: Exception) {
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

    private fun extractText(message: Message): String {
        val textParts = message.contents.contents
            .filterIsInstance<Content.Text>()
            .map { it.text.trim() }
            .filter { it.isNotEmpty() }

        return if (textParts.isNotEmpty()) {
            textParts.joinToString(separator = "\n")
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
        closeEngine()
        modelReady = false
        modelLoading = false
        modelPath = null
        modelError = null
        activeBackend = "uninitialized"
    }

    private fun closeEngine() {
        try {
            engine?.close()
        } catch (_: Exception) {
        } finally {
            engine = null
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

    override fun onDestroy() {
        disposeModel()
        modelExecutor.shutdown()
        super.onDestroy()
    }
}
