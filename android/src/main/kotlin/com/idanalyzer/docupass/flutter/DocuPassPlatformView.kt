package com.idanalyzer.docupass.flutter

import android.content.Context
import android.view.View
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.ComposeView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.idanalyzer.docupass.DocuPassConfig
import com.idanalyzer.docupass.DocuPassResult
import com.idanalyzer.docupass.ui.DocuPassStrings
import com.idanalyzer.docupass.ui.DocuPassTheme
import com.idanalyzer.docupass.ui.DocuPassView
import com.idanalyzer.docupass.ui.withOverrides
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class DocuPassViewFactory(
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = (args as? Map<String, Any?>) ?: emptyMap()
        return DocuPassPlatformView(context, viewId, params, messenger)
    }
}

/**
 * Hosts the native Compose [DocuPassView] inside a Flutter platform view. Because
 * the view lives outside an Activity content tree, it supplies its own ViewTree
 * lifecycle / viewmodel-store / saved-state owners so Compose can run. Results are
 * sent back over a per-view MethodChannel as `onResult`.
 */
class DocuPassPlatformView(
    context: Context,
    viewId: Int,
    params: Map<String, Any?>,
    messenger: BinaryMessenger,
) : PlatformView, LifecycleOwner, ViewModelStoreOwner, SavedStateRegistryOwner {

    private val channel = MethodChannel(messenger, "com.idanalyzer.docupass/view_$viewId")
    private val lifecycleRegistry = LifecycleRegistry(this)
    private val store = ViewModelStore()
    private val savedStateController = SavedStateRegistryController.create(this)
    private val composeView = ComposeView(context)

    init {
        savedStateController.performAttach()
        savedStateController.performRestore(null)
        lifecycleRegistry.currentState = Lifecycle.State.RESUMED

        composeView.setViewTreeLifecycleOwner(this)
        composeView.setViewTreeViewModelStoreOwner(this)
        composeView.setViewTreeSavedStateRegistryOwner(this)

        val reference = params["reference"] as? String
        if (!reference.isNullOrBlank()) {
            val config = DocuPassConfig(
                reference = reference,
                partyId = params["partyId"] as? String,
                baseUrlOverride = params["baseUrl"] as? String,
            )
            val theme = DocuPassTheme(
                primaryColor = (params["brandColor"] as? String)?.takeIf { it.isNotBlank() }
                    ?.let { runCatching { Color(android.graphics.Color.parseColor(it)) }.getOrNull() },
                logoUrl = (params["logoUrl"] as? String)?.takeIf { it.isNotBlank() },
            )
            @Suppress("UNCHECKED_CAST")
            val labels = (params["labels"] as? Map<String, Any?>)?.entries
                ?.filter { it.value is String }?.associate { it.key to it.value as String }
                ?: emptyMap()
            val strings = DocuPassStrings().withOverrides(labels)
            composeView.setContent {
                DocuPassView(config = config, strings = strings, theme = theme, onResult = ::emit)
            }
        }
    }

    override fun getView(): View = composeView

    override fun dispose() {
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        store.clear()
    }

    override val lifecycle: Lifecycle get() = lifecycleRegistry
    override val viewModelStore: ViewModelStore get() = store
    override val savedStateRegistry: SavedStateRegistry get() = savedStateController.savedStateRegistry

    private fun emit(result: DocuPassResult) {
        val map = HashMap<String, Any?>()
        map["reference"] = result.reference
        when (result) {
            is DocuPassResult.Completed -> {
                map["status"] = "completed"; map["code"] = result.code; map["redirectUrl"] = result.redirectUrl
            }
            is DocuPassResult.Failed -> {
                map["status"] = "failed"; map["code"] = result.code
                map["message"] = result.message; map["redirectUrl"] = result.redirectUrl
            }
            is DocuPassResult.Cancelled -> map["status"] = "cancelled"
            is DocuPassResult.Error -> {
                map["status"] = "error"; map["code"] = result.error.code; map["message"] = result.error.message
            }
        }
        channel.invokeMethod("onResult", map)
    }
}
