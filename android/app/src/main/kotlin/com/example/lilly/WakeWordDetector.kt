package com.example.lilly

import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.SystemClock
import android.util.Log
import com.k2fsa.sherpa.onnx.KeywordSpotter
import com.k2fsa.sherpa.onnx.KeywordSpotterConfig
import com.k2fsa.sherpa.onnx.OnlineModelConfig
import com.k2fsa.sherpa.onnx.OnlineStream
import com.k2fsa.sherpa.onnx.OnlineTransducerModelConfig
import com.k2fsa.sherpa.onnx.getFeatureConfig
import kotlin.concurrent.thread

private const val TAG = "LillyWakeWord"

class WakeWordDetector(
    private val context: Context,
    private val onKeywordDetected: (String) -> Unit,
    private val onStatusChanged: (String) -> Unit,
) {
    private var keywordSpotter: KeywordSpotter? = null
    private var stream: OnlineStream? = null
    private var audioRecord: AudioRecord? = null
    private var workerThread: Thread? = null

    @Volatile
    private var isRunning = false

    @Volatile
    private var lastTriggerAt = 0L

    fun start() {
        if (isRunning) return

        val keywordsFile = WakeWordConstants.generatedKeywordsFile(context.filesDir)
        if (!keywordsFile.exists() || keywordsFile.length() == 0L) {
            throw IllegalStateException(
                "Wake-word keywords file is missing. Add android/app/src/main/assets/wake_word/keywords.txt."
            )
        }

        val config = KeywordSpotterConfig(
            featConfig = getFeatureConfig(
                sampleRate = WakeWordConstants.sampleRate,
                featureDim = WakeWordConstants.featureDim,
            ),
            modelConfig = OnlineModelConfig(
                transducer = OnlineTransducerModelConfig(
                    encoder = WakeWordConstants.encoder(context.filesDir).absolutePath,
                    decoder = WakeWordConstants.decoder(context.filesDir).absolutePath,
                    joiner = WakeWordConstants.joiner(context.filesDir).absolutePath,
                ),
                tokens = WakeWordConstants.tokens(context.filesDir).absolutePath,
                numThreads = 2,
                provider = "cpu",
                modelType = "",
                modelingUnit = "",
                bpeVocab = "",
            ),
            keywordsFile = keywordsFile.absolutePath,
            maxActivePaths = 4,
            numTrailingBlanks = 1,
            keywordsScore = 1.5f,
            keywordsThreshold = 0.20f,
        )

        keywordSpotter = KeywordSpotter(config = config)
        stream = keywordSpotter!!.createStream()

        if (stream == null || stream!!.ptr == 0L) {
            throw IllegalStateException("Failed to create wake-word stream.")
        }

        audioRecord = createAudioRecord()
        audioRecord!!.startRecording()

        isRunning = true
        onStatusChanged("Listening for \"${WakeWordConstants.wakePhraseLabel}\"")

        workerThread = thread(
            start = true,
            isDaemon = true,
            name = "lilly-wake-word",
        ) {
            processLoop()
        }
    }

    fun stop() {
        isRunning = false
        workerThread?.join(500)

        stream?.release()
        stream = null

        keywordSpotter?.release()
        keywordSpotter = null

        audioRecord?.let {
            try {
                it.stop()
            } catch (_: Exception) {
            }
            it.release()
        }
        audioRecord = null
    }

    private fun processLoop() {
        val localRecord = audioRecord ?: return
        val localSpotter = keywordSpotter ?: return
        val localStream = stream ?: return

        val intervalSeconds = 0.1f
        val bufferSize = (WakeWordConstants.sampleRate * intervalSeconds).toInt()
        val pcmBuffer = ShortArray(bufferSize)

        while (isRunning) {
            val read = localRecord.read(pcmBuffer, 0, pcmBuffer.size)
            if (read <= 0) {
                continue
            }

            val samples = FloatArray(read) { index ->
                pcmBuffer[index] / 32768.0f
            }

            localStream.acceptWaveform(samples, WakeWordConstants.sampleRate)

            while (localSpotter.isReady(localStream)) {
                localSpotter.decode(localStream)
                val detected = localSpotter.getResult(localStream).keyword

                if (detected.isNotBlank()) {
                    localSpotter.reset(localStream)

                    val now = SystemClock.elapsedRealtime()
                    if (now - lastTriggerAt >= WakeWordConstants.triggerCooldownMs) {
                        lastTriggerAt = now
                        Log.i(TAG, "Wake word detected: $detected")
                        onKeywordDetected(detected)
                    }
                }
            }
        }
    }

    private fun createAudioRecord(): AudioRecord {
        val minBytes = AudioRecord.getMinBufferSize(
            WakeWordConstants.sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )

        if (minBytes <= 0) {
            throw IllegalStateException("Could not create AudioRecord buffer.")
        }

        return AudioRecord(
            MediaRecorder.AudioSource.MIC,
            WakeWordConstants.sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            minBytes * 2,
        )
    }
}
