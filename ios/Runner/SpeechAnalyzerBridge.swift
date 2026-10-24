import AVFoundation
import Flutter
import Speech

/// Apple's SpeechAnalyzer (iOS 26) for Talk with AI's speech input (owner,
/// 2026-10-24): on-device, Apple's newer speech model, as a third engine
/// beside speech_to_text and speech_to_text_pro. Lives in the Runner, not in
/// a package (CLAUDE.md: no new packages).
///
/// Method channel `vocab/speech_analyzer`:
/// - `prepare` → "ready" | "permissionDenied" | "unavailable:<why, for the
///   learner>" (asks for the microphone and speech permissions, downloads the
///   English model once). Apple's newer SpeechTranscriber runs only on some
///   iPhones; elsewhere its DictationTranscriber listens (owner, 2026-10-24);
/// - `start` `{"words": [practice words]}` → starts listening; words arrive
///   on the event channel. With words, Apple's dictation model listens with
///   them as hints (`AnalysisContext.contextualStrings`) and, when its best
///   guess misses them but an alternative has one, takes that alternative
///   (owner, 2026-10-24: "saline" was never heard);
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
      result(call.method == "prepare" ? "unavailable:Apple SpeechAnalyzer needs iOS 26 or newer." : nil)
      return
    }
    Task { @MainActor in
      switch call.method {
      case "prepare":
        result(await AnalyzerSession.prepare())
      case "start":
        if let old = self.session as? AnalyzerSession { await old.cancel() }
        let words = ((call.arguments as? [String: Any])?["words"] as? [String] ?? [])
          .map { $0.trimmingCharacters(in: .whitespaces) }
          .filter { !$0.isEmpty }
        let s = AnalyzerSession(hints: words) { [weak self] text in self?.send(text) }
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
  /// The practice words to listen for; none: the plain transcriber.
  private let hints: [String]
  private let audio = AVAudioEngine()
  private var analyzer: SpeechAnalyzer?
  private var input: AsyncStream<AnalyzerInput>.Continuation?
  private var results: Task<Void, Never>?
  private var finalized = ""
  private var volatile = ""

  init(hints: [String], onText: @escaping (String) -> Void) {
    self.hints = hints
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

  /// Whether this iPhone runs SpeechTranscriber (Apple's newer model) in
  /// English; otherwise DictationTranscriber listens. Set by [prepare].
  static var transcriberUsable = false

  /// Permissions, the analyzer and the English model.
  static func prepare() async -> String {
    let mic = await AVAudioApplication.requestRecordPermission()
    NSLog("SpeechAnalyzerBridge: microphone permission \(mic)")
    if !mic { return "permissionDenied" }
    let speech = await withCheckedContinuation { (done: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
      SFSpeechRecognizer.requestAuthorization { done.resume(returning: $0) }
    }
    NSLog("SpeechAnalyzerBridge: speech recognition status \(speech.rawValue)")
    if speech == .denied || speech == .restricted { return "permissionDenied" }

    let transcriberLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale)
    transcriberUsable = SpeechTranscriber.isAvailable && transcriberLocale != nil
    let dictationUsable = (await DictationTranscriber.supportedLocale(equivalentTo: locale)) != nil
    NSLog("SpeechAnalyzerBridge: transcriber \(transcriberUsable), dictation \(dictationUsable)")
    if !transcriberUsable && !dictationUsable {
      return "unavailable:This iPhone has no English model for Apple SpeechAnalyzer."
    }
    do {
      var modules: [any SpeechModule] = []
      if transcriberUsable { modules.append(transcriber()) }
      if dictationUsable { modules.append(dictation()) }
      if let request = try await AssetInventory.assetInstallationRequest(supporting: modules) {
        try await request.downloadAndInstall()
      }
    } catch {
      NSLog("SpeechAnalyzerBridge: model download failed \(error)")
      return "unavailable:Apple's English speech model could not be downloaded. Check the internet and try again."
    }
    return "ready"
  }

  private static func dictation() -> DictationTranscriber {
    DictationTranscriber(
      locale: locale, contentHints: [.shortForm], transcriptionOptions: [],
      reportingOptions: [.volatileResults, .alternativeTranscriptions], attributeOptions: [])
  }

  /// One result: its words settle ([isFinal]) or are still being worked out.
  private func take(_ words: String, isFinal: Bool) {
    let words = words.trimmingCharacters(in: .whitespaces)
    if isFinal {
      if !words.isEmpty { finalized = [finalized, words].filter { !$0.isEmpty }.joined(separator: " ") }
      volatile = ""
    } else {
      volatile = words
    }
    onText(text)
  }

  /// Whether [text] holds one of the hints as a word or the start of one
  /// ("salines" holds "saline").
  private func hasHint(_ text: String) -> Bool {
    let lower = text.lowercased()
    return hints.contains { hint in
      let h = hint.lowercased()
      var from = lower.startIndex
      while let r = lower.range(of: h, range: from..<lower.endIndex) {
        let before = r.lowerBound == lower.startIndex || !lower[lower.index(before: r.lowerBound)].isLetter
        if before { return true }
        from = r.upperBound
      }
      return false
    }
  }

  /// The best words of a dictation result: its text, or the first
  /// alternative holding a practice word when the text holds none.
  private func best(_ text: String, _ alternatives: [String]) -> String {
    if hints.isEmpty || hasHint(text) { return text }
    return alternatives.first(where: hasHint) ?? text
  }

  func start() async throws {
    let module: any SpeechModule
    // Hints need the dictation model; so does an iPhone without the newer one.
    if hints.isEmpty && Self.transcriberUsable {
      let transcriber = Self.transcriber()
      module = transcriber
      results = Task { [weak self] in
        do {
          for try await r in transcriber.results {
            self?.take(String(r.text.characters), isFinal: r.isFinal)
          }
        } catch {}
      }
    } else {
      // Apple's dictation model is the one that listens with hints.
      let dictation = Self.dictation()
      module = dictation
      if let request = try await AssetInventory.assetInstallationRequest(supporting: [dictation]) {
        try await request.downloadAndInstall()
      }
      results = Task { [weak self] in
        do {
          for try await r in dictation.results {
            guard let self else { return }
            let words = self.best(String(r.text.characters), r.alternatives.map { String($0.characters) })
            self.take(words, isFinal: r.isFinal)
          }
        } catch {}
      }
    }
    let analyzer = SpeechAnalyzer(modules: [module])
    self.analyzer = analyzer
    if !hints.isEmpty {
      let context = AnalysisContext()
      context.contextualStrings[.general] = hints
      try await analyzer.setContext(context)
    }
    guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module]) else {
      throw NSError(domain: "SpeechAnalyzerBridge", code: 1, userInfo: [NSLocalizedDescriptionKey: "no audio format"])
    }
    let (stream, builder) = AsyncStream<AnalyzerInput>.makeStream()
    input = builder

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
