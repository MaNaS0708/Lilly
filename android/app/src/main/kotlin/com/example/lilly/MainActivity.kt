package com.example.lilly

import android.os.Handler
import android.os.Looper
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
    private val channelName = "lilly/model"
    private val mainHandler = Handler(Looper.getMainLooper())
    private val modelExecutor = Executors.newSingleThreadExecutor()

    private var engine: Engine? = null
    private var modelReady = false
    private var modelLoading = false
    private var modelPath: String? = null
    private var modelError: String? = null
    private var activeBackend: String = "uninitialized"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
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
                                "errorMessage" to modelError
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
                    "errorMessage" to modelError
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
                    "errorMessage" to modelError
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
                    "errorMessage" to modelError
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
                    "errorMessage" to modelError
                )
            )
            return
        }

        if (modelReady && modelPath == path && engine != null) {
            result.success(
                mapOf(
                    "success" to true,
                    "status" to "ready",
                    "errorMessage" to null
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
                        "errorMessage" to null
                    )
                )
            } catch (e: Exception) {
                closeEngine()
                modelReady = false
                modelLoading = false
                modelPath = null
                activeBackend = "failed"
                modelError = e.message ?: "Failed to initialize LiteRT-LM engine."

                postResult(
                    result,
                    mapOf(
                        "success" to false,
                        "status" to "error",
                        "errorMessage" to modelError
                    )
                )
            }
        }
    }

    private fun createEngine(path: String): Pair<Engine, String> {
        val cachePath = applicationContext.cacheDir.absolutePath
        var lastError: Exception? = null

        val attempts = listOf(
            "gpu" to Backend.GPU(),
            "cpu" to Backend.CPU(),
        )

        for ((name, backend) in attempts) {
            try {
                val newEngine = Engine(
                    EngineConfig(
                        modelPath = path,
                        backend = backend,
                        visionBackend = Backend.GPU(),
                        audioBackend = Backend.CPU(),
                        maxNumTokens = 2048,
                        cacheDir = cachePath,
                    )
                )
                newEngine.initialize()
                return newEngine to name
            } catch (e: Exception) {
                lastError = e
            }
        }

        throw lastError ?: Exception("Unable to initialize any LiteRT-LM backend.")
    }

    private fun generateResponse(
        prompt: String,
        imagePath: String?,
        history: List<*>?,
        result: MethodChannel.Result
    ) {
        if (modelLoading) {
            result.success(
                mapOf(
                    "success" to false,
                    "text" to "",
                    "errorMessage" to "Model is still loading."
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
                    "errorMessage" to "Model is not initialized on Android."
                )
            )
            return
        }

        if (!imagePath.isNullOrBlank()) {
            result.success(
                mapOf(
                    "success" to false,
                    "text" to "",
                    "errorMessage" to "Gemma 4 text chat is implemented first. Image input is not wired yet on this Android path."
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
                    "errorMessage" to "Please enter a message."
                )
            )
            return
        }

        modelExecutor.execute {
            try {
                val conversationConfig = ConversationConfig(
                    systemInstruction = Contents.of(
                        "You are Lilly, a concise, helpful offline assistant."
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
                        "errorMessage" to null
                    )
                )
            } catch (e: Exception) {
                postResult(
                    result,
                    mapOf(
                        "success" to false,
                        "text" to "",
                        "errorMessage" to (e.message ?: "Gemma 4 inference failed on Android.")
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
        payload: Map<String, Any?>
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
