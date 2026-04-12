package com.example.lilly

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "lilly/model"

    private var modelReady = false
    private var modelPath: String? = null
    private var modelError: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initializeModel" -> {
                        val path = call.argument<String>("modelPath")

                        if (path.isNullOrBlank()) {
                            modelReady = false
                            modelPath = null
                            modelError = "No model path was provided."
                            result.success(
                                mapOf(
                                    "success" to false,
                                    "status" to "error",
                                    "errorMessage" to modelError
                                )
                            )
                            return@setMethodCallHandler
                        }

                        val file = File(path)
                        if (!file.exists()) {
                            modelReady = false
                            modelPath = null
                            modelError = "Model file not found at: $path"
                            result.success(
                                mapOf(
                                    "success" to false,
                                    "status" to "error",
                                    "errorMessage" to modelError
                                )
                            )
                            return@setMethodCallHandler
                        }

                        if (file.length() <= 0L) {
                            modelReady = false
                            modelPath = null
                            modelError = "Model file is empty or invalid."
                            result.success(
                                mapOf(
                                    "success" to false,
                                    "status" to "error",
                                    "errorMessage" to modelError
                                )
                            )
                            return@setMethodCallHandler
                        }

                        modelReady = true
                        modelPath = path
                        modelError = null

                        result.success(
                            mapOf(
                                "success" to true,
                                "status" to "ready",
                                "errorMessage" to null
                            )
                        )
                    }

                    "getModelStatus" -> {
                        val status = when {
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
                        modelReady = false
                        modelPath = null
                        modelError = null
                        result.success(null)
                    }

                    "generateResponse" -> {
                        if (!modelReady || modelPath.isNullOrBlank()) {
                            result.success(
                                mapOf(
                                    "success" to false,
                                    "text" to "",
                                    "errorMessage" to "Model is not initialized on Android."
                                )
                            )
                            return@setMethodCallHandler
                        }

                        val prompt = call.argument<String>("prompt").orEmpty()
                        val imagePath = call.argument<String>("imagePath")
                        val hasImage = !imagePath.isNullOrBlank()

                        val responseText = when {
                            hasImage && prompt.isNotBlank() ->
                                "Android native bridge is using model file at $modelPath. Real Gemma image+text inference is the next step."

                            hasImage ->
                                "Android native bridge is using model file at $modelPath. Real Gemma image inference is the next step."

                            prompt.isNotBlank() ->
                                "Android native bridge is using model file at $modelPath. Real Gemma text inference is the next step for: \"$prompt\""

                            else ->
                                "Android native model file is linked and ready."
                        }

                        result.success(
                            mapOf(
                                "success" to true,
                                "text" to responseText,
                                "errorMessage" to null
                            )
                        )
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
