package ai.lyra.mobile.memory

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.util.UUID

/**
 * Android SQLite implementation of Stonic Memory Core (schema.js & store.js).
 * Includes FTS5 full-text search with fold & skel columns.
 */
class LyraDbHelper(context: Context) : SQLiteOpenHelper(context, "lyra_memory.db", null, 1) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("""
            CREATE TABLE turns (
                id TEXT PRIMARY KEY,
                role TEXT NOT NULL,
                text TEXT NOT NULL,
                fold TEXT NOT NULL,
                skel TEXT NOT NULL,
                created_at INTEGER NOT NULL
            )
        """.trimIndent())

        db.execSQL("""
            CREATE TABLE memories (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                text_original TEXT NOT NULL,
                text_en TEXT NOT NULL,
                quote TEXT NOT NULL,
                origin TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'active',
                pinned INTEGER NOT NULL DEFAULT 0,
                fold TEXT NOT NULL,
                skel TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )
        """.trimIndent())

        db.execSQL("""
            CREATE TABLE intentions (
                id TEXT PRIMARY KEY,
                what TEXT NOT NULL,
                what_en TEXT NOT NULL,
                who_for TEXT NOT NULL,
                due TEXT,
                status TEXT NOT NULL DEFAULT 'open',
                quote TEXT NOT NULL,
                created_at INTEGER NOT NULL
            )
        """.trimIndent())

        // FTS5 Virtual Tables
        db.execSQL("CREATE VIRTUAL TABLE memories_uni USING fts5(text_original, fold, content='memories', content_rowid='rowid')")
        db.execSQL("CREATE VIRTUAL TABLE memories_skel USING fts5(skel, content='memories', content_rowid='rowid')")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {}

    fun insertTurn(role: String, text: String): String {
        val id = UUID.randomUUID().toString()
        val now = System.currentTimeMillis()
        val values = ContentValues().apply {
            put("id", id)
            put("role", role)
            put("text", text)
            put("fold", Normalizer.foldText(text))
            put("skel", Normalizer.skelText(text))
            put("created_at", now)
        }
        writableDatabase.insert("turns", null, values)
        return id
    }

    fun insertMemory(
        type: String,
        textOriginal: String,
        textEn: String,
        quote: String,
        origin: String,
        pinned: Boolean = false
    ): String {
        val id = UUID.randomUUID().toString()
        val now = System.currentTimeMillis()
        val fold = Normalizer.foldText(textOriginal)
        val skel = Normalizer.skelText(textOriginal)

        val values = ContentValues().apply {
            put("id", id)
            put("type", type)
            put("text_original", textOriginal)
            put("text_en", textEn)
            put("quote", quote)
            put("origin", origin)
            put("status", "active")
            put("pinned", if (pinned) 1 else 0)
            put("fold", fold)
            put("skel", skel)
            put("created_at", now)
            put("updated_at", now)
        }
        writableDatabase.insert("memories", null, values)
        return id
    }

    /**
     * Stonic context.js deterministic State Card compiler.
     */
    fun compileStateCard(): String {
        val db = readableDatabase
        val sb = StringBuilder()

        // 1. ALWAYS KEEP IN MIND (pinned)
        val pinnedCursor = db.rawQuery("SELECT text_en FROM memories WHERE pinned = 1 AND status = 'active'", null)
        val pinned = mutableListOf<String>()
        while (pinnedCursor.moveToNext()) {
            pinned.add(pinnedCursor.getString(0))
        }
        pinnedCursor.close()

        if (pinned.isNotEmpty()) {
            sb.append("=== ALWAYS KEEP IN MIND ===\n")
            pinned.forEach { sb.append("- ").append(it).append("\n") }
            sb.append("\n")
        }

        // 2. ABOUT THEM (identity, preference, relationship)
        val aboutCursor = db.rawQuery(
            "SELECT type, text_en FROM memories WHERE pinned = 0 AND status = 'active' ORDER BY updated_at DESC LIMIT 15",
            null
        )
        val about = mutableListOf<String>()
        while (aboutCursor.moveToNext()) {
            about.add("${aboutCursor.getString(0)}: ${aboutCursor.getString(1)}")
        }
        aboutCursor.close()

        if (about.isNotEmpty()) {
            sb.append("=== ABOUT THEM ===\n")
            about.forEach { sb.append("- ").append(it).append("\n") }
            sb.append("\n")
        }

        // 3. OPEN PROMISES
        val promisesCursor = db.rawQuery("SELECT what_en, due FROM intentions WHERE status = 'open' LIMIT 5", null)
        val promises = mutableListOf<String>()
        while (promisesCursor.moveToNext()) {
            val due = promisesCursor.getString(1)?.let { " (Due: $it)" } ?: ""
            promises.add("${promisesCursor.getString(0)}$due")
        }
        promisesCursor.close()

        if (promises.isNotEmpty()) {
            sb.append("=== OPEN PROMISES ===\n")
            promises.forEach { sb.append("- ").append(it).append("\n") }
            sb.append("\n")
        }

        return sb.toString().trim()
    }

    fun verifyQuote(quote: String): Boolean {
        if (quote.isBlank()) return false
        val db = readableDatabase
        val cursor = db.rawQuery("SELECT COUNT(*) FROM turns WHERE text LIKE ?", arrayOf("%$quote%"))
        val exists = cursor.moveToFirst() && cursor.getInt(0) > 0
        cursor.close()
        return exists
    }
}
