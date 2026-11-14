package com.smartoire.brainwave.kit

// Port of App/CaptureStore.swift: saved captures as JSON files in app storage, and export copies for sharing.

import android.content.Context
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object CaptureStore {
    private fun folder(context: Context) = File(context.filesDir, "captures").apply { mkdirs() }

    fun save(context: Context, capture: Capture) {
        File(folder(context), "${capture.id}.json").writeText(capture.toJson().toString())
    }

    /// Newest first.
    fun loadAll(context: Context): List<Capture> =
        folder(context).listFiles { f -> f.extension == "json" }.orEmpty()
            .mapNotNull { parseCapture(it.readText()) }
            .sortedByDescending { it.started }

    fun delete(context: Context, capture: Capture) {
        File(folder(context), "${capture.id}.json").delete()
    }

    /// A CSV and a JSON copy, named by start time, in the cache folder (shared through FileProvider).
    fun exportFiles(context: Context, capture: Capture): List<File> {
        val name = "Brainwave " + SimpleDateFormat("yyyy-MM-dd HH.mm", Locale.US).format(Date(capture.started))
        val folder = File(context.cacheDir, "exports").apply { mkdirs() }
        return listOf(
            File(folder, "$name.csv").apply { writeText(capture.csv()) },
            File(folder, "$name.json").apply { writeText(capture.toJson().toString(2)) },
        )
    }
}
