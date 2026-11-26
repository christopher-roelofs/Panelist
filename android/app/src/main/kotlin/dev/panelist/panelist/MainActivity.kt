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
            "copy" -> background(result) { copy(Uri.parse(call.arguments as String)) }
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
            "canWrite" -> background(result) { canWrite(Uri.parse(call.arguments as String)) }
            "docExists" -> background(result) {
                resolve(treeArg(call), call.argument<String>("path")!!) != null
            }
            "docReplace" -> background(result) {
                replace(treeArg(call), call.argument<String>("path")!!, File(call.argument<String>("file")!!))
            }
            "docCreate" -> background(result) {
                create(treeArg(call), call.argument<String>("path")!!, File(call.argument<String>("file")!!))
            }
            "docMove" -> background(result) {
                move(treeArg(call), call.argument<String>("from")!!, call.argument<String>("to")!!)
            }
            "docDelete" -> background(result) {
                delete(treeArg(call), call.argument<String>("path")!!)
                null
            }
            "docRemoveEmptyFolder" -> background(result) {
                removeEmptyFolder(treeArg(call), call.argument<String>("path")!!)
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
            // Write too: details are saved into the comics, and comics are
            // renamed, moved and converted in place.
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
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
        persist(tree, write = true)
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

    /**
     * Keeps read access (and with [write], write access) across restarts,
     * where the provider allows it.
     */
    private fun persist(uri: Uri, write: Boolean = false) {
        val read = Intent.FLAG_GRANT_READ_URI_PERMISSION
        val both = read or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        for (flags in if (write) listOf(both, read) else listOf(read)) {
            try {
                contentResolver.takePersistableUriPermission(uri, flags)
                return
            } catch (_: SecurityException) {
                // Not persistable (e.g. a one-off grant from a file manager):
                // usable for now, but recents will need it picked again. Or
                // no write access granted: try read alone.
            }
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

    // --- Editing documents in a library folder -------------------------
    //
    // Addressed by the folder's tree URI and a `/`-separated path inside it,
    // so any provider works (document IDs are opaque).

    private fun treeArg(call: MethodCall) = Uri.parse(call.argument<String>("tree")!!)

    /** Whether Panelist may change files in the folder [tree]. */
    private fun canWrite(tree: Uri): Boolean =
        contentResolver.persistedUriPermissions.any {
            it.uri == tree && it.isWritePermission
        }

    private fun docUri(tree: Uri, id: String) =
        DocumentsContract.buildDocumentUriUsingTree(tree, id)

    private fun split(path: String): Pair<String, String> {
        val clean = path.trim('/')
        return clean.substringBeforeLast('/', "") to clean.substringAfterLast('/')
    }

    /** [parentId]'s child named [name]: `(id, isFolder)`, or null. */
    private fun child(tree: Uri, parentId: String, name: String): Pair<String, Boolean>? {
        val columns = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
        )
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
        var loose: Pair<String, Boolean>? = null
        contentResolver.query(children, columns, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                val found = c.getString(1) ?: continue
                val entry = c.getString(0) to
                    (c.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR)
                if (found == name) return entry
                // Most storage ignores case: "saga" is the same as "Saga".
                if (found.equals(name, ignoreCase = true)) loose = entry
            }
        }
        return loose
    }

    /** The document ID at [path] inside [tree], or null. */
    private fun resolve(tree: Uri, path: String): String? {
        var id = DocumentsContract.getTreeDocumentId(tree)
        for (part in path.split('/').filter { it.isNotEmpty() }) {
            id = child(tree, id, part)?.first ?: return null
        }
        return id
    }

    /** The folder at [path] inside [tree], created as needed. */
    private fun ensureFolder(tree: Uri, path: String): String {
        var id = DocumentsContract.getTreeDocumentId(tree)
        for (part in path.split('/').filter { it.isNotEmpty() }) {
            val existing = child(tree, id, part)
            id = when {
                existing == null -> DocumentsContract.getDocumentId(
                    DocumentsContract.createDocument(
                        contentResolver,
                        docUri(tree, id),
                        DocumentsContract.Document.MIME_TYPE_DIR,
                        part,
                    ) ?: throw IllegalStateException("Couldn’t create the folder $part"),
                )
                existing.second -> existing.first
                else -> throw IllegalStateException("$part is a file, not a folder")
            }
        }
        return id
    }

    private fun sizeOf(uri: Uri): Long? =
        contentResolver.query(
            uri,
            arrayOf(DocumentsContract.Document.COLUMN_SIZE),
            null,
            null,
            null,
        )?.use { c -> if (c.moveToFirst() && !c.isNull(0)) c.getLong(0) else null }

    /** A new document [name] in [parentId] holding [file]'s bytes, checked. */
    private fun write(tree: Uri, parentId: String, name: String, file: File): Uri {
        val uri = DocumentsContract.createDocument(
            contentResolver,
            docUri(tree, parentId),
            "application/octet-stream",
            name,
        ) ?: throw IllegalStateException("Couldn’t create $name")
        try {
            if (displayName(uri) != name) {
                throw IllegalStateException("The folder already has a file named $name")
            }
            contentResolver.openOutputStream(uri, "w")!!.use { out ->
                file.inputStream().use { it.copyTo(out) }
            }
            val size = sizeOf(uri)
            if (size != null && size != file.length()) {
                throw IllegalStateException("Only part of $name was written")
            }
        } catch (e: Exception) {
            DocumentsContract.deleteDocument(contentResolver, uri)
            throw e
        }
        return uri
    }

    /**
     * Replaces the document at [path] with [file]: written alongside under a
     * hidden name and checked first, so a failure leaves the original as it
     * was. Returns the document's URI (the same on local storage).
     */
    private fun replace(tree: Uri, path: String, file: File): String {
        val (folder, name) = split(path)
        val parentId = resolve(tree, folder)
            ?: throw IllegalStateException("The folder of $name is gone")
        val originalId = child(tree, parentId, name)?.first
            ?: throw IllegalStateException("$name is gone")
        val saving = ".$name.panelist-saving"
        val old = ".$name.panelist-old"
        for (leftover in listOf(saving, old)) {
            child(tree, parentId, leftover)?.let {
                DocumentsContract.deleteDocument(contentResolver, docUri(tree, it.first))
            }
        }
        val fresh = write(tree, parentId, saving, file)
        // Original aside, new one in, then the original goes. Each step can
        // be undone if the next one fails.
        val aside = try {
            DocumentsContract.renameDocument(contentResolver, docUri(tree, originalId), old)
                ?: docUri(tree, originalId)
        } catch (e: Exception) {
            DocumentsContract.deleteDocument(contentResolver, fresh)
            throw e
        }
        val placed = try {
            DocumentsContract.renameDocument(contentResolver, fresh, name) ?: fresh
        } catch (e: Exception) {
            DocumentsContract.renameDocument(contentResolver, aside, name)
            DocumentsContract.deleteDocument(contentResolver, fresh)
            throw e
        }
        DocumentsContract.deleteDocument(contentResolver, aside)
        return placed.toString()
    }

    /** A new document at [path] (folders created) holding [file]'s bytes. */
    private fun create(tree: Uri, path: String, file: File): String {
        val (folder, name) = split(path)
        val parentId = ensureFolder(tree, folder)
        if (child(tree, parentId, name) != null) {
            throw IllegalStateException("The folder already has a file named $name")
        }
        return write(tree, parentId, name, file).toString()
    }

    /**
     * Moves the document at [from] to [to] (both paths inside [tree]),
     * creating folders as needed. Nothing is overwritten. Returns its URI.
     */
    private fun move(tree: Uri, from: String, to: String): String {
        val (fromFolder, fromName) = split(from)
        val (toFolder, toName) = split(to)
        val fromParent = resolve(tree, fromFolder)
            ?: throw IllegalStateException("The folder of $fromName is gone")
        val id = child(tree, fromParent, fromName)?.first
            ?: throw IllegalStateException("$fromName is gone")
        val toParent = ensureFolder(tree, toFolder)
        val there = child(tree, toParent, toName)
        // Only the case changes: the "existing" file is this one.
        if (there != null && there.first != id) {
            throw IllegalStateException("A file named $toName is already there")
        }
        var uri = docUri(tree, id)
        if (toParent != fromParent) {
            // A name free in both folders while it moves.
            val moving = if (child(tree, toParent, fromName) == null) {
                fromName
            } else {
                ".$fromName.panelist-moving"
            }
            if (moving != fromName) {
                uri = DocumentsContract.renameDocument(contentResolver, uri, moving) ?: uri
            }
            uri = try {
                DocumentsContract.moveDocument(
                    contentResolver,
                    uri,
                    docUri(tree, fromParent),
                    docUri(tree, toParent),
                ) ?: throw UnsupportedOperationException()
            } catch (_: UnsupportedOperationException) {
                copyThenDelete(tree, uri, toParent, moving)
            }
        }
        if (displayName(uri) != toName) {
            uri = renameTo(uri, toName)
        }
        return uri.toString()
    }

    /** Renames [uri] to [name], also when only the case changes. */
    private fun renameTo(uri: Uri, name: String): Uri {
        val current = displayName(uri)
        if (current != null && current.equals(name, ignoreCase = true)) {
            val step = DocumentsContract.renameDocument(
                contentResolver,
                uri,
                ".$name.panelist-renaming",
            ) ?: uri
            return DocumentsContract.renameDocument(contentResolver, step, name) ?: step
        }
        return DocumentsContract.renameDocument(contentResolver, uri, name) ?: uri
    }

    /** For providers that can't move: copy to [toParent], then delete. */
    private fun copyThenDelete(tree: Uri, uri: Uri, toParent: String, name: String): Uri {
        val copy = File.createTempFile("move", null, copiesDir())
        try {
            contentResolver.openInputStream(uri)!!.use { input ->
                copy.outputStream().use { input.copyTo(it) }
            }
            val moved = write(tree, toParent, name, copy)
            DocumentsContract.deleteDocument(contentResolver, uri)
            return moved
        } finally {
            copy.delete()
        }
    }

    private fun delete(tree: Uri, path: String) {
        val id = resolve(tree, path) ?: return
        DocumentsContract.deleteDocument(contentResolver, docUri(tree, id))
    }

    /** Deletes the folder at [path] if nothing is in it; whether it did. */
    private fun removeEmptyFolder(tree: Uri, path: String): Boolean {
        if (path.trim('/').isEmpty()) return false
        val id = resolve(tree, path) ?: return false
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, id)
        val empty = contentResolver.query(
            children,
            arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID),
            null,
            null,
            null,
        )?.use { it.count == 0 } ?: false
        if (empty) DocumentsContract.deleteDocument(contentResolver, docUri(tree, id))
        return empty
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

    /**
     * A private copy of [uri] in the cache, for edits: reopening a library
     * document through /proc/self/fd can be refused, a copy can't.
     */
    private fun copy(uri: Uri): String {
        val copy = File.createTempFile("edit", null, copiesDir())
        try {
            contentResolver.openInputStream(uri)!!.use { input ->
                copy.outputStream().use { input.copyTo(it) }
            }
        } catch (e: Exception) {
            copy.delete()
            throw e
        }
        return copy.path
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
