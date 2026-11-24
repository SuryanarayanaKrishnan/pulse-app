package com.pulse.pulse.capture

import android.content.Context
import org.json.JSONArray
import java.util.Locale

/**
 * Which SMS senders and notification packages Pulse may look at.
 *
 * The Dart side pushes its own lists via the `configure` channel call; they are persisted here so
 * the receivers keep filtering correctly when the app process was started by a broadcast and no
 * Flutter engine exists. Anything that does not match is dropped immediately and never stored.
 */
class CaptureConfig private constructor(context: Context) {

    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private val senders: List<String> get() = list(KEY_SENDERS, DEFAULT_SENDERS)
    private val walletPackages: Set<String> get() = list(KEY_WALLET, DEFAULT_WALLET_PACKAGES).toSet()
    private val bankPackages: Set<String> get() = list(KEY_BANK_PACKAGES, emptyList()).toSet()
    private val bankHints: List<String> get() = list(KEY_BANK_HINTS, DEFAULT_BANK_HINTS)

    fun update(
        senders: List<String>?,
        walletPackages: List<String>?,
        bankPackages: List<String>?,
        bankHints: List<String>?,
    ) {
        prefs.edit().apply {
            senders?.let { putString(KEY_SENDERS, JSONArray(it).toString()) }
            walletPackages?.let { putString(KEY_WALLET, JSONArray(it).toString()) }
            bankPackages?.let { putString(KEY_BANK_PACKAGES, JSONArray(it).toString()) }
            bankHints?.let { putString(KEY_BANK_HINTS, JSONArray(it).toString()) }
        }.apply()
    }

    /**
     * True when [address] is a known bank sender ID.
     *
     * Matching ignores case and punctuation. IDs of four characters or fewer (FAB, DIB, Liv...)
     * must equal the whole address or one of its `-`/space separated parts (`AD-FAB`), so that
     * short IDs do not match arbitrary text; longer IDs may appear anywhere in the address.
     * Purely numeric addresses (phone numbers) never match.
     */
    fun isBankSender(address: String?): Boolean {
        if (address.isNullOrBlank()) return false
        val parts = address.split(NON_ALNUM).filter { it.isNotEmpty() }.map { it.lowercase(Locale.ROOT) }
        if (parts.isEmpty() || parts.all { p -> p.all { it.isDigit() } }) return false
        val joined = parts.joinToString("")
        return senders.any { raw ->
            val token = raw.filter { it.isLetterOrDigit() }.lowercase(Locale.ROOT)
            when {
                token.isEmpty() -> false
                token.length <= SHORT_ID_MAX -> token == joined || parts.contains(token)
                else -> joined.contains(token)
            }
        }
    }

    /** True for wallet apps, configured bank apps, and packages that look like a known bank app. */
    fun isCapturedPackage(pkg: String): Boolean {
        if (pkg in walletPackages || pkg in bankPackages) return true
        val lower = pkg.lowercase(Locale.ROOT)
        return bankHints.any { it.isNotBlank() && lower.contains(it.lowercase(Locale.ROOT)) }
    }

    private fun list(key: String, fallback: List<String>): List<String> {
        val raw = prefs.getString(key, null) ?: return fallback
        return try {
            val arr = JSONArray(raw)
            List(arr.length()) { arr.getString(it) }
        } catch (_: Exception) {
            fallback
        }
    }

    companion object {
        private const val PREFS = "pulse_capture_config"
        private const val KEY_SENDERS = "senders"
        private const val KEY_WALLET = "wallet_packages"
        private const val KEY_BANK_PACKAGES = "bank_packages"
        private const val KEY_BANK_HINTS = "bank_hints"
        private const val SHORT_ID_MAX = 4
        private val NON_ALNUM = Regex("[^A-Za-z0-9]+")

        /** Mirrors `CaptureConfig.defaultBankSenderIds` in Dart. */
        val DEFAULT_SENDERS = listOf(
            "EmiratesNBD", "ENBD", "ADCBAlert", "ADCB", "FAB", "Mashreq", "MashreqBank", "RAKBANK",
            "DIB", "ADIB", "HSBC", "CBD", "EIB", "Liv", "Wio", "NBF", "CBI", "AjmanBank", "SIB",
            "NoorBank", "ENBDLiv", "StandardChartered", "CitiBank",
        )

        /** Mirrors `CaptureConfig.defaultWalletPackages` in Dart. */
        val DEFAULT_WALLET_PACKAGES = listOf(
            "com.google.android.apps.walletnfcrel",
            "com.google.android.apps.nbu.paisa.user",
            "com.samsung.android.spay",
            "com.samsung.android.samsungpay.gear",
        )

        val DEFAULT_BANK_HINTS = listOf("enbd", "emiratesnbd", "adcb", "mashreq", "rakbank", "adib", "hsbc")

        private val OTP = Regex(
            "\\b(otp|one[- ]?time (password|pin|code)|verification code|passcode|cvv)\\b",
            RegexOption.IGNORE_CASE,
        )

        /** One-time codes are never captured, stored or uploaded. */
        fun looksLikeOtp(text: String): Boolean = OTP.containsMatchIn(text)

        @Volatile
        private var instance: CaptureConfig? = null

        fun get(context: Context): CaptureConfig =
            instance ?: synchronized(this) {
                instance ?: CaptureConfig(context).also { instance = it }
            }
    }
}
