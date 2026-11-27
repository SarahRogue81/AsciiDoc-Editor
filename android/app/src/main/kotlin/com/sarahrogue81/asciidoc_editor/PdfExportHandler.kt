package com.sarahrogue81.asciidoc_editor

import android.app.Activity
import android.content.Context
import android.print.PrintAttributes
import android.print.PrintManager
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.MethodChannel

class PdfExportHandler(private val activity: Activity) {
    private var activePrintWebView: WebView? = null

    fun exportHtmlToPdf(html: String, jobName: String, result: MethodChannel.Result) {
        val sanitizedJobName = jobName
            .removeSuffix(".adoc")
            .removeSuffix(".asciidoc")
            .removeSuffix(".asc")
            .ifBlank { "AsciiDoc Document" }

        activity.runOnUiThread {
            var completed = false
            val webView = WebView(activity).apply {
                settings.javaScriptEnabled = false
                settings.allowFileAccess = true
                settings.allowContentAccess = true
            }
            activePrintWebView = webView

            webView.webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView, url: String?) {
                    if (completed) return
                    completed = true
                    try {
                        val printManager =
                            activity.getSystemService(Context.PRINT_SERVICE) as PrintManager
                        val adapter = view.createPrintDocumentAdapter(sanitizedJobName)
                        val attributes = PrintAttributes.Builder()
                            .setMinMargins(PrintAttributes.Margins(250, 250, 250, 250))
                            .build()
                        printManager.print(
                            sanitizedJobName,
                            adapter,
                            attributes,
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PRINT_ERROR", e.message ?: "Failed to open print dialog.", null)
                    }
                }

                override fun onReceivedError(
                    view: WebView,
                    request: WebResourceRequest,
                    error: WebResourceError,
                ) {
                    if (completed || !request.isForMainFrame) return
                    completed = true
                    result.error("RENDER_ERROR", error.description?.toString(), null)
                }
            }

            webView.loadDataWithBaseURL(
                "file:///android_asset/flutter_assets/assets/preview/",
                html,
                "text/html",
                "UTF-8",
                null,
            )
        }
    }
}
