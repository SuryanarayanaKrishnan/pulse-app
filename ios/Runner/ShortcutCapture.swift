// On-device capture for iOS. UNCOMPILED: written without Xcode, review before shipping.
//
// iOS cannot read SMS or notifications, so a Shortcuts "Transaction"
// automation (Wallet > a card > Transaction) runs the "Record Payment" action
// below every time a card is tapped. The action only appends the payment to a
// small file inbox on this phone; no server is involved. Flutter drains the
// inbox (channel `pulse/shortcut_inbox`) when the app starts or returns to the
// foreground and feeds each item to the on-device pipeline.
//
// Setup is documented in the README ("iOS: Shortcuts automation").

import AppIntents
import Flutter
import Foundation

// MARK: - Inbox

/// One JSON file per payment in Application Support/PulseInbox. Files are
/// written atomically and stay readable after the first unlock, so the intent
/// also works while the phone is locked.
enum ShortcutInbox {
  private static let lock = NSLock()

  private static var directory: URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let dir = base.appendingPathComponent("PulseInbox", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  /// Appends one payment. `amount` is the raw text from Shortcuts ("AED 45.50");
  /// Dart parses it.
  @discardableResult
  static func append(amount: String, merchant: String, card: String?) throws -> String {
    let id = UUID().uuidString
    var item: [String: Any] = [
      "id": id,
      "amount": amount,
      "merchant": merchant,
      "ts": Int(Date().timeIntervalSince1970),
    ]
    if let card = card, !card.isEmpty { item["card"] = card }
    let data = try JSONSerialization.data(withJSONObject: item)
    lock.lock()
    defer { lock.unlock() }
    try data.write(
      to: directory.appendingPathComponent("\(id).json"),
      options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
    )
    return id
  }

  /// Everything waiting, oldest first.
  static func peek() -> [[String: Any]] {
    lock.lock()
    defer { lock.unlock() }
    let files = (try? FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil)) ?? []
    return files
      .filter { $0.pathExtension == "json" }
      .compactMap { url -> (Int, [String: Any])? in
        guard let data = try? Data(contentsOf: url),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return ((obj["ts"] as? Int) ?? 0, obj)
      }
      .sorted { $0.0 < $1.0 }
      .map { $0.1 }
  }

  /// Removes items Flutter has taken over.
  static func ack(_ ids: [String]) {
    lock.lock()
    defer { lock.unlock() }
    for id in ids {
      // Ids are UUIDs we generated; refuse anything that could leave the folder.
      guard !id.contains("/"), !id.contains("..") else { continue }
      try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(id).json"))
    }
  }
}

// MARK: - Flutter channel

final class ShortcutInboxPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "pulse/shortcut_inbox", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ShortcutInboxPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "peekPending":
      result(ShortcutInbox.peek())
    case "ackPending":
      let ids = (call.arguments as? [String: Any])?["ids"] as? [String] ?? []
      ShortcutInbox.ack(ids)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

// MARK: - App Intent

/// The action a Shortcuts Transaction automation runs. It does not open the
/// app and does not touch the network.
@available(iOS 16.0, *)
struct RecordPaymentIntent: AppIntent {
  static let title: LocalizedStringResource = "Record Payment"
  static let description = IntentDescription(
    "Adds a card payment to Pulse on this phone. Nothing is sent to a server.")
  static let openAppWhenRun: Bool = false

  @Parameter(title: "Amount")
  var amount: String

  @Parameter(title: "Merchant")
  var merchant: String

  @Parameter(title: "Card")
  var card: String?

  func perform() async throws -> some IntentResult {
    try ShortcutInbox.append(amount: amount, merchant: merchant, card: card)
    return .result()
  }
}

@available(iOS 16.0, *)
struct PulseShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: RecordPaymentIntent(),
      phrases: ["Record a payment in \(.applicationName)"],
      shortTitle: "Record Payment",
      systemImageName: "creditcard"
    )
  }
}
