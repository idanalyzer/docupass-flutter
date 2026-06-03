import Flutter
import UIKit

public class DocupassFlutterPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let factory = DocuPassViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "com.idanalyzer.docupass/view")
    }
}
