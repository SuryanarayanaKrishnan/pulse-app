// On-device capture for iOS. UNCOMPILED: written without Xcode, review before shipping.
//
// iOS cannot read SMS or notifications, so a Shortcuts Wallet automation
// ("When I tap any of my Wallet passes or payment cards") runs the "Record Payment" action
// below every time a card is tapped. The action only appends the payment to a
// small file inbox on this phone; no server is involved. Flutter drains the
// inbox (channel `pulse/shortcut_inbox`) when the app starts or returns to the
// foreground and feeds each item to the on-device pipeline.
//
// Setup is documented in docs/SHORTCUT_LINKS.md and the in-app guided screens.

import AppIntents
import Flutter
import Foundation
import Vision

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

  /// Appends one bank SMS forwarded by a Shortcuts "Message" automation. The
  /// text is parsed on the phone like an Android SMS.
  @discardableResult
  static func appendSms(body: String, sender: String?) throws -> String {
    let id = UUID().uuidString
    var item: [String: Any] = [
      "id": id,
      "kind": "sms",
      "body": body,
      "ts": Int(Date().timeIntervalSince1970),
    ]
    if let sender = sender, !sender.isEmpty { item["sender"] = sender }
    let data = try JSONSerialization.data(withJSONObject: item)
    lock.lock()
    defer { lock.unlock() }
    try data.write(
      to: directory.appendingPathComponent("\(id).json"),
      options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
    )
    return id
  }

  /// Appends text recognised on a screenshot. Only the text is kept.
  @discardableResult
  static func appendOcr(text: String, nudge: Bool = false) throws -> String {
    let id = UUID().uuidString
    var item: [String: Any] = [
      "id": id, "kind": "ocr", "body": text,
      "ts": Int(Date().timeIntervalSince1970),
    ]
    // Lets the setup screen tell the shopping-app nudge from Back Tap.
    if nudge { item["src"] = "nudge" }
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

/// The action a Shortcuts Wallet automation runs. It does not open the
/// app and does not touch the network. Only Amount is needed; Merchant and
/// Card are optional so the user maps as little as possible.
@available(iOS 16.0, *)
struct RecordPaymentIntent: AppIntent {
  static let title: LocalizedStringResource = "Record Payment"
  static let description = IntentDescription(
    "Adds a card payment to Pulse on this phone. Nothing is sent to a server.")
  static let openAppWhenRun: Bool = false

  static var parameterSummary: some ParameterSummary {
    Summary("Record \(\.$amount) at \(\.$merchant)") {
      \.$card
    }
  }

  @Parameter(title: "Amount")
  var amount: String

  @Parameter(title: "Merchant", default: "Apple Pay")
  var merchant: String

  @Parameter(title: "Card")
  var card: String?

  func perform() async throws -> some IntentResult {
    try ShortcutInbox.append(amount: amount, merchant: merchant, card: card)
    return .result()
  }
}

/// The action a Shortcuts "Message" automation runs for a bank SMS. Message
/// connects to the previous action's output, which for the first action of an
/// automation is the Shortcut Input, so the user maps nothing. Sender is
/// optional: the bank is recognised from the text.
@available(iOS 16.0, *)
struct RecordBankSmsIntent: AppIntent {
  static let title: LocalizedStringResource = "Record Bank SMS"
  static let description = IntentDescription(
    "Adds a bank text message to Pulse on this phone. Nothing is sent to a server.",
    categoryName: "Capture")
  static let openAppWhenRun: Bool = false

  static var parameterSummary: some ParameterSummary {
    Summary("Record bank text \(\.$message)") {
      \.$sender
    }
  }

  @Parameter(title: "Message", inputConnectionBehavior: .connectToPreviousIntentResult)
  var message: String

  @Parameter(title: "Sender")
  var sender: String?

  func perform() async throws -> some IntentResult {
    try ShortcutInbox.appendSms(body: message, sender: sender)
    return .result()
  }
}

/// Reads a screenshot with Apple Vision on this phone and returns only the
/// recognised text. The image is never saved or sent anywhere.
@available(iOS 16.0, *)
enum ScreenshotReader {
  /// Cheap check that recognised text carries an amount, so the gesture can
  /// answer straight away. Pulse still does the real parsing.
  static func looksLikePayment(_ text: String) -> Bool {
    text.range(
      of: #"(AED|Dhs?\.?)\s?\d|\d\s?(AED|Dhs?\b)"#,
      options: [.regularExpression, .caseInsensitive]) != nil
  }

  static func text(from file: IntentFile) throws -> String {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    let handler = VNImageRequestHandler(data: file.data, options: [:])
    try handler.perform([request])
    return (request.results ?? [])
      .compactMap { $0.topCandidates(1).first?.string }
      .joined(separator: "\n")
  }
}

/// "Capture to Pulse". The screenshot connects to the previous action's
/// output (Take Screenshot, or the image from the share sheet), so no field is
/// mapped. An App Intent cannot take the screenshot itself: iOS offers no API
/// for that, so the shortcut starts with Take Screenshot.
@available(iOS 16.0, *)
struct CaptureScreenshotIntent: AppIntent {
  static let title: LocalizedStringResource = "Capture to Pulse"
  static let description = IntentDescription(
    "Reads a screenshot on this phone and adds the payment it shows to Pulse.",
    categoryName: "Capture")
  static let openAppWhenRun: Bool = false

  @Parameter(
    title: "Screenshot", supportedTypeIdentifiers: ["public.image"],
    inputConnectionBehavior: .connectToPreviousIntentResult)
  var screenshot: IntentFile

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let text = try ScreenshotReader.text(from: screenshot)
    // Back Tap and the Action Button run with the screen still showing the
    // other app, so say in one line whether anything was found. The real
    // parsing and the Undo/Edit prompt happen in Pulse.
    guard ScreenshotReader.looksLikePayment(text) else {
      return .result(dialog: "No amount on screen. Open the payment or alert and try again.")
    }
    try ShortcutInbox.appendOcr(text: text)
    return .result(dialog: "Sent to Pulse. Open Pulse to confirm.")
  }
}

/// "Ask then Capture": the action behind the shopping-app nudge. It asks "Log
/// that order?" itself, so the shortcut needs no Show Alert action: Get Latest
/// Screenshots, then this. Cancel leaves nothing stored.
@available(iOS 16.0, *)
struct AskThenCaptureIntent: AppIntent {
  static let title: LocalizedStringResource = "Ask then Capture"
  static let description = IntentDescription(
    "Asks to log the order you just screenshotted, then adds it to Pulse.",
    categoryName: "Capture")
  static let openAppWhenRun: Bool = false

  @Parameter(
    title: "Screenshot", supportedTypeIdentifiers: ["public.image"],
    inputConnectionBehavior: .connectToPreviousIntentResult)
  var screenshot: IntentFile

  func perform() async throws -> some IntentResult {
    // Throws when the user taps Cancel, which ends the run without storing.
    try await requestConfirmation(result: .result(dialog: "Log that order?"))
    let text = try ScreenshotReader.text(from: screenshot)
    if !text.isEmpty { try ShortcutInbox.appendOcr(text: text, nudge: true) }
    return .result()
  }
}

/// Everything here appears automatically in Shortcuts, Spotlight, Siri and the
/// Action Button picker, with no shortcut to build.
@available(iOS 16.0, *)
struct PulseShortcuts: AppShortcutsProvider {
  static var shortcutTileColor: ShortcutTileColor = .teal

  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: RecordPaymentIntent(),
      phrases: [
        "Record a payment in \(.applicationName)",
        "Log a payment in \(.applicationName)",
      ],
      shortTitle: "Record Payment",
      systemImageName: "creditcard"
    )
    AppShortcut(
      intent: RecordBankSmsIntent(),
      phrases: [
        "Record a bank text in \(.applicationName)",
        "Add a bank SMS to \(.applicationName)",
      ],
      shortTitle: "Record Bank SMS",
      systemImageName: "message"
    )
    AppShortcut(
      intent: CaptureScreenshotIntent(),
      phrases: [
        "Capture a screenshot to \(.applicationName)",
        "Capture to \(.applicationName)",
      ],
      shortTitle: "Capture to Pulse",
      systemImageName: "camera.viewfinder"
    )
    AppShortcut(
      intent: AskThenCaptureIntent(),
      phrases: ["Log my last order in \(.applicationName)"],
      shortTitle: "Ask then Capture",
      systemImageName: "questionmark.bubble"
    )
  }
}
