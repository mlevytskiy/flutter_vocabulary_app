import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popup_menu_2/popup_menu_2.dart';

import '../../../core/models/definition_result.dart';
import '../../../core/models/translation_result.dart';
import '../../../core/models/word_pair.dart';
import '../../../core/providers.dart';
import '../../../core/services/app_settings.dart';
import '../../../core/services/pronunciation_service.dart';
import '../../../core/services/speech_input.dart';
import '../../../core/theme/app_theme.dart';
import '../../words/widgets/MyCustomPopupMenuController.dart';
import '../../words/widgets/open_dots_menu.dart';
import 'talk_navigation.dart';
import 'talk_notifier.dart';
import 'talk_text.dart';
import 'talk_quiz_card.dart';
import 'talk_recognition_panel.dart';
import 'talk_widgets.dart';
import 'talk_word_popup.dart';

/// Said when the speech permission is refused or no recognizer is there
/// (learn-redesign AC-26, AC-28); typing keeps working.
const talkVoiceRefusedMessage = 'Allow the microphone and speech recognition in Settings to talk';

/// Said when the engine itself cannot run (owner, 2026-10-24: not a
/// permission matter), after the engine's own reason when it gives one.
const talkVoiceUnavailableMessage = 'Speech recognition is not available. Pick another engine with the tab on the right, or type.';
String talkVoiceUnavailableWith(String why) => '$why Pick another engine with the tab on the right, or type.';

/// The mic's hint and listening lines (owner, 2026-10-24: say how to use it).
const talkMicHintText = 'Tap the mic to speak, tap again to send';
const talkListeningTapText = 'Listening… tap the mic to send';
const talkListeningHoldText = 'Listening… let go to send';

/// Hands-free talk's toggle tips and lines (learn-redesign AC-29, owner
/// 2026-10-24).
const talkHandsFreeOnTip = 'Hands-free on';
const talkHandsFreeOffTip = 'Hands-free off';
const talkSpeakingText = 'Speaking…';
const talkNothingHeardText = "Didn't hear anything — tap the mic to talk";
String talkListeningPauseText(int seconds) => 'Listening… pause $seconds s to send';
String talkHandsFreeHintText(int seconds) => 'Hands-free: just talk; a pause of $seconds s sends';

/// The status line once the learner has paused for a second while the ring
/// runs down (talk-screen-b).
String talkSendingInText(int seconds) => 'Sending in $seconds…';

/// Where the hands-free loop stands: between turns, reading the AI's line
/// aloud, or listening for the learner.
enum _HandsFree { idle, speaking, listening }

/// Talk with AI (learn-redesign SCR-06; AC-20, AC-21, AC-24): bubbles, the
/// word strip, Hint, the reply field and End talk; hold-to-talk beside Send,
/// whose use has the AI's replies read aloud (AC-25, AC-26, ADR-0009).
/// Hands-free (AC-29, on by default, the bar's headset): each AI line is
/// spoken, then it listens until a pause and sends. Laid out as Direction B
/// (talk-screen-b, owner 2026-10-24): a tutor header, long bubbles with the
/// practice words highlighted and tappable (the Words screen's popup,
/// read-only), the spoken line filling like karaoke, a ring around the mic
/// counting down the pause, and one line of all the words. Opened by
/// `TalkRoute`.
///
/// With [learnFlow] it runs the Learn flow's main dialog (learn-welcome
/// AC-13, AC-14) and, once it ends or is refused for the day, goes back to
/// the flow, which shows its results.
class TalkScreen extends ConsumerStatefulWidget {
  const TalkScreen({super.key, this.collectionId, this.split = true, this.learnFlow = false});

  /// Null for the current collection, as on `LearnRoute`.
  final String? collectionId;

  /// Whether the Learn sheet's split was ticked.
  final bool split;

  /// The Learn flow's main dialog of [collectionId].
  final bool learnFlow;

  @override
  ConsumerState<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends ConsumerState<TalkScreen> with TickerProviderStateMixin {
  static const leaveText = 'Leave the talk? Words used so far are not saved.';
  static const maxReplies = 12;

  final _field = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  /// The speech input, read on the first hold; null until then.
  SpeechInput? _speech;

  /// What the first hold's init found; null while not asked yet.
  SpeechAvailability? _availability;

  /// Whether the finger is on the mic, and whether it is listening.
  bool _holding = false;
  bool _listening = false;

  /// A press shorter than [_tapMax] is a tap: listening goes on until the
  /// next tap sends it; a longer press is a hold that sends on release
  /// (owner, 2026-10-24: holding was not obvious).
  static const _tapMax = Duration(milliseconds: 400);
  Timer? _pressTimer;
  bool _pressHeld = false;
  bool _tapMode = false;

  /// Set once the mic was used in this talk: new AI replies are read aloud.
  bool _voiceUsed = false;
  bool _customReply = false;

  void _choose(String choice) {
    setState(_hfStop);
    _field.clear();
    ref.read(talkProvider(widget.collectionId, learnFlow: widget.learnFlow).notifier).send(choice, isChoice: true);
  }

  /// The hands-free loop (AC-29): its step, whether the learner paused it
  /// with the mic (or nothing was heard), and a run number that drops the
  /// callbacks of a stopped step.
  _HandsFree _hf = _HandsFree.idle;
  bool _hfPaused = false;
  bool _hfNothingHeard = false;
  int _hfRun = 0;
  PronunciationService? _tts;

  /// The karaoke of the AI line being spoken (its index in the messages, null
  /// when none; its value is the voice's progress) and the pause ring, which
  /// restarts with every piece heard.
  late final _karaoke = AnimationController(vsync: this);
  late final _ring = AnimationController(vsync: this);
  int? _spokenIndex;

  /// The voice of the line being spoken is still being fetched (no progress
  /// yet). Its bar fills over how long the last voices took to arrive
  /// ([_loadEstimate]; the Worker sends no size ahead, so there is nothing
  /// truer to count), stops short of the end while it waits, and fills up
  /// when the voice starts (owner, 2026-10-24: a real progress line, not an
  /// endless one).
  bool _voiceLoading = false;
  late final _loadBar = AnimationController(vsync: this);
  Duration _loadEstimate = const Duration(seconds: 3);
  DateTime? _loadStarted;

  /// AI lines whose voice has already played: Play and Replay on them play
  /// it again from memory, without the loading bar (owner, 2026-10-24).
  final _heard = <int>{};

  /// The word popup (the Words screen's dots popup, talk-screen-b): one menu,
  /// moved to the tapped word before it opens.
  final _popup = MyCustomPopupMenuController();
  final _stackKey = GlobalKey();
  Rect _anchor = Rect.zero;
  Rect _anchorGlobal = Rect.zero;
  WordPair? _popupWord;

  /// Any other word of an AI line whose translation the popup shows instead
  /// (owner, 2026-10-24), and the translations already looked up.
  String? _lookupWord;
  final _lookups = <String, TranslationResult?>{};

  @override
  void initState() {
    super.initState();
    _field.addListener(() {
      if (_listening || _hf == _HandsFree.listening) _scrollToEnd();
    });
    // After the first build has subscribed, so the auto-dispose talk lives.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final talk = ref.read(talkProvider(widget.collectionId, learnFlow: widget.learnFlow).notifier);
      widget.learnFlow ? talk.startFlow() : talk.start(split: widget.split);
    });
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    _hfStop();
    if (_listening) _speech?.cancel();
    _karaoke.dispose();
    _loadBar.dispose();
    _ring.dispose();
    _field.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  void _send() {
    if (_hf != _HandsFree.idle) _hfStop();
    final text = _field.text.trim();
    if (text.isEmpty) return;
    _field.clear();
    final notifier = ref.read(talkProvider(widget.collectionId, learnFlow: widget.learnFlow).notifier);
    // A spoken quiz step takes the answer instead of the AI (owner, 2026-10-24).
    if (ref.read(talkProvider(widget.collectionId, learnFlow: widget.learnFlow)).spokenQuizItem != null) {
      notifier.answerQuiz(text);
      return;
    }
    notifier.send(text);
  }

  /// The mic went down: init on the first hold, then listen while held.
  Future<void> _holdDown() async {
    _holding = true;
    if (_hf == _HandsFree.speaking) setState(_hfStop);
    final speech = _speech ??= ref.read<SpeechInput>(speechInputProvider);
    _giveHints(speech);
    if (_availability != SpeechAvailability.ready) {
      final found = await speech.init();
      if (!mounted) return;
      _setAvailability(found);
      if (found != SpeechAvailability.ready) return;
    }
    if (!_holding) return;
    _field.clear();
    setState(() {
      _listening = true;
      _voiceUsed = true;
    });
    await speech.listen(onText: (text, _) {
      if (mounted) _field.text = text;
    });
  }

  /// The mic went down: a second tap while listening only waits for its
  /// release; otherwise listening starts and the press is timed.
  void _micDown() {
    if (_listening && _tapMode) return;
    _pressHeld = false;
    _pressTimer?.cancel();
    _pressTimer = Timer(_tapMax, () => _pressHeld = true);
    _holdDown();
  }

  /// The mic came up: the tap that ends tap mode sends; a short first press
  /// keeps listening (tap mode); a hold sends at once.
  void _micUp() {
    _pressTimer?.cancel();
    if (_tapMode) {
      _tapMode = false;
      _holdUp();
      return;
    }
    if (!_pressHeld) {
      _tapMode = true;
      if (mounted) setState(() {});
      return;
    }
    _holdUp();
  }

  /// The mic was let go: stop and send the final words, if any.
  Future<void> _holdUp() async {
    _holding = false;
    if (!_listening) return;
    await _speech?.stop();
    if (!mounted) return;
    setState(() => _listening = false);
    _send();
  }

  /// A new AI line (AC-25, AC-29): hands-free speaks it and then listens;
  /// otherwise it is read aloud once the mic was used.
  Future<void> _onAiLine(String text) async {
    await ref.read(handsFreeProvider.notifier).loaded;
    if (!mounted) return;
    final talk = ref.read(talkProvider(widget.collectionId, learnFlow: widget.learnFlow));
    final index = talk.messages.length - 1;
    if (talk.mixed) {
      // Each turn starts afresh: a speaking turn listens at once (after the
      // line is read, when replies are read aloud; owner, 2026-10-24).
      _hfPaused = false;
      _hfNothingHeard = false;
      final listen = _autoListen(talk);
      if (ref.read(handsFreeProvider) || _voiceUsed) {
        await _speakLine(index, thenListen: listen);
      } else if (listen) {
        await _hfListen();
      }
      return;
    }
    if (!ref.read(handsFreeProvider)) {
      if (_voiceUsed) await _speakLine(index, thenListen: false);
      return;
    }
    if (_hfPaused) return;
    await _speakLine(index, thenListen: true);
  }

  /// Whether the mic opens by itself on the learner's turn: hands-free in a
  /// plain talk; in a mixed mission only a speaking turn or "Say something
  /// else", whatever the read-aloud switch (owner, 2026-10-24).
  bool _autoListen(TalkState talk) => talk.openQuiz != null
      // A quick check listens on its spoken steps only.
      ? talk.spokenQuizItem != null
      : talk.mixed
          ? !talk.complete && (talk.interaction == 'speak' || _customReply)
          : ref.read(handsFreeProvider);

  /// Speaks AI line [index] with the karaoke and, while its voice is fetched,
  /// the loading bar; then hands-free listens when [thenListen]. Play and
  /// Replay call it too (talk-mission).
  Future<void> _speakLine(int index, {required bool thenListen}) async {
    final messages = ref.read(talkProvider(widget.collectionId, learnFlow: widget.learnFlow)).messages;
    if (index < 0 || index >= messages.length || messages[index].role != TalkRole.ai) return;
    await ref.read(ttsVoiceProvider.notifier).loaded;
    if (!mounted) return;
    _hfStop();
    final run = _hfRun;
    final tts = ref.read(pronunciationServiceProvider);
    _tts = tts;
    final fetch = !_heard.contains(index);
    setState(() {
      _hf = _HandsFree.speaking;
      _spokenIndex = index;
      _voiceLoading = fetch;
    });
    _loadStarted = DateTime.now();
    _loadBar.value = 0;
    if (fetch) _loadBar.animateTo(0.9, duration: _loadEstimate, curve: Curves.easeOutCubic);
    _karaoke.value = 0;
    try {
      // Never listening while speaking: no echo. The voice's progress fills
      // the karaoke; its first report ends the loading.
      await tts.speakAndWait(messages[index].text, accent: Accent.us, voice: ref.read(ttsVoiceProvider),
          onProgress: (p) {
        if (!mounted || run != _hfRun) return;
        _heard.add(index);
        if (_voiceLoading) _endLoading();
        _karaoke.value = p.clamp(0, 1);
      });
    } catch (_) {}
    if (!mounted || run != _hfRun) return;
    _loadBar.stop();
    setState(() {
      _hf = _HandsFree.idle;
      _spokenIndex = null;
      _voiceLoading = false;
    });
    // A quiz step that opened while the line was read listens now too.
    if (thenListen || ref.read(talkProvider(widget.collectionId, learnFlow: widget.learnFlow)).spokenQuizItem != null) await _hfListen();
  }

  /// The voice has started: the bar fills up and fades, and how long it
  /// took tunes the next estimate.
  void _endLoading() {
    final started = _loadStarted;
    if (started != null) {
      final took = DateTime.now().difference(started).inMilliseconds;
      final next = (_loadEstimate.inMilliseconds + took) ~/ 2;
      _loadEstimate = Duration(milliseconds: next.clamp(800, 10000));
    }
    _loadBar.animateTo(1, duration: const Duration(milliseconds: 120));
    setState(() => _voiceLoading = false);
  }

  /// Play or Replay under the latest AI line: speaks it from the start; in
  /// hands-free it listens afterwards unless the loop is paused.
  void _replay(int index) {
    if (_listening) return;
    _voiceUsed = true;
    final handsFree = ref.read(handsFreeProvider);
    if (handsFree) {
      _hfPaused = false;
      _hfNothingHeard = false;
    }
    _speakLine(index, thenListen: _autoListen(ref.read(talkProvider(widget.collectionId, learnFlow: widget.learnFlow))));
  }

  /// Stop under the line being spoken: the voice stops; in hands-free the
  /// learner's turn starts as if it had ended.
  void _stopVoice() {
    final listen = _autoListen(ref.read(talkProvider(widget.collectionId, learnFlow: widget.learnFlow))) && !_hfPaused;
    setState(_hfStop);
    if (listen) _hfListen();
  }

  /// Listens until the learner's pause, then sends what was heard; with
  /// nothing heard it stops the loop until the mic is tapped.
  Future<void> _hfListen() async {
    if (!mounted || _hfPaused) return;
    final talk = ref.read(talkProvider(widget.collectionId, learnFlow: widget.learnFlow));
    if (talk.status != TalkStatus.talking || !_autoListen(talk)) return;
    final run = ++_hfRun;
    final speech = _speech ??= ref.read<SpeechInput>(speechInputProvider);
    _giveHints(speech);
    if (_availability != SpeechAvailability.ready) {
      final found = await speech.init();
      if (!mounted) return;
      _setAvailability(found);
      if (found != SpeechAvailability.ready) return;
    }
    if (run != _hfRun) return;
    await ref.read(talkPauseProvider.notifier).loaded;
    if (!mounted || run != _hfRun) return;
    _field.clear();
    final pause = Duration(seconds: ref.read(talkPauseProvider));
    _ring
      ..duration = pause
      ..reset();
    setState(() {
      _hf = _HandsFree.listening;
      _hfNothingHeard = false;
    });
    await speech.listenUntilPause(
      pause: pause,
      onPartial: (text) {
        if (!mounted || run != _hfRun) return;
        _field.text = text;
        // The ring runs down the pause from the last words heard.
        if (text.trim().isNotEmpty) _ring.forward(from: 0);
      },
      onDone: (text) {
        if (!mounted || run != _hfRun) return;
        _ring.reset();
        setState(() => _hf = _HandsFree.idle);
        if (text.trim().isEmpty) {
          setState(() {
            _hfNothingHeard = true;
            _hfPaused = true;
          });
          return;
        }
        _field.text = text;
        _send();
      },
    );
  }

  /// Stops the loop's current step (no setState: callers rebuild).
  void _hfStop() {
    _hfRun++;
    if (_hf == _HandsFree.listening) _speech?.stopListening();
    if (_hf == _HandsFree.speaking) _tts?.stop().catchError((Object _) {});
    _hf = _HandsFree.idle;
    _spokenIndex = null;
    _loadBar.stop();
    _voiceLoading = false;
    _ring.reset();
  }

  /// The mic in hands-free: pauses the loop, or listens again.
  void _hfMicTap() {
    if (_hf != _HandsFree.idle) {
      setState(() {
        _hfStop();
        _hfPaused = true;
      });
      return;
    }
    setState(() {
      _hfPaused = false;
      _hfNothingHeard = false;
    });
    _hfListen();
  }

  /// The bar's headset: hands-free on (listens now when it is the
  /// learner's turn) or off (tap/hold as before).
  Future<void> _toggleHandsFree() async {
    final on = !ref.read(handsFreeProvider);
    setState(() {
      _hfStop();
      _hfPaused = false;
      _hfNothingHeard = false;
    });
    if (on && _listening) {
      await _speech?.cancel();
      _holding = false;
      _tapMode = false;
      if (mounted) setState(() => _listening = false);
    }
    await ref.read(handsFreeProvider.notifier).set(on);
    if (on && mounted) await _hfListen();
  }

  /// Tells a recognizer that can take them the talk's practice words, so
  /// rare ones ("saline") are heard (owner, 2026-10-24).
  void _giveHints(SpeechInput speech) {
    if (speech is SpeechHints) {
      (speech as SpeechHints).hints = [for (final w in ref.read(talkProvider(widget.collectionId, learnFlow: widget.learnFlow)).words) w.word.word];
    }
  }

  /// Whether the permission dialog was shown on this visit.
  bool _permissionAsked = false;

  /// What the recognizer's init found; a refused permission opens the
  /// dialog with "Move to Settings" once per visit (owner, 2026-10-24).
  void _setAvailability(SpeechAvailability found) {
    setState(() => _availability = found);
    if (found == SpeechAvailability.permissionDenied && !_permissionAsked) {
      _permissionAsked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPermissionDialog();
      });
    }
  }

  Future<void> _showPermissionDialog() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.mic_off_rounded),
        title: const Text('Microphone is off'),
        content: Text(Platform.isIOS
            ? 'To talk, turn on Microphone and Speech Recognition for this app in Settings.'
            : 'To talk, allow the Microphone for this app: Settings → Permissions → Microphone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Move to Settings')),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await openAppSettings();
    if (!mounted) return;
    // Back from Settings, the next mic tap asks the recognizer again.
    setState(() {
      _availability = null;
      _speech = null;
      _permissionAsked = false;
    });
  }

  /// Switches the engine or the recognition mode: listening stops, and the
  /// next listen starts with the new recognizer.
  Future<void> _changeRecognition(Future<void> Function() change) async {
    if (_listening) await _speech?.cancel();
    setState(() {
      _hfStop();
      _hfPaused = true;
      _listening = false;
      _holding = false;
      _tapMode = false;
    });
    await change();
    if (!mounted) return;
    setState(() {
      _speech = null;
      _availability = null;
    });
  }

  /// Opens the word popup on [word], its arrow at [global] (talk-screen-b).
  void _openWord(WordPair word, Rect global) => _openPopup(global, word: word);

  /// Opens the popup on any other word of an AI line: its translation.
  void _openLookup(String word, Rect global) => _openPopup(global, lookup: word);

  void _openPopup(Rect global, {WordPair? word, String? lookup}) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    if (_popup.menuIsShowing) _popup.hideMenu();
    setState(() {
      _popupWord = word;
      _lookupWord = lookup;
      _anchor = box.globalToLocal(global.topLeft) & global.size;
      _anchorGlobal = global;
    });
    // Once the anchor has moved there.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) openDotsMenu(context, _popup, _focus.unfocus);
    });
  }

  /// The Words screen's loaders, read-only: what they bring is shown, never
  /// stored.
  Future<TranslationResult?> _loadTranslations(WordPair word) async {
    try {
      return (await ref.read(googleTranslateServiceProvider).translateWord(word.word.trim(), from: 'en', to: 'uk'))
          .result;
    } catch (_) {
      return null;
    }
  }

  /// [word]'s translation, looked up once per talk.
  Future<TranslationResult?> _lookup(String word) async {
    final key = word.trim().toLowerCase();
    if (_lookups.containsKey(key)) return _lookups[key];
    final result = await _loadTranslations(WordPair(word: word, translation: ''));
    if (result != null) _lookups[key] = result;
    return result;
  }

  Future<List<String>?> _loadSenses(WordPair word) async {
    final result = await ref.read(dictionaryServiceProvider).define(word.word.trim());
    return switch (result.kind) {
      DefinitionKind.senses => result.senses,
      DefinitionKind.notFound => const [],
      DefinitionKind.unavailable => null,
    };
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(leaveText),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = talkProvider(widget.collectionId, learnFlow: widget.learnFlow);
    ref.listen(provider, (prev, next) {
      if (next.messages.length != prev?.messages.length || next.status != prev?.status) _scrollToEnd();
      if (next.quizzes != prev?.quizzes) {
        _scrollToEnd();
        // A spoken quiz step, or back to a speaking turn, listens at once.
        final step = next.spokenQuizItem;
        final stepChanged = step != null && (prev?.spokenQuizItem == null || !identical(prev!.spokenQuizItem, step));
        final backToTalk = prev?.openQuiz != null && next.openQuiz == null && _autoListen(next);
        if ((stepChanged || backToTalk) && _hf != _HandsFree.speaking && !_listening) {
          setState(() {
            _hfPaused = false;
            _hfNothingHeard = false;
          });
          _hfListen();
        }
      }
      if (next.messages.length > (prev?.messages.length ?? 0)) _customReply = false;
      if (next.messages.length > (prev?.messages.length ?? 0) && next.messages.last.role == TalkRole.ai) {
        _onAiLine(next.messages.last.text);
      }
      if (next.status != TalkStatus.talking && _hf != _HandsFree.idle) setState(_hfStop);
      final draft = next.keepDraft;
      if (draft != null && draft != prev?.keepDraft && !next.keepChoice) _field.text = draft;
      if (draft == null && prev?.keepDraft != null) _field.clear();
      if (widget.learnFlow) {
        // Back to the flow, now at its results (learn-welcome AC-13, AC-15).
        final end = next.status == TalkStatus.over || next.status == TalkStatus.limit;
        if (end && prev?.status != next.status) Navigator.of(context).pop();
      } else if (next.status == TalkStatus.over && prev?.status != TalkStatus.over) {
        openSessionResults(context, widget.collectionId);
      }
    });
    final s = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final decor = AppDecor.of(context);
    final scheme = Theme.of(context).colorScheme;
    final busy = s.status == TalkStatus.starting || s.status == TalkStatus.waiting;
    final inProgress = s.messages.isNotEmpty && s.status != TalkStatus.over;
    final micShown = _availability == null || _availability == SpeechAvailability.ready;
    final speechProblem = _speech is SpeechProblem ? (_speech as SpeechProblem).problem : null;
    final refusedText = _availability == SpeechAvailability.unavailable
        ? (speechProblem == null ? talkVoiceUnavailableMessage : talkVoiceUnavailableWith(speechProblem))
        : talkVoiceRefusedMessage;
    final voiceRefused =
        _availability == SpeechAvailability.permissionDenied || _availability == SpeechAvailability.unavailable;
    final autoVoice = ref.watch(handsFreeProvider);
    // Mixed missions may read the character aloud, but never start recording automatically.
    final handsFree = s.mixed ? _autoListen(s) : autoVoice;
    final composer = s.openQuiz != null
        ? s.spokenQuizItem != null
        : !s.complete && (!s.mixed || s.interaction == 'speak' || _customReply);
    final pauseSeconds = ref.watch(talkPauseProvider);
    final micOn = _listening || _hf == _HandsFree.listening;
    final String? line;
    if (handsFree) {
      line = switch (_hf) {
        _HandsFree.speaking => talkSpeakingText,
        _HandsFree.listening => talkListeningPauseText(pauseSeconds),
        _HandsFree.idle => voiceRefused
            ? refusedText
            : _hfNothingHeard
                ? talkNothingHeardText
                : micShown && s.status == TalkStatus.talking
                    ? talkHandsFreeHintText(pauseSeconds)
                    : null,
      };
    } else {
      line = _listening || voiceRefused || (micShown && s.status == TalkStatus.talking)
          ? (_listening
              ? (_tapMode ? talkListeningTapText : talkListeningHoldText)
              : voiceRefused
                  ? refusedText
                  : talkMicHintText)
          : null;
    }

    Widget body;
    if (s.status == TalkStatus.limit) {
      body = _Message(
          text: s.errorText ?? talkDayLimitMessage, button: 'Back', onPressed: () => Navigator.of(context).pop());
    } else if (s.status == TalkStatus.starting && s.messages.isEmpty) {
      body = const _Message(text: 'Planning your mission…', busy: true);
    } else if (s.status == TalkStatus.error && s.messages.isEmpty) {
      body = _Message(text: s.errorText ?? talkFailedMessage, button: 'Retry', onPressed: notifier.retry);
    } else {
      final theme = Theme.of(context);
      final words = [for (final w in s.words) w.word];
      final usedRows = {
        for (final w in s.words)
          if (w.used) w.word.rowId
      };
      final micActive = micOn && _availability == SpeechAvailability.ready;
      final mission = s.mission;
      body = Column(
        children: [
          TalkTutorHeader(collectionName: s.name, onEnd: s.messages.isEmpty ? null : notifier.finish),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final maxWidth = box.maxWidth * 0.84;
              return ListView(
                key: talkLogKey,
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                children: [
                  if (mission != null)
                    TalkMissionCard(
                      title: mission.title,
                      role: mission.role,
                      goal: mission.goal,
                      picture: s.picture,
                      pictureLoading: s.pictureLoading,
                    ),
                  for (final (i, m) in s.messages.indexed) ...[
                    i == _spokenIndex
                        ? AnimatedBuilder(
                            animation: Listenable.merge([_karaoke, _loadBar]),
                            builder: (_, __) => _bubble(i, m, maxWidth, words, usedRows,
                                spokenEnd: karaokeSplit(m.text, _karaoke.value),
                                voiceLoading: _voiceLoading,
                                voiceProgress: _loadBar.value),
                          )
                        : _bubble(i, m, maxWidth, words, usedRows),
                    // Under every AI line, to listen to earlier ones again too.
                    if (m.role == TalkRole.ai)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TalkVoiceControls(
                          speaking: _spokenIndex == i,
                          onPlay: _listening ? null : () => _replay(i),
                          onStop: _stopVoice,
                          onReplay: _listening ? null : () => _replay(i),
                        ),
                      ),
                    for (final q in s.quizzes)
                      if (q.at == i + 1)
                        TalkQuizCard(
                          quiz: q.quiz,
                          onPick: notifier.answerQuiz,
                          onMatch: notifier.matchQuiz,
                          onNext: notifier.nextQuiz,
                          onRate: notifier.rateQuiz,
                        ),
                  ],
                  if (s.mixed && s.status == TalkStatus.talking && !s.complete && s.openQuiz == null) ...[
                    if (s.interaction == 'choice') ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('What do you want to do?'),
                      ),
                      for (final choice in s.choices)
                        TalkChoiceButton(
                          choice: choice,
                          words: words,
                          onPressed: _listening ? null : () => _choose(choice),
                        ),
                      if (!_customReply)
                        TextButton(
                          onPressed: () {
                            setState(() => _customReply = true);
                            _hfListen();
                          },
                          child: const Text('Say something else'),
                        ),
                    ],
                    if (s.interaction == 'speak')
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Your turn to speak', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(s.speakingPrompt),
                          const Text('Tap the mic when you are ready, or type your answer.'),
                        ]),
                      ),
                  ],
                  if (s.complete && s.openQuiz == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: FilledButton(onPressed: notifier.end, child: const Text('See results')),
                    ),
                  if (s.status == TalkStatus.waiting) TalkBubble(index: -1, text: '…', mine: false, maxWidth: maxWidth),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _field,
                    builder: (_, v, __) => micOn && v.text.trim().isNotEmpty
                        ? TalkLiveBubble(text: v.text, maxWidth: maxWidth)
                        : const SizedBox.shrink(),
                  ),
                ],
              );
            }),
          ),
          if (s.status == TalkStatus.error)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              child: Row(children: [
                Expanded(
                  child: Text(s.errorText ?? talkFailedMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error)),
                ),
                TextButton(onPressed: notifier.retry, child: const Text('Retry')),
              ]),
            ),
          // The word strip shows on every turn, choices too (owner,
          // 2026-10-24); the mic and the field only when the learner speaks.
          DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
            child: Column(
              children: [
                if (composer && s.hintWord != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Try using: ${s.hintWord}',
                          style:
                              theme.textTheme.bodyMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600)),
                    ),
                  ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    key: talkStripKey,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    children: [
                      for (final w in s.words)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: TalkStripChip(
                            word: w.word.word,
                            used: w.used,
                            target: !w.used && w.word.word == s.target,
                            onTap: (rect) => _openWord(w.word, rect),
                          ),
                        ),
                    ],
                  ),
                ),
                if (composer) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 16, 0),
                    child: Row(children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton(
                            onPressed: s.hintAvailable && s.status == TalkStatus.talking ? notifier.showHint : null,
                            // Narrower padding: the big mic leaves less room beside it.
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.lightbulb_outline, size: 18),
                              SizedBox(width: 6),
                              Flexible(child: Text('Hint', overflow: TextOverflow.fade, softWrap: false)),
                            ]),
                          ),
                        ),
                      ),
                      if (micShown)
                        Semantics(
                          label: 'Tap to talk',
                          button: true,
                          child: Listener(
                            onPointerDown: handsFree || (busy && !_listening) ? null : (_) => _micDown(),
                            onPointerUp: handsFree
                                ? (busy && _hf == _HandsFree.idle ? null : (_) => _hfMicTap())
                                : (_) => _micUp(),
                            onPointerCancel: handsFree ? null : (_) => _micUp(),
                            child: AnimatedBuilder(
                              animation: _ring,
                              builder: (_, child) => TalkRing(
                                progress: _hf == _HandsFree.listening ? _ring.value : 0,
                                active: micActive,
                                child: child!,
                              ),
                              child: TalkMicCircle(on: micOn, busy: busy),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _field,
                            builder: (_, v, __) => TalkWave(active: micActive, seed: micActive ? v.text.length : 0),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  if (line != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                      child: AnimatedBuilder(
                        animation: _ring,
                        builder: (_, __) {
                          final left = (1 - _ring.value) * pauseSeconds;
                          final sending =
                              _hf == _HandsFree.listening && _ring.isAnimating && _ring.value * pauseSeconds >= 1;
                          return Text(
                            sending ? talkSendingInText(left.ceil()) : line!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(color: decor.muted, fontWeight: FontWeight.w600),
                          );
                        },
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 4, 8),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _field,
                          focusNode: _focus,
                          enabled: !busy,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(hintText: 'Type a reply…', isDense: true),
                        ),
                      ),
                      IconButton(tooltip: 'Send', icon: const Icon(Icons.send), onPressed: busy ? null : _send),
                    ]),
                  ),
                ] else
                  const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      );
    }

    final word = _popupWord;
    return PopScope(
      canPop: !inProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_popup.menuIsShowing) {
          _popup.hideMenu();
          return;
        }
        _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Talk with AI'),
          actions: [
            IconButton(
              tooltip: s.mixed
                  ? (autoVoice ? 'Read replies aloud: on' : 'Read replies aloud: off')
                  : (handsFree ? talkHandsFreeOnTip : talkHandsFreeOffTip),
              icon: Icon(autoVoice ? Icons.headset_mic : Icons.headset_off),
              onPressed: _toggleHandsFree,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text('${s.repliesCount} / ${s.replyLimit ?? (s.mixed ? 9 : maxReplies)}')),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            key: _stackKey,
            children: [
              Positioned.fill(child: body),
              // How speech is recognised, at the right edge below the tutor header.
              if (s.messages.isNotEmpty)
                Positioned(
                  top: 64,
                  right: 0,
                  child: TalkRecognitionTab(
                    engine: ref.watch(speechEngineProvider),
                    onDevice: ref.watch(speechOnDeviceProvider),
                    onEngine: (e) => _changeRecognition(() => ref.read(speechEngineProvider.notifier).set(e)),
                    onOnDevice: (v) => _changeRecognition(() => ref.read(speechOnDeviceProvider.notifier).set(v)),
                  ),
                ),
              // The popup's anchor, moved onto the tapped word.
              Positioned.fromRect(
                rect: _anchor,
                child: IgnorePointer(
                  child: CustomPopupMenu(
                    controller: _popup,
                    pressType: PressType.singleClick,
                    showArrow: true,
                    arrowColor: decor.popup,
                    arrowSize: 10,
                    barrierColor: Colors.transparent,
                    verticalMargin: 6,
                    menuBuilder: () => _lookupWord != null
                        ? _fitPopup(
                            context,
                            dotsMenuPanel(
                              context,
                              TalkLookupPopup(
                                word: _lookupWord!,
                                onLoad: () => _lookup(_lookupWord!),
                                onClose: _popup.hideMenu,
                              ),
                            ),
                          )
                        : word == null
                            ? const SizedBox.shrink()
                            : _fitPopup(
                                context,
                                dotsMenuPanel(
                                  context,
                                  TalkWordPopup(
                                    word: _popupWord ?? word,
                                    mode: ref.read(wordDetailModeProvider),
                                    onLoadTranslations: () => _loadTranslations(_popupWord ?? word),
                                    onLoadSenses: () => _loadSenses(_popupWord ?? word),
                                    onClose: _popup.hideMenu,
                                  ),
                                ),
                              ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The word popup kept on screen (talk-mission, owner 2026-10-24): a
  /// margin from the screen's sides, and no taller than the room on the side
  /// it opens to — above the word in the lower half, below it in the upper
  /// half, as `popup_menu_2` places it — so it never runs under the bars or
  /// off the screen.
  Widget _fitPopup(BuildContext context, Widget panel) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    const gap = 6 + 10 + 8; // verticalMargin + arrow + breathing room
    final above = _anchorGlobal.bottom > screen.height / 2;
    final room = above
        ? _anchorGlobal.top - media.padding.top - gap
        : screen.height - _anchorGlobal.bottom - media.padding.bottom - gap;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: room.clamp(120, 420)),
        child: panel,
      ),
    );
  }

  Widget _bubble(int i, TalkMessage m, double maxWidth, List<WordPair> words, Set<String> usedRows,
          {int? spokenEnd, bool voiceLoading = false, double voiceProgress = 0}) =>
      TalkBubble(
        index: i,
        text: m.text,
        mine: m.role == TalkRole.learner,
        maxWidth: maxWidth,
        words: words,
        usedRows: usedRows,
        spokenEnd: spokenEnd,
        voiceLoading: voiceLoading,
        voiceProgress: voiceProgress,
        onWord: _openWord,
        onOtherWord: _openLookup,
        onPhrase: _openLookup,
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.busy = false, this.button, this.onPressed});

  final String text;
  final bool busy;
  final String? button;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[const CircularProgressIndicator(), const SizedBox(height: 16)],
              Text(text, textAlign: TextAlign.center),
              if (button != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: onPressed, child: Text(button!)),
              ],
            ],
          ),
        ),
      );
}
