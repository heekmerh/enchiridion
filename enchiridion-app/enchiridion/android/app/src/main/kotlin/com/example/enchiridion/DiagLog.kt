package com.example.enchiridion

import android.content.Context
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// Minimal synchronous append-only diagnostic log shared with the Dart side
// (lib/services/diagnostics_log.dart). Both write to the same file so a
// single readable timeline covers native FlutterEngine construction/
// teardown — which happens before any Dart code can run — as well as
// everything that happens once Dart is up. Writes are synchronous and
// flushed/closed every call rather than buffered, so a hang or an
// ANR-triggered process kill during an event still leaves a usable trail.
object DiagLog {
    private const val FILE_NAME = "study_buddy_diagnostics.log"
    private const val MAX_BYTES = 2L * 1024 * 1024
    private val dateFormat =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)

    // The directory Dart's `DiagnosticsLog` is told to write into as well.
    fun directory(context: Context): String = context.filesDir.path

    @Synchronized
    fun event(context: Context, kind: String, name: String, data: String = "") {
        try {
            val file = File(context.filesDir, FILE_NAME)
            rotateIfNeeded(file)
            val ts = dateFormat.format(Date())
            val suffix = if (data.isEmpty()) "" else " $data"
            file.appendText("$ts [native] $kind $name$suffix\n")
        } catch (_: Exception) {
            // A failing log write must never affect the thing being observed.
        }
    }

    private fun rotateIfNeeded(file: File) {
        try {
            if (file.exists() && file.length() > MAX_BYTES) {
                val rotated = File(file.parentFile, "$FILE_NAME.1")
                if (rotated.exists()) rotated.delete()
                file.renameTo(rotated)
            }
        } catch (_: Exception) {
        }
    }
}
