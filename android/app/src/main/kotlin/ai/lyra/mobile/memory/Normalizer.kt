package ai.lyra.mobile.memory

import java.text.Normalizer
import java.util.Locale

/**
 * Port of Stonic electron/services/memory/normalize.js
 * Generates 'fold' and 'skel' forms for multi-lingual and Roman Urdu FTS5 indexing.
 */
object Normalizer {

    private val VOWELS = setOf('a', 'e', 'i', 'o', 'u', 'y')

    fun foldText(input: String?): String {
        if (input.isNullOrBlank()) return ""
        var text = input.lowercase(Locale.ROOT)
        // Normalize Unicode diacritics
        text = Normalizer.normalize(text, Normalizer.Form.NFD)
            .replace("\\p{InCombiningDiacriticalMarks}+".toRegex(), "")

        // Collapse repeated characters ("jaaaana" -> "jaana")
        text = text.replace("([a-z])\\1{2,}".toRegex(), "$1$1")

        // Standardize common phonetic variants in Roman Urdu/Hindi
        text = text
            .replace("aa", "a")
            .replace("ee", "i")
            .replace("oo", "u")
            .replace("kh", "k")
            .replace("gh", "g")
            .replace("ph", "f")

        return text.replace("[^a-z0-9\\s]".toRegex(), " ").trim()
    }

    fun skelText(input: String?): String {
        val folded = foldText(input)
        val sb = StringBuilder()
        for (ch in folded) {
            if (ch !in VOWELS && ch.isLetterOrDigit()) {
                sb.append(ch)
            } else if (ch.isWhitespace()) {
                if (sb.isNotEmpty() && sb.last() != ' ') {
                    sb.append(' ')
                }
            }
        }
        return sb.toString().trim()
    }
}
