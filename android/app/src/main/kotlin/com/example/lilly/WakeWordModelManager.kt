package com.example.lilly

import android.content.Context
import org.apache.commons.compress.archivers.tar.TarArchiveInputStream
import org.apache.commons.compress.compressors.bzip2.BZip2CompressorInputStream
import java.io.BufferedInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

class WakeWordModelManager(private val context: Context) {
    fun isReady(): Boolean {
        return WakeWordConstants.isWakeWordReady(context.filesDir)
    }

    @Synchronized
    @Throws(IOException::class)
    fun ensureInstalled(onStatus: ((String) -> Unit)? = null): File {
        val storageDir = WakeWordConstants.storageDir(context.filesDir)
        storageDir.mkdirs()

        if (!WakeWordConstants.isModelInstalled(context.filesDir)) {
            onStatus?.invoke("Downloading wake-word model...")
            val archiveFile = File(context.cacheDir, WakeWordConstants.archiveName)
            downloadFile(WakeWordConstants.modelUrl, archiveFile)

            try {
                onStatus?.invoke("Preparing wake-word model...")
                extractArchive(archiveFile, storageDir)
            } finally {
                archiveFile.delete()
            }
        }

        if (!WakeWordConstants.isModelInstalled(context.filesDir)) {
            throw IOException("Wake-word model files are incomplete after extraction.")
        }

        installBundledKeywordsFile()

        if (!WakeWordConstants.isWakeWordReady(context.filesDir)) {
            throw IOException(
                "Wake-word keywords file is missing. Add android/app/src/main/assets/wake_word/keywords.txt."
            )
        }

        return storageDir
    }

    @Throws(IOException::class)
    private fun installBundledKeywordsFile() {
        val outputFile = WakeWordConstants.generatedKeywordsFile(context.filesDir)
        outputFile.parentFile?.mkdirs()

        context.assets.open(WakeWordConstants.bundledKeywordsAssetPath).use { input ->
            FileOutputStream(outputFile).use { output ->
                input.copyTo(output)
            }
        }
    }

    @Throws(IOException::class)
    private fun downloadFile(url: String, destination: File) {
        destination.parentFile?.mkdirs()
        if (destination.exists()) {
            destination.delete()
        }

        val connection = URL(url).openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.connectTimeout = 30_000
        connection.readTimeout = 60_000
        connection.instanceFollowRedirects = true
        connection.connect()

        if (connection.responseCode !in 200..299) {
            throw IOException("Wake-word model download failed with HTTP ${connection.responseCode}.")
        }

        connection.inputStream.use { input ->
            FileOutputStream(destination).use { output ->
                input.copyTo(output)
            }
        }

        connection.disconnect()
    }

    @Throws(IOException::class)
    private fun extractArchive(archiveFile: File, targetDir: File) {
        val modelDir = WakeWordConstants.modelDir(context.filesDir)
        if (modelDir.exists()) {
            modelDir.deleteRecursively()
        }

        val basePath = targetDir.canonicalPath + File.separator

        TarArchiveInputStream(
            BZip2CompressorInputStream(
                BufferedInputStream(FileInputStream(archiveFile)),
            ),
        ).use { tar ->
            while (true) {
                val entry = tar.nextTarEntry ?: break
                val outFile = File(targetDir, entry.name)

                val canonical = outFile.canonicalPath
                if (!canonical.startsWith(basePath)) {
                    throw IOException("Unsafe archive entry: ${entry.name}")
                }

                if (entry.isDirectory) {
                    outFile.mkdirs()
                    continue
                }

                outFile.parentFile?.mkdirs()
                FileOutputStream(outFile).use { output ->
                    tar.copyTo(output)
                }
            }
        }
    }
}
