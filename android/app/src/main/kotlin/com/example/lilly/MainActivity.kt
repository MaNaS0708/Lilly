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
                                "Say \"Hey Lilly\" to open voice chat. Lilly listens from the foreground trigger service and can still be opened from the notification."
                            } else {
                                "Say \"Hey Lilly\" to open voice chat. The first time you enable the trigger, Lilly downloads the wake-word model automatically and then starts listening."
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

                val initialized = createEngine(path)
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
                modelError = buildString {
                    append(e.message ?: "Failed to initialize LiteRT-LM engine.")
                    append(" ")
                    append(deviceDiagnostics())
                }.trim()

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

        private fun createEngine(path: String): Pair<Engine, String> {
        val errors = mutableListOf<String>()

        val attempts = listOf(
            "cpu" to Backend.CPU(),
            "gpu" to Backend.GPU(),
        )

        for ((name, backend) in attempts) {
            try {
                val newEngine = Engine(
                    EngineConfig(
                        modelPath = path,
                        backend = backend,
                        visionBackend = backend,
                        audioBackend = backend,
                        maxNumTokens = 2048,
                    )
                )
                newEngine.initialize()
                return newEngine to name
            } catch (e: Exception) {
                errors += "$name: ${e.message ?: e.javaClass.simpleName}"
            }
        }

        throw Exception(
            "Unable to initialize LiteRT-LM backend. ${errors.joinToString(" | ")}"
        )
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

        if (!imagePath.isNullOrBlank()) {
            result.success(
                mapOf(
                    "success" to false,
                    "text" to "",
                    "errorMessage" to "Gemma 4 text chat is implemented first. Image input is not wired yet on this Android path.",
                )
            )
            return
        }

        val trimmedPrompt = prompt.trim()
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

        modelExecutor.execute {
            try {
                val conversationConfig = ConversationConfig(
                    systemInstruction = Contents.of(
                        """
                        You are Lilly, a kind, warm, patient assistant.
                        Speak in a natural and easy-to-understand way.
                        Use short clear sentences unless the user asks for detail.
                        Do not use emojis.
                        Avoid jargon unless it is really needed, and explain it simply when used.
                        Sound like a calm helpful person, not like a formal bot.

                        When the user asks about text from the world around them, help naturally.
                        If the extracted text strongly suggests an object, say what it most likely is.
                        Example: if the text looks like a book cover, say it appears to be a book and mention the likely title and author.
                        Never invent visual details you cannot actually infer.
                        Be honest when you are unsure.
                        """.trimIndent()
                    ),

                    initialMessages = buildInitialMessages(history),
                    samplerConfig = SamplerConfig(
                        topK = 40,
                        topP = 0.95,
                        temperature = 0.7,
                        seed = 1,
                    ),
                )

                val response = activeEngine.createConversation(conversationConfig).use { conversation ->
                    conversation.sendMessage(trimmedPrompt)
                }

                val responseText = extractText(response)

                postResult(
                    result,
                    mapOf(
                        "success" to true,
                        "text" to responseText,
                        "errorMessage" to null,
                    )
                )
            } catch (e: Exception) {
                postResult(
                    result,
                    mapOf(
                        "success" to false,
                        "text" to "",
                        "errorMessage" to (e.message ?: "Gemma 4 inference failed on Android."),
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
