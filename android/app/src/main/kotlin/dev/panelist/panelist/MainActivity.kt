package dev.panelist.panelist

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Bridges Android's Storage Access Framework to Dart (channel
 * `panelist/android`, see lib/platform/android_documents.dart).
 *
 * Documents are identified by their content:// URI. To read one, Dart asks
 * for a file descriptor and opens `/proc/self/fd/<fd>`, so the format
 * readers (Dart file I/O, libarchive, pdfium) all work on plain paths.
 */
class MainActivity : FlutterActivity() {
    private lateinit var channel: MethodChannel
    private val io = Executors.newSingleThreadExecutor()
    private var pendingPick: MethodChannel.Result? = null
    private var pendingTree: MethodChannel.Result? = null

    /** A VIEW intent's URI not yet collected by Dart. */
    private var initialUri: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(::onMethodCall)
        initialUri = viewedUri(intent)
        io.execute(::sweepCopies)
    }

    override fun onStart() {
        super.onStart()
        // Android draws a focus outline (in the system accent colour) around
        // the whole Flutter view once a key event arrives (keyboard, remote,
        // adb). Flutter shows its own focus, so turn the system one off.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            findViewById<View?>(FLUTTER_VIEW_ID)?.defaultFocusHighlightEnabled = false
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        viewedUri(intent)?.let { channel.invokeMethod("openUri", it) }
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "takeInitialUri" -> {
                result.success(initialUri)
                initialUri = null
            }
            "pickDocument" -> pickDocument(result)
            "pickTree" -> pickTree(result)
            "listTree" -> background(result) { listTree(Uri.parse(call.arguments as String)) }
            "open" -> background(result) { open(Uri.parse(call.arguments as String)) }
            "closeFd" -> background(result) {
                ParcelFileDescriptor.adoptFd(call.arguments as Int).close()
                null
            }
            "exists" -> background(result) { exists(Uri.parse(call.arguments as String)) }
            "deleteCopy" -> background(result) {
                deleteCopy(call.arguments as String)
                null
            }
            "release" -> background(result) {
                releasePermission(Uri.parse(call.arguments as String))
                null
            }
            else -> result.notImplemented()
        }
    }

    private fun pickDocument(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "A picker is already open", null)
            return
        }
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            // Comic MIME types are rarely registered, so accept anything and
            // let the format sniffing decide.
            type = "*/*"
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        startActivityForResult(intent, PICK_REQUEST)
    }

    private fun pickTree(result: MethodChannel.Result) {
        if (pendingTree != null) {
            result.error("busy", "A picker is already open", null)
            return
        }
        pendingTree = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        startActivityForResult(intent, TREE_REQUEST)
    }

    /** Called with a picked folder: returns `{uri, name}` once access persists. */
    private fun onTreePicked(resultCode: Int, data: Intent?) {
        val result = pendingTree ?: return
        pendingTree = null
        val tree = data?.data
        if (resultCode != RESULT_OK || tree == null) {
            result.success(null)
            return
        }
        persist(tree)
        io.execute {
            val root = DocumentsContract.buildDocumentUriUsingTree(
                tree,
                DocumentsContract.getTreeDocumentId(tree),
            )
            val name = displayName(root) ?: "Comics"
            runOnUiThread { result.success(mapOf("uri" to tree.toString(), "name" to name)) }
        }
    }

    /**
     * Every file under the folder [tree], as `{uri, folder, name, size,
     * modified}` maps; `folder` is the `/`-separated path inside [tree].
     * Hidden files and folders are skipped.
     */
    private fun listTree(tree: Uri): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        val columns = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )
        val pending = ArrayDeque<Pair<String, String>>()
        pending.add(DocumentsContract.getTreeDocumentId(tree) to "")
        while (pending.isNotEmpty()) {
            val (docId, folder) = pending.removeFirst()
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, docId)
            contentResolver.query(children, columns, null, null, null)?.use { c ->
                while (c.moveToNext()) {
                    val id = c.getString(0)
                    val name = c.getString(1) ?: continue
                    if (name.startsWith(".")) continue
                    if (c.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) {
                        pending.add(id to if (folder.isEmpty()) name else "$folder/$name")
                    } else {
                        out.add(
                            mapOf(
                                "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, id).toString(),
                                "folder" to folder,
                                "name" to name,
                                "size" to if (c.isNull(3)) 0L else c.getLong(3),
                                "modified" to if (c.isNull(4)) 0L else c.getLong(4),
                            ),
                        )
                    }
                }
            }
        }
        return out
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == TREE_REQUEST) {
            onTreePicked(resultCode, data)
            return
        }
        if (requestCode != PICK_REQUEST) return
        val result = pendingPick ?: return
        pendingPick = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        persist(uri)
        result.success(uri.toString())
    }

    /** VIEW intents from file managers ("Open with"). */
    private fun viewedUri(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        val uri = intent.data ?: return null
        if (uri.scheme == "file") return uri.path
        persist(uri)
        return uri.toString()
    }

    /** Keeps read access across restarts, where the provider allows it. */
    private fun persist(uri: Uri) {
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
            // Not persistable (e.g. a one-off grant from a file manager):
            // readable for now, but recents will need it picked again.
        }
    }

    private fun releasePermission(uri: Uri) {
        try {
            contentResolver.releasePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
        }
    }

    /**
     * Opens [uri] for reading. Returns `{fd, name}` for seekable documents
     * (the usual case: local storage), or `{path, name}` for a copy in the
     * cache when the provider only offers a stream (some cloud providers).
     */
    private fun open(uri: Uri): Map<String, Any?> {
        val name = displayName(uri)
        val pfd = contentResolver.openFileDescriptor(uri, "r")
            ?: throw IllegalStateException("Could not open $uri")
        if (isSeekable(pfd)) {
            return mapOf("fd" to pfd.detachFd(), "name" to name)
        }
        pfd.close()
        // Unique, so two opens of one document don't share a file.
        val copy = File.createTempFile("doc", null, copiesDir())
        try {
            contentResolver.openInputStream(uri)!!.use { input ->
                copy.outputStream().use { input.copyTo(it) }
            }
        } catch (e: Exception) {
            copy.delete()
            throw e
        }
        return mapOf("path" to copy.path, "name" to name)
    }

    private fun copiesDir() = File(cacheDir, "documents").apply { mkdirs() }

    /** Deletes a copy made by [open] once it's no longer being read. */
    private fun deleteCopy(path: String) {
        val file = File(path)
        if (file.parentFile?.canonicalPath == copiesDir().canonicalPath) {
            file.delete()
        }
    }

    /**
     * Deletes copies left by earlier runs (e.g. if the app was killed while
     * reading). Copies made by this process are kept: the activity is
     * recreated on rotation while a book may still be open.
     */
    private fun sweepCopies() {
        copiesDir().listFiles()?.forEach {
            if (it.lastModified() < processStart) it.delete()
        }
    }

    private fun isSeekable(pfd: ParcelFileDescriptor): Boolean =
        try {
            Os.lseek(pfd.fileDescriptor, 0, OsConstants.SEEK_CUR)
            true
        } catch (_: ErrnoException) {
            false
        }

    private fun displayName(uri: Uri): String? =
        try {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
        } catch (_: Exception) {
            null
        } ?: uri.lastPathSegment

    private fun exists(uri: Uri): Boolean =
        try {
            contentResolver.openFileDescriptor(uri, "r")?.use { true } ?: false
        } catch (_: Exception) {
            false
        }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            val outcome = runCatching(work)
            runOnUiThread {
                outcome.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error("io", it.message ?: "$it", null) },
                )
            }
        }
    }

    companion object {
        private const val CHANNEL = "panelist/android"
        private const val PICK_REQUEST = 7301
        private const val TREE_REQUEST = 7302

        /** When this process started (the class is loaded once per process). */
        private val processStart = System.currentTimeMillis()
    }
}
