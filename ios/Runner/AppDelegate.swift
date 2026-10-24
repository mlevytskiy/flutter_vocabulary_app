import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Apple's SpeechAnalyzer for Talk with AI (owner, 2026-10-24).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SpeechAnalyzerBridge") {
      SpeechAnalyzerBridge.register(with: registrar)
    }
  }
}
