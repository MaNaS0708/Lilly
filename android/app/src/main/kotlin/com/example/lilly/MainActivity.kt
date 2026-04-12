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
                        initializeModel(path, result)
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

                        result.success(
                            mapOf(
                                "success" to false,
                                "text" to "",
                                "errorMessage" to "LiteRT-LM custom Android integration is not implemented yet in Lilly. The current MediaPipe path cannot run .litertlm models."
                            )
                        )
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun initializeModel(path: String?, result: MethodChannel.Result) {
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
            return
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
            return
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
            return
        }

        if (path.endsWith(".litertlm")) {
            modelReady = false
            modelPath = path
            modelError =
                "This Lilly build still uses the MediaPipe model bridge. .litertlm requires a custom LiteRT-LM Android integration, which is not wired yet."
            result.success(
                mapOf(
                    "success" to false,
                    "status" to "error",
                    "errorMessage" to modelError
                )
            )
            return
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
}
