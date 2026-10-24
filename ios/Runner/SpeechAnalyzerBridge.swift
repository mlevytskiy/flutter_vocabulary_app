import AVFoundation
import Flutter
import Speech

/// Apple's SpeechAnalyzer (iOS 26) for Talk with AI's speech input (owner,
/// 2026-10-24): on-device, Apple's newer speech model, as a third engine
/// beside speech_to_text and speech_to_text_pro. Lives in the Runner, not in
/// a package (CLAUDE.md: no new packages).
///
/// Method channel `vocab/speech_analyzer`:
/// - `prepare` → "ready" | "permissionDenied" | "unavailable" (asks for the
///   microphone and speech permissions, downloads the English model once);
/// - `start` → starts listening; words arrive on the event channel;
/// - `stop` → finishes and answers the final text;
/// - `cancel` → stops and drops what was heard.
/// Event channel `vocab/speech_analyzer/events`: `{"text": all words heard
/// in this session, "isFinal": false}` as the words come.
final class SpeechAnalyzerBridge: NSObject, FlutterStreamHandler {
  private static var shared: SpeechAnalyzerBridge?

  private var sink: FlutterEventSink?
  private var session: AnyObject?

  static func register(with registrar: FlutterPluginRegistrar) {
    let bridge = SpeechAnalyzerBridge()
    shared = bridge
    let methods = FlutterMethodChannel(name: "vocab/speech_analyzer", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(name: "vocab/speech_analyzer/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(bridge)
    methods.setMethodCallHandler { call, result in bridge.handle(call, result: result) }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func send(_ text: String) {
    DispatchQueue.main.async { [weak self] in
      self?.sink?(["text": text, "isFinal": false])
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 26.0, *) else {
      result(call.method == "prepare" ? "unavailable" : nil)
      return
    }
    Task { @MainActor in
      switch call.method {
      case "prepare":
        result(await AnalyzerSession.prepare())
      case "start":
        if let old = self.session as? AnalyzerSession { await old.cancel() }
        let s = AnalyzerSession { [weak self] text in self?.send(text) }
        self.session = s
        do {
          try await s.start()
          result(true)
        } catch {
          self.session = nil
          result(FlutterError(code: "start_failed", message: "\(error)", details: nil))
        }
      case "stop":
        let s = self.session as? AnalyzerSession
        self.session = nil
        result(await s?.stop() ?? "")
      case "cancel":
        let s = self.session as? AnalyzerSession
        self.session = nil
        await s?.cancel()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

@available(iOS 26.0, *)
@MainActor
final class AnalyzerSession {
  static let locale = Locale(identifier: "en-US")

  private let onText: (String) -> Void
  private let audio = AVAudioEngine()
  private var analyzer: SpeechAnalyzer?
  private var input: AsyncStream<AnalyzerInput>.Continuation?
  private var results: Task<Void, Never>?
  private var finalized = ""
  private var volatile = ""

  init(onText: @escaping (String) -> Void) {
    self.onText = onText
  }

  /// All the words of this session: the settled ones, then the ones still
  /// being worked out.
  var text: String {
    [finalized, volatile].filter { !$0.isEmpty }.joined(separator: " ")
  }

  private static func transcriber() -> SpeechTranscriber {
    SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
  }

  /// Permissions, the analyzer and the English model.
  static func prepare() async -> String {
    let mic = await AVAudioApplication.requestRecordPermission()
    if !mic { return "permissionDenied" }
    let speech = await withCheckedContinuation { (done: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
      SFSpeechRecognizer.requestAuthorization { done.resume(returning: $0) }
    }
    if speech == .denied || speech == .restricted { return "permissionDenied" }
    guard SpeechTranscriber.isAvailable else { return "unavailable" }
    guard await SpeechTranscriber.supportedLocale(equivalentTo: locale) != nil else { return "unavailable" }
    do {
      if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber()]) {
        try await request.downloadAndInstall()
      }
    } catch {
      return "unavailable"
    }
    return "ready"
  }

  func start() async throws {
    let transcriber = Self.transcriber()
    let analyzer = SpeechAnalyzer(modules: [transcriber])
    self.analyzer = analyzer
    guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
      throw NSError(domain: "SpeechAnalyzerBridge", code: 1, userInfo: [NSLocalizedDescriptionKey: "no audio format"])
    }
    let (stream, builder) = AsyncStream<AnalyzerInput>.makeStream()
    input = builder

    results = Task { [weak self] in
      do {
        for try await r in transcriber.results {
          let words = String(r.text.characters).trimmingCharacters(in: .whitespaces)
          guard let self else { return }
          if r.isFinal {
            if !words.isEmpty { self.finalized = [self.finalized, words].filter { !$0.isEmpty }.joined(separator: " ") }
            self.volatile = ""
          } else {
            self.volatile = words
          }
          self.onText(self.text)
        }
      } catch {}
    }

    try await analyzer.start(inputSequence: stream)

    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
    try session.setActive(true, options: .notifyOthersOnDeactivation)

    let node = audio.inputNode
    let micFormat = node.outputFormat(forBus: 0)
    guard let converter = AVAudioConverter(from: micFormat, to: format) else {
      throw NSError(domain: "SpeechAnalyzerBridge", code: 2, userInfo: [NSLocalizedDescriptionKey: "no converter"])
    }
    node.installTap(onBus: 0, bufferSize: 4096, format: micFormat) { buffer, _ in
      if let converted = Self.convert(buffer, with: converter, to: format) {
        builder.yield(AnalyzerInput(buffer: converted))
      }
    }
    audio.prepare()
    try audio.start()
  }

  /// Finishes the speech heard so far and answers all its words.
  func stop() async -> String {
    stopAudio()
    input?.finish()
    try? await analyzer?.finalizeAndFinishThroughEndOfInput()
    await results?.value
    return text
  }

  func cancel() async {
    stopAudio()
    input?.finish()
    await analyzer?.cancelAndFinishNow()
    results?.cancel()
  }

  private func stopAudio() {
    if audio.isRunning { audio.stop() }
    audio.inputNode.removeTap(onBus: 0)
  }

  /// [buffer] in the analyzer's format.
  nonisolated private static func convert(
    _ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter, to format: AVAudioFormat
  ) -> AVAudioPCMBuffer? {
    if buffer.format == format { return buffer }
    let ratio = format.sampleRate / buffer.format.sampleRate
    let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1)
    guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
    var given = false
    var error: NSError?
    converter.convert(to: out, error: &error) { _, status in
      if given {
        status.pointee = .noDataNow
        return nil
      }
      given = true
      status.pointee = .haveData
      return buffer
    }
    return error == nil ? out : nil
  }
}
