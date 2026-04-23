package com.example.lilly

import java.io.File

object WakeWordConstants {
    const val wakePhraseLabel = "Hey Lilly"

    private const val storageDirName = "wake_word"
    const val modelDirName = "sherpa-onnx-kws-zipformer-zh-en-3M-2025-12-20"
    const val archiveName = "$modelDirName.tar.bz2"
    const val modelUrl =
        "https://github.com/k2-fsa/sherpa-onnx/releases/download/kws-models/$archiveName"

    const val sampleRate = 16000
    const val featureDim = 80
    const val triggerCooldownMs = 5000L

    const val bundledKeywordsAssetPath = "wake_word/keywords.txt"

    fun storageDir(filesDir: File): File = File(filesDir, storageDirName)
    fun modelDir(filesDir: File): File = File(storageDir(filesDir), modelDirName)

    fun encoder(filesDir: File): File =
        File(modelDir(filesDir), "encoder-epoch-13-avg-2-chunk-16-left-64.int8.onnx")

    fun decoder(filesDir: File): File =
        File(modelDir(filesDir), "decoder-epoch-13-avg-2-chunk-16-left-64.onnx")

    fun joiner(filesDir: File): File =
        File(modelDir(filesDir), "joiner-epoch-13-avg-2-chunk-16-left-64.int8.onnx")

    fun tokens(filesDir: File): File =
        File(modelDir(filesDir), "tokens.txt")

    fun lexicon(filesDir: File): File =
        File(modelDir(filesDir), "en.phone")

    fun generatedKeywordsFile(filesDir: File): File =
        File(storageDir(filesDir), "keywords.txt")

    fun requiredFiles(filesDir: File): List<File> {
        return listOf(
            encoder(filesDir),
            decoder(filesDir),
            joiner(filesDir),
            tokens(filesDir),
            lexicon(filesDir),
        )
    }

    fun isModelInstalled(filesDir: File): Boolean {
        return requiredFiles(filesDir).all { it.exists() && it.length() > 0L }
    }

    fun isWakeWordReady(filesDir: File): Boolean {
        return isModelInstalled(filesDir) &&
            generatedKeywordsFile(filesDir).exists() &&
            generatedKeywordsFile(filesDir).length() > 0L
    }
}
