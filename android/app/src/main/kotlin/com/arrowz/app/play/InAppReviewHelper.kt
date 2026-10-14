package com.arrowz.app.play

import android.app.Activity
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.google.android.play.core.review.ReviewInfo
import com.google.android.play.core.review.ReviewManager
import com.google.android.play.core.review.ReviewManagerFactory
import java.lang.ref.WeakReference
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

/**
 * Configuration for rate-limiting In-App Review requests.
 *
 * @param minDaysBetweenRequests Minimum days before requesting another review.
 * @param minEventsBeforeFirstReview Minimum positive events required before the first request.
 * @param maxRequestsPerSession Maximum review prompt attempts allowed per app session.
 * @param preferencesName Name of the [SharedPreferences] file used for tracking.
 */
data class ReviewConfig(
    val minDaysBetweenRequests: Long = 30L,
    val minEventsBeforeFirstReview: Int = 3,
    val maxRequestsPerSession: Int = 1,
    val preferencesName: String = "play_in_app_review_prefs"
)

/**
 * Result returned by the In-App Review request flow.
 */
sealed class ReviewResult {
    /**
     * The review flow completed. Note: Google Play never confirms whether the user
     * actually rated or submitted a review, or whether the bottom sheet was shown (Play
     * enforces an opaque server-side quota). Completion is treated as final.
     */
    data object Completed : ReviewResult()

    /** The review request was skipped because the internal cooldown or guard was active. */
    data class NotEligible(val reason: String) : ReviewResult()

    /** The host Activity is unavailable, finishing, or destroyed. */
    data object ActivityUnavailable : ReviewResult()

    /** The review request failed silently. */
    data class Failed(val exception: Throwable) : ReviewResult()
}

/**
 * Production-ready helper for Google Play's native In-App Review.
 *
 * Implements 100% native Play Store UI using official Play Core Review KTX:
 * - Play Store's own native bottom sheet for ratings and reviews.
 * - Zero custom dialogs, zero "Enjoying the app?" pre-prompts, zero star pickers.
 * - Fails completely silently without disturbing or blocking the user.
 * - Strict adherence to Google Play developer policies.
 *
 * Safeguards:
 * - Built-in cooldown and session throttling to prevent spamming Google's API.
 * - Uses [WeakReference] to [Activity] to guarantee zero memory leaks.
 * - Uses Kotlin Coroutines with `.await()` alongside safe Task callback overloads.
 *
 * Trigger Placement Rule:
 * NEVER call this on app launch, cold start, or after a negative event (failure/crash).
 * ONLY call after genuine positive moments (e.g. level completion, task exported).
 *
 * @param activity The host Activity context.
 * @param reviewManager Injected [ReviewManager], defaulting to [ReviewManagerFactory.create].
 * @param config Rate-limiting and eligibility rules.
 */
class InAppReviewHelper(
    activity: Activity,
    private val reviewManager: ReviewManager = ReviewManagerFactory.create(activity),
    private val config: ReviewConfig = ReviewConfig()
) {

    private val activityRef = WeakReference(activity)

    /** Safe reference to host Activity; null if finishing or destroyed. */
    private val safeActivity: Activity?
        get() = activityRef.get()?.takeIf { !it.isFinishing && !it.isDestroyed }

    private val preferences: SharedPreferences? by lazy {
        activity.applicationContext?.getSharedPreferences(
            config.preferencesName,
            Context.MODE_PRIVATE
        )
    }

    /** Number of review attempts executed in the current app process session. */
    private var sessionAttemptCount = 0

    // ─────────────────────────────────────────────────────────────────────────
    // Eligibility & Cooldown Guards
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Records a positive user milestone (e.g. level finished, task saved).
     *
     * Increments the persistent counter used to satisfy [ReviewConfig.minEventsBeforeFirstReview].
     */
    fun recordPositiveEvent() {
        val prefs = preferences ?: return
        val currentCount = prefs.getInt(KEY_TOTAL_EVENTS_COUNT, 0)
        prefs.edit().putInt(KEY_TOTAL_EVENTS_COUNT, currentCount + 1).apply()
        Log.d(TAG, "Recorded positive milestone. Total events: ${currentCount + 1}")
    }

    /**
     * Evaluates whether the user is eligible for a review request based on
     * session quotas, positive event counts, and minimum cooldown days.
     *
     * @param force If true, bypasses the internal cooldown (useful for debugging/testing only).
     * @return Eligibility decision and reason.
     */
    fun checkEligibility(force: Boolean = false): Pair<Boolean, String> {
        if (force) return true to "Forced attempt."

        // 1. Session-level guard
        if (sessionAttemptCount >= config.maxRequestsPerSession) {
            return false to "Session quota exceeded ($sessionAttemptCount/${config.maxRequestsPerSession} in this session)."
        }

        val prefs = preferences ?: return false to "SharedPreferences unavailable."

        // 2. Minimum positive events guard
        val totalEvents = prefs.getInt(KEY_TOTAL_EVENTS_COUNT, 0)
        if (totalEvents < config.minEventsBeforeFirstReview) {
            return false to "Insufficient positive milestones ($totalEvents/${config.minEventsBeforeFirstReview})."
        }

        // 3. Time-based cooldown guard
        val lastRequestTimestamp = prefs.getLong(KEY_LAST_REQUEST_TIMESTAMP, 0L)
        if (lastRequestTimestamp > 0L) {
            val elapsedMillis = System.currentTimeMillis() - lastRequestTimestamp
            val elapsedDays = TimeUnit.MILLISECONDS.toDays(elapsedMillis)
            if (elapsedDays < config.minDaysBetweenRequests) {
                return false to "Cooldown active ($elapsedDays/${config.minDaysBetweenRequests} days elapsed since last prompt)."
            }
        }

        return true to "Eligible."
    }

    // ─────────────────────────────────────────────────────────────────────────
    // In-App Review Flow Execution
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Requests and displays the native Google Play In-App Review flow using Kotlin Coroutines.
     *
     * Call this ONLY from a genuine success/milestone event:
     * ```kotlin
     * // Example call location in an Activity or ViewModel:
     * fun onLevelCompleted(level: Int) {
     *     reviewHelper.recordPositiveEvent()
     *     lifecycleScope.launch {
     *         reviewHelper.tryRequestReview()
     *     }
     * }
     * ```
     *
     * Note on Return Value:
     * Google's In-App Review API provides NO guarantee that the user was prompted or rated.
     * The dialog may be suppressed by Google Play's internal quota without error.
     * The completion of this method is treated as final in all scenarios.
     *
     * @param force Bypasses internal cooldown checks (default: false).
     * @return [ReviewResult] indicating the outcome.
     */
    suspend fun tryRequestReview(force: Boolean = false): ReviewResult = withContext(Dispatchers.Main) {
        val currentActivity = safeActivity ?: run {
            Log.w(TAG, "Cannot request review: Activity is null, finishing, or destroyed.")
            return@withContext ReviewResult.ActivityUnavailable
        }

        val (isEligible, reason) = checkEligibility(force)
        if (!isEligible) {
            Log.d(TAG, "In-App Review skipped: $reason")
            return@withContext ReviewResult.NotEligible(reason)
        }

        try {
            // Step 1: Request ReviewInfo from Play Core
            Log.d(TAG, "Requesting ReviewInfo from Google Play...")
            val reviewInfo: ReviewInfo = reviewManager.requestReviewFlow().await()

            // Check activity state before launching the UI
            val validActivity = safeActivity ?: return@withContext ReviewResult.ActivityUnavailable

            // Step 2: Launch the native Play Store bottom-sheet flow
            Log.i(TAG, "Launching native Google Play In-App Review flow...")
            reviewManager.launchReviewFlow(validActivity, reviewInfo).await()

            // Update internal cooldown and counters
            markReviewAttempted()

            Log.i(TAG, "In-App Review flow finished. Result treated as final.")
            ReviewResult.Completed
        } catch (e: Exception) {
            // Fail silently: Google Play policy forbids showing any error UI to users
            Log.w(TAG, "In-App Review request failed silently: ${e.message}", e)
            ReviewResult.Failed(e)
        }
    }

    /**
     * Non-coroutine overload of [tryRequestReview] using Google Play Task listeners.
     *
     * @param force Bypasses internal cooldown checks (default: false).
     * @param onComplete Optional callback invoked with the [ReviewResult].
     */
    fun tryRequestReview(
        force: Boolean = false,
        onComplete: ((ReviewResult) -> Unit)? = null
    ) {
        val currentActivity = safeActivity ?: run {
            Log.w(TAG, "Cannot request review: Activity is null, finishing, or destroyed.")
            onComplete?.invoke(ReviewResult.ActivityUnavailable)
            return
        }

        val (isEligible, reason) = checkEligibility(force)
        if (!isEligible) {
            Log.d(TAG, "In-App Review skipped: $reason")
            onComplete?.invoke(ReviewResult.NotEligible(reason))
            return
        }

        Log.d(TAG, "Requesting ReviewInfo from Google Play via Task callback...")
        reviewManager.requestReviewFlow()
            .addOnSuccessListener { reviewInfo ->
                val validActivity = safeActivity ?: run {
                    onComplete?.invoke(ReviewResult.ActivityUnavailable)
                    return@addOnSuccessListener
                }

                reviewManager.launchReviewFlow(validActivity, reviewInfo)
                    .addOnCompleteListener {
                        markReviewAttempted()
                        Log.i(TAG, "In-App Review flow completed via Task.")
                        onComplete?.invoke(ReviewResult.Completed)
                    }
            }
            .addOnFailureListener { e ->
                Log.w(TAG, "In-App Review request failed silently: ${e.message}", e)
                onComplete?.invoke(ReviewResult.Failed(e))
            }
    }

    /**
     * Updates timestamps and session counters after an attempt.
     */
    private fun markReviewAttempted() {
        sessionAttemptCount++
        preferences?.edit()
            ?.putLong(KEY_LAST_REQUEST_TIMESTAMP, System.currentTimeMillis())
            ?.apply()
    }

    /**
     * Clears cached references.
     */
    fun cleanup() {
        activityRef.clear()
    }

    companion object {
        private const val TAG = "InAppReviewHelper"
        private const val KEY_LAST_REQUEST_TIMESTAMP = "play_review_last_request_timestamp"
        private const val KEY_TOTAL_EVENTS_COUNT = "play_review_total_events_count"
    }
}
