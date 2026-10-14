package com.arrowz.app.play

import android.app.Activity
import android.util.Log
import android.view.View
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.google.android.material.snackbar.Snackbar
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallState
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.ActivityResult
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import java.lang.ref.WeakReference
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

/**
 * Result returned by the In-App Update check operation.
 */
sealed class UpdateCheckResult {
    /** The native Google Play flexible update bottom-sheet flow was started. */
    data object FlowStarted : UpdateCheckResult()

    /** An in-progress flexible update was resumed. */
    data object ResumedInProgress : UpdateCheckResult()

    /** An update was previously downloaded and the restart prompt was displayed. */
    data object AlreadyDownloaded : UpdateCheckResult()

    /** No update is currently available on Google Play. */
    data object NoUpdateAvailable : UpdateCheckResult()

    /** An update is available, but the flexible update type is not allowed. */
    data object FlexibleUpdateNotAllowed : UpdateCheckResult()

    /** The host Activity is unavailable, finishing, or destroyed. */
    data object ActivityUnavailable : UpdateCheckResult()

    /** The ActivityResultLauncher has not been initialized or registered. */
    data object LauncherUnavailable : UpdateCheckResult()

    /** An error occurred while checking for updates (failed silently). */
    data class Failed(val exception: Throwable) : UpdateCheckResult()
}

/**
 * Result returned by Google Play's update flow activity contract.
 */
sealed class UpdateFlowResult {
    /** The user accepted the update flow and download has initiated. */
    data object Accepted : UpdateFlowResult()

    /** The user declined or canceled the update bottom sheet. */
    data object Canceled : UpdateFlowResult()

    /** The update flow failed with [ActivityResult.RESULT_IN_APP_UPDATE_FAILED]. */
    data object Failed : UpdateFlowResult()

    /** Another undocumented result code was returned. */
    data class Other(val resultCode: Int) : UpdateFlowResult()
}

/**
 * Production-ready helper for Google Play's native In-App Updates (Flexible Flow).
 *
 * Implements 100% native Play Store UI using official Play Core KTX libraries:
 * - Play Store's own native bottom sheet for flexible update consent.
 * - Play Store's own download progress in the background.
 * - Native Material [Snackbar] with "RESTART" action when downloaded.
 * - Zero custom dialogs, zero custom bottom sheets, zero custom banners.
 *
 * Lifecycle and Architecture:
 * - Implements [DefaultLifecycleObserver] for automatic attachment to [ComponentActivity].
 * - Uses [WeakReference] to [Activity] to guarantee zero memory leaks.
 * - Uses modern [ActivityResultLauncher] via [ActivityResultContracts.StartIntentSenderForResult]
 *   (never deprecated [Activity.startActivityForResult] request codes).
 * - Coroutine-ready with `.await()` support alongside safe callback overloads.
 * - All tasks wrapped with safety listeners; zero crashes on cancellation or failure.
 *
 * @param activity The host Activity context.
 * @param appUpdateManager Injected [AppUpdateManager], defaulting to [AppUpdateManagerFactory.create].
 * @param externalLauncher Optional external [ActivityResultLauncher], if pre-registered by caller.
 * @param onUpdateResult Optional callback invoked when the update flow activity finishes.
 * @param onInstallStatusChanged Optional callback for observing raw [InstallState] changes.
 */
class AppUpdateHelper(
    activity: Activity,
    private val appUpdateManager: AppUpdateManager = AppUpdateManagerFactory.create(activity),
    externalLauncher: ActivityResultLauncher<IntentSenderRequest>? = null,
    var onUpdateResult: ((UpdateFlowResult) -> Unit)? = null,
    var onInstallStatusChanged: ((InstallState) -> Unit)? = null
) : DefaultLifecycleObserver {

    private val activityRef = WeakReference(activity)

    /** Safe reference to host Activity; null if finishing or destroyed. */
    private val safeActivity: Activity?
        get() = activityRef.get()?.takeIf { !it.isFinishing && !it.isDestroyed }

    private var updateLauncher: ActivityResultLauncher<IntentSenderRequest>? = externalLauncher
    private var isListenerRegistered = false

    /**
     * Listener for flexible download progress and completion.
     */
    private val installStateUpdatedListener = InstallStateUpdatedListener { state ->
        when (state.installStatus()) {
            InstallStatus.DOWNLOADED -> {
                Log.i(TAG, "InstallState: DOWNLOADED. Prompting restart via native Snackbar.")
                popupSnackbarForCompleteUpdate()
                onInstallStatusChanged?.invoke(state)
            }
            InstallStatus.FAILED -> {
                Log.w(
                    TAG,
                    "InstallState: FAILED (errorCode: ${state.installErrorCode()}). Failing silently."
                )
                onInstallStatusChanged?.invoke(state)
            }
            InstallStatus.DOWNLOADING -> {
                val bytes = state.bytesDownloaded()
                val total = state.totalBytesToDownload()
                Log.d(TAG, "InstallState: DOWNLOADING ($bytes / $total bytes).")
                onInstallStatusChanged?.invoke(state)
            }
            InstallStatus.INSTALLING -> {
                Log.d(TAG, "InstallState: INSTALLING.")
                onInstallStatusChanged?.invoke(state)
            }
            InstallStatus.INSTALLED -> {
                Log.i(TAG, "InstallState: INSTALLED. Update completed.")
                unregisterListener()
                onInstallStatusChanged?.invoke(state)
            }
            InstallStatus.CANCELED -> {
                Log.d(TAG, "InstallState: CANCELED.")
                onInstallStatusChanged?.invoke(state)
            }
            InstallStatus.PENDING -> {
                Log.d(TAG, "InstallState: PENDING.")
                onInstallStatusChanged?.invoke(state)
            }
            else -> {
                Log.d(TAG, "InstallState: Status = ${state.installStatus()}")
                onInstallStatusChanged?.invoke(state)
            }
        }
    }

    init {
        // Automatically attach lifecycle observer if the Activity is a LifecycleOwner
        if (activity is LifecycleOwner) {
            activity.lifecycle.addObserver(this)
        }

        // Auto-register ActivityResultLauncher if not provided and activity is ComponentActivity
        if (updateLauncher == null && activity is ComponentActivity) {
            updateLauncher = activity.activityResultRegistry.register(
                "play_app_update_${activity.javaClass.simpleName}_${System.identityHashCode(this)}",
                ActivityResultContracts.StartIntentSenderForResult()
            ) { result ->
                handleActivityResult(result.resultCode)
            }
        }
    }

    /**
     * Manually assign an [ActivityResultLauncher] if registered externally (e.g. in Compose).
     */
    fun setLauncher(launcher: ActivityResultLauncher<IntentSenderRequest>) {
        this.updateLauncher = launcher
    }

    /**
     * Handles result codes from the Google Play update flow.
     */
    private fun handleActivityResult(resultCode: Int) {
        when (resultCode) {
            Activity.RESULT_OK -> {
                Log.i(TAG, "ActivityResult: User accepted flexible update flow (RESULT_OK).")
                onUpdateResult?.invoke(UpdateFlowResult.Accepted)
            }
            Activity.RESULT_CANCELED -> {
                Log.w(TAG, "ActivityResult: User canceled or dismissed update flow (RESULT_CANCELED).")
                onUpdateResult?.invoke(UpdateFlowResult.Canceled)
            }
            ActivityResult.RESULT_IN_APP_UPDATE_FAILED -> {
                Log.e(
                    TAG,
                    "ActivityResult: Update flow failed with RESULT_IN_APP_UPDATE_FAILED."
                )
                onUpdateResult?.invoke(UpdateFlowResult.Failed)
            }
            else -> {
                Log.d(TAG, "ActivityResult: Update flow returned code: $resultCode")
                onUpdateResult?.invoke(UpdateFlowResult.Other(resultCode))
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Core Update Logic
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Asynchronously checks for updates via Google Play using Kotlin Coroutines.
     *
     * Call this in `onCreate()` or upon landing on the main screen.
     *
     * Flow:
     * 1. If [UpdateAvailability.UPDATE_AVAILABLE] and [AppUpdateType.FLEXIBLE] is allowed:
     *    Launches the official Google Play bottom sheet via [ActivityResultLauncher].
     * 2. If [UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS]:
     *    Resumes the in-progress update flow immediately.
     * 3. If [InstallStatus.DOWNLOADED]:
     *    Prompts the user to restart using the native completion [Snackbar].
     * 4. Fails silently on any network or API error without crashing.
     *
     * @return [UpdateCheckResult] indicating the outcome.
     */
    suspend fun checkForUpdate(): UpdateCheckResult = withContext(Dispatchers.Main) {
        val currentActivity = safeActivity ?: return@withContext UpdateCheckResult.ActivityUnavailable
        val launcher = updateLauncher ?: run {
            Log.w(TAG, "Cannot start update flow: ActivityResultLauncher is null.")
            return@withContext UpdateCheckResult.LauncherUnavailable
        }

        try {
            val appUpdateInfo = appUpdateManager.appUpdateInfo.await()
            handleUpdateInfo(appUpdateInfo, launcher)
        } catch (e: Exception) {
            Log.w(TAG, "In-app update check failed silently: ${e.message}", e)
            UpdateCheckResult.Failed(e)
        }
    }

    /**
     * Non-coroutine overload of [checkForUpdate] wrapping Google Play Tasks with
     * safe [com.google.android.gms.tasks.OnSuccessListener] and
     * [com.google.android.gms.tasks.OnFailureListener].
     *
     * @param onResult Optional callback with the [UpdateCheckResult].
     */
    fun checkForUpdate(onResult: ((UpdateCheckResult) -> Unit)? = null) {
        val currentActivity = safeActivity ?: run {
            onResult?.invoke(UpdateCheckResult.ActivityUnavailable)
            return
        }
        val launcher = updateLauncher ?: run {
            Log.w(TAG, "Cannot start update flow: ActivityResultLauncher is null.")
            onResult?.invoke(UpdateCheckResult.LauncherUnavailable)
            return
        }

        appUpdateManager.appUpdateInfo
            .addOnSuccessListener { info ->
                val result = handleUpdateInfo(info, launcher)
                onResult?.invoke(result)
            }
            .addOnFailureListener { e ->
                Log.w(TAG, "In-app update check failed silently: ${e.message}", e)
                onResult?.invoke(UpdateCheckResult.Failed(e))
            }
    }

    /**
     * Inspects [AppUpdateInfo] and starts/resumes the appropriate flexible flow.
     */
    private fun handleUpdateInfo(
        info: AppUpdateInfo,
        launcher: ActivityResultLauncher<IntentSenderRequest>
    ): UpdateCheckResult {
        return when (info.updateAvailability()) {
            UpdateAvailability.UPDATE_AVAILABLE -> {
                if (info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)) {
                    val options = AppUpdateOptions.newBuilder(AppUpdateType.FLEXIBLE).build()
                    val started = appUpdateManager.startUpdateFlowForResult(info, launcher, options)
                    if (started) {
                        Log.i(TAG, "Google Play flexible update flow successfully started.")
                        UpdateCheckResult.FlowStarted
                    } else {
                        Log.w(TAG, "Google Play update flow failed to launch.")
                        UpdateCheckResult.Failed(
                            IllegalStateException("startUpdateFlowForResult returned false")
                        )
                    }
                } else {
                    Log.d(TAG, "Update available, but FLEXIBLE update type is not allowed.")
                    UpdateCheckResult.FlexibleUpdateNotAllowed
                }
            }
            UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS -> {
                Log.i(TAG, "Developer-triggered update already in progress. Resuming flexible flow...")
                val options = AppUpdateOptions.newBuilder(AppUpdateType.FLEXIBLE).build()
                appUpdateManager.startUpdateFlowForResult(info, launcher, options)
                UpdateCheckResult.ResumedInProgress
            }
            else -> {
                if (info.installStatus() == InstallStatus.DOWNLOADED) {
                    Log.i(TAG, "Update already downloaded. Presenting restart prompt.")
                    popupSnackbarForCompleteUpdate()
                    UpdateCheckResult.AlreadyDownloaded
                } else {
                    Log.d(
                        TAG,
                        "No update available (availability: ${info.updateAvailability()}, installStatus: ${info.installStatus()})."
                    )
                    UpdateCheckResult.NoUpdateAvailable
                }
            }
        }
    }

    /**
     * Displays Google Play's standard native completion prompt:
     * A persistent [Snackbar] with a "RESTART" action that calls [AppUpdateManager.completeUpdate].
     *
     * @param anchorView Optional anchor view. If null, attaches to `android.R.id.content`.
     * @param message Text prompt (default: "An update has just been downloaded.").
     * @param actionText Action button label (default: "RESTART").
     */
    fun popupSnackbarForCompleteUpdate(
        anchorView: View? = null,
        message: String = "An update has just been downloaded.",
        actionText: String = "RESTART"
    ) {
        val currentActivity = safeActivity ?: run {
            Log.w(TAG, "Cannot display complete-update Snackbar: Activity is unavailable.")
            return
        }
        val targetView = anchorView
            ?: currentActivity.findViewById(android.R.id.content)
            ?: run {
                Log.w(TAG, "Cannot display complete-update Snackbar: root view not found.")
                return
            }

        Snackbar.make(targetView, message, Snackbar.LENGTH_INDEFINITE).apply {
            setAction(actionText) {
                Log.i(TAG, "Restart action tapped. Calling appUpdateManager.completeUpdate()...")
                appUpdateManager.completeUpdate()
            }
            show()
        }
    }

    /**
     * Re-checks for stalled or completed updates upon returning to the foreground.
     *
     * Call this in `onResume()` to ensure updates downloaded in background or stalled mid-flow
     * are properly surfaced.
     */
    fun resumeStalledUpdateIfAny() {
        val launcher = updateLauncher ?: return
        appUpdateManager.appUpdateInfo
            .addOnSuccessListener { info ->
                if (info.installStatus() == InstallStatus.DOWNLOADED) {
                    Log.i(TAG, "onResume: Update is DOWNLOADED. Presenting restart prompt.")
                    popupSnackbarForCompleteUpdate()
                } else if (info.updateAvailability() ==
                    UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                ) {
                    Log.i(TAG, "onResume: Resuming stalled DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS...")
                    val options = AppUpdateOptions.newBuilder(AppUpdateType.FLEXIBLE).build()
                    appUpdateManager.startUpdateFlowForResult(info, launcher, options)
                }
            }
            .addOnFailureListener { e ->
                Log.d(TAG, "onResume: Stalled update check failed silently: ${e.message}")
            }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Lifecycle Management (Prevents Leaks)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Registers the [InstallStateUpdatedListener] to monitor download progress.
     */
    fun registerListener() {
        if (!isListenerRegistered) {
            appUpdateManager.registerListener(installStateUpdatedListener)
            isListenerRegistered = true
            Log.d(TAG, "InstallStateUpdatedListener registered.")
        }
    }

    /**
     * Unregisters the [InstallStateUpdatedListener] to prevent leaks.
     */
    fun unregisterListener() {
        if (isListenerRegistered) {
            try {
                appUpdateManager.unregisterListener(installStateUpdatedListener)
                isListenerRegistered = false
                Log.d(TAG, "InstallStateUpdatedListener unregistered.")
            } catch (e: Exception) {
                Log.w(TAG, "Error unregistering listener: ${e.message}")
            }
        }
    }

    override fun onStart(owner: LifecycleOwner) {
        registerListener()
    }

    override fun onResume(owner: LifecycleOwner) {
        registerListener()
        resumeStalledUpdateIfAny()
    }

    override fun onStop(owner: LifecycleOwner) {
        unregisterListener()
    }

    override fun onDestroy(owner: LifecycleOwner) {
        cleanup()
    }

    /**
     * Manual lifecycle hooks for non-LifecycleOwner activities or custom wrappers.
     */
    fun onStart() = registerListener()
    fun onResume() {
        registerListener()
        resumeStalledUpdateIfAny()
    }
    fun onStop() = unregisterListener()
    fun onPause() = unregisterListener()

    /**
     * Releases all listeners and references.
     */
    fun cleanup() {
        unregisterListener()
        try {
            updateLauncher?.unregister()
        } catch (_: Exception) {}
        updateLauncher = null
        activityRef.clear()
    }

    companion object {
        private const val TAG = "AppUpdateHelper"
    }
}
