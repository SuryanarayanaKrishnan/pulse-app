import Flutter
import UIKit
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets scheduled reminders show while the app is open (flutter_local_notifications).
    UNUserNotificationCenter.current().delegate = self
    // Daily encrypted backup (see docs/BACKUP.md; not verified without Xcode).
    WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "pulse.backup.daily", earliestBeginInSeconds: 86400)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ShortcutInboxPlugin") {
      ShortcutInboxPlugin.register(with: registrar)
    }
  }
}
