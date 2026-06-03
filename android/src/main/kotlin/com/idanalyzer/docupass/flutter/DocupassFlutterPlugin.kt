package com.idanalyzer.docupass.flutter

import io.flutter.embedding.engine.plugins.FlutterPlugin

/** Registers the DocuPass platform view factory with the Flutter engine. */
class DocupassFlutterPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding.platformViewRegistry.registerViewFactory(
            "com.idanalyzer.docupass/view",
            DocuPassViewFactory(binding.binaryMessenger),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}
