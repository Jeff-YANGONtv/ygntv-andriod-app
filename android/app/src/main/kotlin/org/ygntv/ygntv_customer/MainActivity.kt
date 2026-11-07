package org.ygntv.ygntv_customer

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import java.security.MessageDigest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DOWNLOAD_CHANNEL
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "enqueue" -> result.success(enqueueDownload(call))
                    "list" -> result.success(listDownloads())
                    "dismiss" -> {
                        val id = call.argument<Number>("id")?.toLong()
                            ?: error("Missing download ID")
                        dismissDownload(id)
                        result.success(null)
                    }
                    "delete" -> {
                        val id = call.argument<Number>("id")?.toLong()
                            ?: error("Missing download ID")
                        deleteDownload(id)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error(
                    "DOWNLOAD_FAILED",
                    error.message ?: "Could not access downloads",
                    null
                )
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_UPDATE_CHANNEL
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "startDownload" -> result.success(startAppUpdateDownload(call))
                    "downloadStatus" -> {
                        val id = call.argument<Number>("id")?.toLong()
                            ?: error("Missing update download ID")
                        result.success(appUpdateStatus(id))
                    }
                    "canInstallPackages" -> result.success(canInstallPackages())
                    "openInstallPermissionSettings" -> {
                        openInstallPermissionSettings()
                        result.success(null)
                    }
                    "installDownloadedApk" -> {
                        val id = call.argument<Number>("id")?.toLong()
                            ?: error("Missing update download ID")
                        installDownloadedApk(id)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error(
                    "APP_UPDATE_FAILED",
                    error.message ?: "Could not install the YGNTV update",
                    null
                )
            }
        }
    }

    private fun startAppUpdateDownload(call: MethodCall): Long {
        val uri = Uri.parse(call.argument<String>("url") ?: error("Missing update URL"))
        val host = uri.host?.lowercase()
        require(uri.scheme == "https" && (host == "ygntv.org" || host == "www.ygntv.org")) {
            "YGNTV updates must use the official HTTPS website"
        }
        require(uri.path?.matches(Regex("^/app-updates/customer-test/[A-Za-z0-9._-]+\\.apk$")) == true) {
            "This is not an official YGNTV TEST update file"
        }
        val sha256 = call.argument<String>("sha256")?.lowercase()
            ?: error("Missing update checksum")
        require(sha256.matches(Regex("^[a-f0-9]{64}$"))) {
            "The YGNTV update checksum is invalid"
        }
        val rawName = call.argument<String>("fileName") ?: "ygntv-customer-test-update.apk"
        val fileName = rawName.replace(Regex("[^A-Za-z0-9._-]"), "_")
        require(fileName.endsWith(".apk", ignoreCase = true)) { "The update file must be an APK" }
        val request = DownloadManager.Request(uri)
            .setTitle(call.argument<String>("title") ?: "YGNTV TEST app update")
            .setDescription("Downloading the official YGNTV TEST app update")
            .setMimeType("application/vnd.android.package-archive")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(false)
        request.setDestinationInExternalFilesDir(
            this,
            Environment.DIRECTORY_DOWNLOADS,
            fileName
        )
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val id = manager.enqueue(request)
        appUpdatePreferences().edit().putString("sha256:$id", sha256).apply()
        return id
    }

    private fun appUpdateStatus(id: Long): Map<String, Any?> {
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val cursor = manager.query(DownloadManager.Query().setFilterById(id))
        cursor.use {
            if (!it.moveToFirst()) return mapOf("status" to "missing")
            val statusCode = it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
            val downloaded = it.getLong(it.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)).coerceAtLeast(0L)
            val total = it.getLong(it.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)).coerceAtLeast(0L)
            val reason = it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
            val status = when (statusCode) {
                DownloadManager.STATUS_PENDING -> "pending"
                DownloadManager.STATUS_RUNNING -> "downloading"
                DownloadManager.STATUS_PAUSED -> "paused"
                DownloadManager.STATUS_SUCCESSFUL -> "complete"
                DownloadManager.STATUS_FAILED -> "failed"
                else -> "unknown"
            }
            if (statusCode != DownloadManager.STATUS_SUCCESSFUL) {
                return mapOf(
                    "status" to status,
                    "bytes_downloaded" to downloaded,
                    "total_bytes" to total,
                    "message" to if (statusCode == DownloadManager.STATUS_FAILED) "Download failed (code $reason)." else null
                )
            }
            val actualHash = downloadedApkSha256(manager, id)
            val expectedHash = appUpdatePreferences().getString("sha256:$id", null)
            val checksumValid = actualHash != null && actualHash.equals(expectedHash, ignoreCase = true)
            return mapOf(
                "status" to if (checksumValid) "complete" else "failed",
                "bytes_downloaded" to downloaded,
                "total_bytes" to total,
                "checksum_valid" to checksumValid,
                "message" to if (checksumValid) null else "The downloaded APK checksum did not match."
            )
        }
    }

    private fun downloadedApkSha256(manager: DownloadManager, id: Long): String? {
        return try {
            val uri = manager.getUriForDownloadedFile(id) ?: return null
            val digest = MessageDigest.getInstance("SHA-256")
            contentResolver.openInputStream(uri)?.use { input ->
                val buffer = ByteArray(16 * 1024)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    digest.update(buffer, 0, count)
                }
            } ?: return null
            digest.digest().joinToString("") {
                (it.toInt() and 0xff).toString(16).padStart(2, '0')
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun canInstallPackages(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()

    private fun openInstallPermissionSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
        } else {
            Intent(Settings.ACTION_SECURITY_SETTINGS)
        }
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun installDownloadedApk(id: Long) {
        require(canInstallPackages()) { "Allow YGNTV to install apps from this source first" }
        val status = appUpdateStatus(id)
        require(status["status"] == "complete" && status["checksum_valid"] == true) {
            status["message"] as? String ?: "The YGNTV update download is not ready"
        }
        val uri = (getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager)
            .getUriForDownloadedFile(id) ?: error("The downloaded update file could not be opened")
        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(installIntent)
    }

    private fun appUpdatePreferences() =
        getSharedPreferences(APP_UPDATE_PREFERENCES, Context.MODE_PRIVATE)

    private fun enqueueDownload(call: MethodCall): Long {
        val url = call.argument<String>("url") ?: error("Missing download URL")
        val uri = Uri.parse(url)
        require(uri.scheme == "https") { "Downloads must use HTTPS" }

        val rawHeaders = call.argument<Map<String, String>>("headers") ?: emptyMap()
        when (uri.host?.lowercase()) {
            "stream.ygntv.org" -> {
                require(uri.path?.matches(Regex("^/videos/(m|e)-[1-9][0-9]*/(360p|480p|720p|1080p|1440p|2160p|source)\\.mp4$")) == true) {
                    "This YGNTV stream path is not allowed"
                }
                require(rawHeaders["Origin"] == "https://ygntv.org") {
                    "The protected YGNTV origin header is missing"
                }
                require(rawHeaders["Cookie"]?.startsWith("ygntv_playback_session=") == true) {
                    "The protected YGNTV playback session is missing"
                }
            }
            "api.ygntv.org" -> {
                require(uri.path == "/api/tv/download") {
                    "This YGNTV download route is not allowed"
                }
                require(rawHeaders["Authorization"]?.startsWith("Bearer ") == true) {
                    "Sign in is required for this download"
                }
            }
            else -> error("This download host is not allowed")
        }

        val rawName = call.argument<String>("fileName") ?: "yangon-tv-video.mp4"
        var fileName = rawName.replace(Regex("[^A-Za-z0-9._-]"), "_")
        if (!fileName.lowercase().endsWith(".mp4")) fileName += ".mp4"
        val title = call.argument<String>("title") ?: "YGNTV video"

        val request = DownloadManager.Request(uri)
            .setTitle(title)
            .setDescription("Downloading from YGNTV")
            .setMimeType("video/mp4")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(false)

        rawHeaders.forEach { (name, value) -> request.addRequestHeader(name, value) }
        request.setDestinationInExternalFilesDir(
            this,
            Environment.DIRECTORY_MOVIES,
            fileName
        )

        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val id = manager.enqueue(request)
        val ids = trackedDownloadIds()
        if (id !in ids) ids.add(id)
        downloadPreferences().edit()
            .putString(DOWNLOAD_IDS_KEY, ids.joinToString(","))
            .apply()
        return id
    }

    private fun listDownloads(): List<Map<String, Any?>> {
        val ids = trackedDownloadIds()
        if (ids.isEmpty()) return emptyList()

        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val cursor = manager.query(DownloadManager.Query().setFilterById(*ids.toLongArray()))
        val downloadsById = mutableMapOf<Long, Map<String, Any?>>()
        cursor.use {
            val idColumn = it.getColumnIndexOrThrow(DownloadManager.COLUMN_ID)
            val titleColumn = it.getColumnIndexOrThrow(DownloadManager.COLUMN_TITLE)
            val statusColumn = it.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS)
            val reasonColumn = it.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON)
            val downloadedColumn = it.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
            val totalColumn = it.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
            val localUriColumn = it.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI)

            while (it.moveToNext()) {
                val id = it.getLong(idColumn)
                val stateCode = it.getInt(statusColumn)
                val status = when (stateCode) {
                    DownloadManager.STATUS_PENDING -> "pending"
                    DownloadManager.STATUS_RUNNING -> "downloading"
                    DownloadManager.STATUS_PAUSED -> "paused"
                    DownloadManager.STATUS_SUCCESSFUL -> "complete"
                    DownloadManager.STATUS_FAILED -> "failed"
                    else -> "unknown"
                }
                val reason = it.getInt(reasonColumn)
                val message = if (stateCode == DownloadManager.STATUS_FAILED) {
                    "Download failed (code $reason)."
                } else {
                    null
                }
                downloadsById[id] = mapOf(
                    "id" to id,
                    "title" to (it.getString(titleColumn) ?: "YGNTV video"),
                    "status" to status,
                    "bytes_downloaded" to it.getLong(downloadedColumn).coerceAtLeast(0L),
                    "total_bytes" to it.getLong(totalColumn).coerceAtLeast(0L),
                    "message" to message,
                    "local_uri" to it.getString(localUriColumn)
                )
            }
        }
        return ids.asReversed().mapNotNull(downloadsById::get)
    }

    private fun dismissDownload(id: Long) {
        val ids = trackedDownloadIds()
        ids.remove(id)
        downloadPreferences().edit()
            .putString(DOWNLOAD_IDS_KEY, ids.joinToString(","))
            .apply()
    }

    private fun deleteDownload(id: Long) {
        val manager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        manager.remove(id)
        dismissDownload(id)
    }

    private fun trackedDownloadIds(): MutableList<Long> =
        downloadPreferences()
            .getString(DOWNLOAD_IDS_KEY, "")
            .orEmpty()
            .split(',')
            .mapNotNull(String::toLongOrNull)
            .distinct()
            .toMutableList()

    private fun downloadPreferences() =
        getSharedPreferences(DOWNLOAD_PREFERENCES, Context.MODE_PRIVATE)

    private companion object {
        const val DOWNLOAD_CHANNEL = "org.ygntv.customer/download"
        const val APP_UPDATE_CHANNEL = "org.ygntv.customer/app_update"
        const val APP_UPDATE_PREFERENCES = "ygntv_customer_app_update"
        const val DOWNLOAD_PREFERENCES = "ygntv_customer_downloads"
        const val DOWNLOAD_IDS_KEY = "tracked_download_ids"
    }
}
