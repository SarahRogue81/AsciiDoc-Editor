package com.sarahrogue81.asciidoc_editor

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Process
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.nio.charset.StandardCharsets

class SafFileHandler(private val activity: Activity) {
    companion object {
        private const val REQUEST_OPEN_DOCUMENT = 4101
        private const val REQUEST_CREATE_DOCUMENT = 4102
    }

    private var pendingResult: MethodChannel.Result? = null
    private var pendingCreateContent: String = ""

    fun extractUriFromIntent(intent: Intent?): String? {
        if (intent == null) return null
        val action = intent.action
        if (action != Intent.ACTION_VIEW && action != Intent.ACTION_EDIT) {
            return null
        }
        val uri = intent.data ?: return null
        tryTakePersistablePermission(uri, intent.flags)
        return uri.toString()
    }

    fun openDocument(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("BUSY", "Another file picker request is already in progress.", null)
            return
        }
        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "text/asciidoc",
                    "text/x-asciidoc",
                    "text/plain",
                    "application/octet-stream",
                ),
            )
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_OPEN_DOCUMENT)
        } catch (e: Exception) {
            pendingResult = null
            result.error("OPEN_FAILED", e.message, null)
        }
    }

    fun createDocument(suggestedName: String, initialContent: String, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("BUSY", "Another file picker request is already in progress.", null)
            return
        }
        pendingResult = result
        pendingCreateContent = initialContent
        val safeName = if (suggestedName.endsWith(".adoc", ignoreCase = true) ||
            suggestedName.endsWith(".asciidoc", ignoreCase = true) ||
            suggestedName.endsWith(".asc", ignoreCase = true)
        ) {
            suggestedName
        } else {
            "$suggestedName.adoc"
        }

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "text/plain"
            putExtra(Intent.EXTRA_TITLE, safeName)
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_CREATE_DOCUMENT)
        } catch (e: Exception) {
            pendingResult = null
            pendingCreateContent = ""
            result.error("CREATE_FAILED", e.message, null)
        }
    }

    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_OPEN_DOCUMENT && requestCode != REQUEST_CREATE_DOCUMENT) {
            return false
        }
        val result = pendingResult ?: return true
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pendingCreateContent = ""
            result.success(null)
            return true
        }

        val uri = data.data!!
        tryTakePersistablePermission(uri, data.flags)

        try {
            if (requestCode == REQUEST_CREATE_DOCUMENT) {
                val contentToWrite = pendingCreateContent
                pendingCreateContent = ""
                writeTextToUri(uri, contentToWrite)
                val displayName = queryDisplayName(uri)
                result.success(
                    mapOf(
                        "uri" to uri.toString(),
                        "displayName" to displayName,
                        "content" to contentToWrite,
                        "isReadOnly" to false,
                    ),
                )
            } else {
                val content = readTextFromUri(uri)
                val displayName = queryDisplayName(uri)
                val isReadOnly = !canWriteToUri(uri)
                result.success(
                    mapOf(
                        "uri" to uri.toString(),
                        "displayName" to displayName,
                        "content" to content,
                        "isReadOnly" to isReadOnly,
                    ),
                )
            }
        } catch (e: Exception) {
            result.error("IO_ERROR", e.message ?: "Failed to access document.", null)
        }
        return true
    }

    fun readDocument(uriString: String, result: MethodChannel.Result) {
        try {
            val uri = Uri.parse(uriString)
            val content = readTextFromUri(uri)
            val displayName = queryDisplayName(uri)
            val isReadOnly = !canWriteToUri(uri)
            result.success(
                mapOf(
                    "uri" to uriString,
                    "displayName" to displayName,
                    "content" to content,
                    "isReadOnly" to isReadOnly,
                ),
            )
        } catch (e: Exception) {
            result.error("READ_ERROR", e.message ?: "Failed to read document.", null)
        }
    }

    fun writeDocument(uriString: String, content: String, result: MethodChannel.Result) {
        try {
            val uri = Uri.parse(uriString)
            writeTextToUri(uri, content)
            result.success(true)
        } catch (e: Exception) {
            result.error("WRITE_ERROR", e.message ?: "Failed to write document.", null)
        }
    }

    private fun tryTakePersistablePermission(uri: Uri, intentFlags: Int) {
        val takeFlags = intentFlags and
            (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        if (takeFlags == 0) return
        try {
            activity.contentResolver.takePersistableUriPermission(uri, takeFlags)
        } catch (_: SecurityException) {
            // Some SAF providers or temporary Open With grants do not support persistable permissions.
        }
    }

    private fun readTextFromUri(uri: Uri): String {
        val inputStream = activity.contentResolver.openInputStream(uri)
            ?: throw IOException("Unable to open input stream for $uri")
        return inputStream.bufferedReader(StandardCharsets.UTF_8).use { it.readText() }
    }

    private fun writeTextToUri(uri: Uri, content: String) {
        val outputStream = try {
            activity.contentResolver.openOutputStream(uri, "wt")
        } catch (_: Exception) {
            activity.contentResolver.openOutputStream(uri, "w")
        } ?: throw IOException("Unable to open output stream for $uri")

        outputStream.use { stream ->
            stream.write(content.toByteArray(StandardCharsets.UTF_8))
            stream.flush()
        }
    }

    private fun queryDisplayName(uri: Uri): String {
        try {
            activity.contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) {
                        val name = cursor.getString(idx)
                        if (!name.isNullOrBlank()) {
                            return name
                        }
                    }
                }
            }
        } catch (_: Exception) {
            // Fall through to path-based fallback.
        }
        return uri.lastPathSegment?.substringAfterLast('/') ?: "Untitled.adoc"
    }

    private fun canWriteToUri(uri: Uri): Boolean {
        if (uri.scheme == "file") {
            return true
        }
        try {
            activity.contentResolver.query(
                uri,
                arrayOf(DocumentsContract.Document.COLUMN_FLAGS),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(DocumentsContract.Document.COLUMN_FLAGS)
                    if (idx >= 0 && !cursor.isNull(idx)) {
                        val flags = cursor.getInt(idx)
                        if ((flags and DocumentsContract.Document.FLAG_SUPPORTS_WRITE) == 0) {
                            return false
                        }
                    }
                }
            }
        } catch (_: Exception) {
            // Fall through to permission check.
        }

        val permission = activity.checkUriPermission(
            uri,
            Process.myPid(),
            Process.myUid(),
            Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
        )
        return permission == android.content.pm.PackageManager.PERMISSION_GRANTED
    }
}
