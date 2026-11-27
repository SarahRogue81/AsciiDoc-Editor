package com.sarahrogue81.asciidoc_editor

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val PLATFORM_CHANNEL = "com.sarahrogue81.asciidoc_editor/platform"
        private const val INCOMING_URI_CHANNEL = "com.sarahrogue81.asciidoc_editor/incoming_uri"
    }

    private lateinit var safFileHandler: SafFileHandler
    private lateinit var pdfExportHandler: PdfExportHandler
    private var incomingUriSink: EventChannel.EventSink? = null
    private var pendingInitialUri: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        safFileHandler = SafFileHandler(this)
        pdfExportHandler = PdfExportHandler(this)
        pendingInitialUri = safFileHandler.extractUriFromIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (!::safFileHandler.isInitialized) {
            safFileHandler = SafFileHandler(this)
        }
        if (!::pdfExportHandler.isInitialized) {
            pdfExportHandler = PdfExportHandler(this)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLATFORM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openDocument" -> safFileHandler.openDocument(result)
                    "createDocument" -> {
                        val suggestedName = call.argument<String>("suggestedName") ?: "Untitled.adoc"
                        val content = call.argument<String>("content") ?: ""
                        safFileHandler.createDocument(suggestedName, content, result)
                    }
                    "readDocument" -> {
                        val uri = call.argument<String>("uri")
                        if (uri.isNullOrBlank()) {
                            result.error("INVALID_URI", "Document URI is required.", null)
                        } else {
                            safFileHandler.readDocument(uri, result)
                        }
                    }
                    "writeDocument" -> {
                        val uri = call.argument<String>("uri")
                        val content = call.argument<String>("content") ?: ""
                        if (uri.isNullOrBlank()) {
                            result.error("INVALID_URI", "Document URI is required.", null)
                        } else {
                            safFileHandler.writeDocument(uri, content, result)
                        }
                    }
                    "getInitialUri" -> {
                        val uri = pendingInitialUri
                        pendingInitialUri = null
                        result.success(uri)
                    }
                    "exportPdf" -> {
                        val html = call.argument<String>("html") ?: ""
                        val jobName = call.argument<String>("jobName") ?: "AsciiDoc Document"
                        pdfExportHandler.exportHtmlToPdf(html, jobName, result)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, INCOMING_URI_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    incomingUriSink = events
                }

                override fun onCancel(arguments: Any?) {
                    incomingUriSink = null
                }
            })
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uri = safFileHandler.extractUriFromIntent(intent) ?: return
        val sink = incomingUriSink
        if (sink != null) {
            sink.success(uri)
        } else {
            pendingInitialUri = uri
        }
    }

    @Deprecated("Required for FlutterActivity SAF result forwarding")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (::safFileHandler.isInitialized &&
            safFileHandler.handleActivityResult(requestCode, resultCode, data)
        ) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
