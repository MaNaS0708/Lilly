package com.example.lilly

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "lilly/model"
    private var modelReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initializeModel" -> {
                        modelReady = true
                        result.success(true)
                    }

                    "disposeModel" -> {
                        modelReady = false
                        result.success(null)
                    }

                    "generateResponse" -> {
                        if (!modelReady) {
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
                                "Android native stub received image plus prompt: \"$prompt\". Replace this with Gemma 4 LiteRT inference."

                            hasImage ->
                                "Android native stub received an image. Replace this with Gemma 4 LiteRT image inference."

                            prompt.isNotBlank() ->
                                "Android native stub reply for: \"$prompt\". Replace this with Gemma 4 LiteRT text inference."

                            else ->
                                "Android native model is ready."
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
