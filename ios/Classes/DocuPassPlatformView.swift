import Flutter
import UIKit
import SwiftUI
import DocuPass

class DocuPassViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        DocuPassPlatformViewImpl(frame: frame, viewId: viewId, args: args, messenger: messenger)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

/// Hosts the native SwiftUI `DocuPassView` as a Flutter platform view; sends the
/// result back over a per-view MethodChannel as `onResult`.
class DocuPassPlatformViewImpl: NSObject, FlutterPlatformView {
    private let container = UIView()
    private var hosting: UIHostingController<AnyView>?
    private let channel: FlutterMethodChannel

    init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.idanalyzer.docupass/view_\(viewId)", binaryMessenger: messenger)
        super.init()
        container.frame = frame

        let params = args as? [String: Any] ?? [:]
        guard let reference = params["reference"] as? String, !reference.isEmpty else { return }

        let config = DocuPassConfig(
            reference: reference,
            partyId: params["partyId"] as? String,
            baseURLOverride: params["baseUrl"] as? String
        )
        let theme = DocuPassTheme(
            primaryColor: (params["brandColor"] as? String).flatMap { Color(hex: $0) },
            logoURL: (params["logoUrl"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        )
        let strings = DocuPassStrings().applying((params["labels"] as? [String: String]) ?? [:])
        let root = DocuPassView(config: config, strings: strings, theme: theme) { [weak self] result in self?.emit(result) }
        let hc = UIHostingController(rootView: AnyView(root))
        hosting = hc
        hc.view.frame = container.bounds
        hc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hc.view.backgroundColor = .clear
        container.addSubview(hc.view)
    }

    func view() -> UIView { container }

    private func emit(_ result: DocuPassResult) {
        var map: [String: Any] = ["reference": result.reference]
        switch result {
        case let .completed(_, url, code):
            map["status"] = "completed"
            if let code { map["code"] = code }
            if let url { map["redirectUrl"] = url }
        case let .failed(_, code, msg, url):
            map["status"] = "failed"
            if let code { map["code"] = code }
            if let msg { map["message"] = msg }
            if let url { map["redirectUrl"] = url }
        case .cancelled:
            map["status"] = "cancelled"
        case let .error(_, err):
            map["status"] = "error"
            if let c = err.code { map["code"] = c }
            if let m = err.message { map["message"] = m }
        }
        channel.invokeMethod("onResult", arguments: map)
    }
}
