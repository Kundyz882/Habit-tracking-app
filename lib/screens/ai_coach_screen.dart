import 'package:flutter/material.dart';
import 'dart:async';

import '../services/ai_service.dart';
import '../services/habit_store.dart';
import '../theme.dart';

class _Msg {
  const _Msg(this.role, this.text, {this.isError = false});
  final String role; // 'user' or 'assistant'
  final String text;
  final bool isError;
}

/// Conversations are kept in memory while the app is open, per user.
final Map<String, List<_Msg>> _sessions = {};
DateTime? _sharedQuotaUntil;

const String _greeting =
    "Hi! I'm your habit coach. Tell me what is going well or what feels hard, "
    'and I will suggest small steps based on your check-ins.';

const List<String> _suggestions = [
  'Why is it hard for me to stay consistent?',
  'Give me one small step for today',
  'I missed a day. What now?',
];

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key, required this.store, this.initialMessage});

  final HabitStore store;
  final String? initialMessage;

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final AiService _service = AiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;
  bool _initialMessageSent = false;
  Timer? _quotaTicker;

  List<_Msg> get _messages =>
      _sessions.putIfAbsent(widget.store.userId, () => []);

  bool get _quotaBlocked =>
      _sharedQuotaUntil != null && _sharedQuotaUntil!.isAfter(DateTime.now());

  String? get _lastUserText {
    for (final message in _messages.reversed) {
      if (message.role == 'user') return message.text;
    }
    return null;
  }

  bool get _isRussian => RegExp('[А-Яа-яЁё]').hasMatch(_lastUserText ?? '');

  @override
  void initState() {
    super.initState();
    if (_quotaBlocked) _startQuotaTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sendInitialMessage();
  }

  void _sendInitialMessage() {
    final message = widget.initialMessage;
    if (_initialMessageSent || message == null || message.trim().isEmpty) {
      return;
    }
    _initialMessageSent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _send(message);
      }
    });
  }

  @override
  void dispose() {
    _quotaTicker?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _startQuotaTicker() {
    _quotaTicker?.cancel();
    _quotaTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!_quotaBlocked) {
        _quotaTicker?.cancel();
        _sharedQuotaUntil = null;
      }
      setState(() {});
    });
  }

  String _remainingLabel() {
    final remaining = _sharedQuotaUntil?.difference(DateTime.now());
    final totalMinutes = ((remaining?.inSeconds ?? 0) + 59) ~/ 60;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final russian = _isRussian;
    if (russian) {
      if (hours > 0) return '$hours ч $minutes мин';
      return '$minutes мин';
    }
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending || _quotaBlocked) return;
    final messages = _messages;
    setState(() {
      messages.add(_Msg('user', text));
      _sending = true;
    });
    _controller.clear();
    _scrollDown();

    final turns = [
      for (final m in messages)
        if (!m.isError) ChatTurn(m.role, m.text)
    ];
    String? reply;
    Duration? quotaWait;
    try {
      reply = await _service.chat(turns, widget.store.habits.toList());
    } on AiQuotaException catch (e) {
      quotaWait = e.retryAfter;
      _sharedQuotaUntil = DateTime.now().add(e.retryAfter);
    }

    final russian = RegExp('[А-Яа-яЁё]').hasMatch(text);
    messages.add(quotaWait != null
        ? _Msg(
            'assistant',
            russian
                ? 'Лимит AI-коуча временно исчерпан. Отправка сообщений приостановлена.'
                : 'The AI coach quota is temporarily exhausted. Sending is paused.',
            isError: true)
        : reply == null
            ? const _Msg(
                'assistant',
                'Sorry, I could not reach the coach right now. '
                    'Please try again in a moment.',
                isError: true)
            : _Msg('assistant', reply));
    if (!mounted) return;
    setState(() => _sending = false);
    if (quotaWait != null) _startQuotaTicker();
    _scrollDown();
  }

  @override
  Widget build(BuildContext context) {
    final all = [const _Msg('assistant', _greeting), ..._messages];
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary, const Color(0xFF8E6CEF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 21),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI coach', style: TextStyle(fontSize: 17)),
              Text('Your habit companion',
                  style: TextStyle(fontSize: 12, color: Color(0xFF7C839D))),
            ],
          ),
        ]),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: tint(primary, 0.07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border_rounded,
                        size: 15, color: primary),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'Support for habits, not medical advice',
                        style: TextStyle(
                            fontSize: 12,
                            color: tint(const Color(0xFF1B2559), 0.7)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_quotaBlocked)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _isRussian
                        ? 'Лимит AI-коуча исчерпан. Можно писать через ${_remainingLabel()}.'
                        : 'AI coach limit reached. You can send messages again in ${_remainingLabel()}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF8A4B20)),
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                itemCount: all.length + (_sending ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == all.length) {
                    return const _Bubble(
                        msg: _Msg('assistant', 'Coach is thinking…'));
                  }
                  return _Bubble(msg: all[i]);
                },
              ),
            ),
            if (_messages.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 2, bottom: 8),
                      child: Text('Try asking',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tint(const Color(0xFF1B2559), 0.55))),
                    ),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final s in _suggestions)
                        ActionChip(
                          label: Text(s),
                          onPressed: () => _send(s),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: tint(primary, 0.14)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          labelStyle: TextStyle(
                              color: tint(const Color(0xFF1B2559), 0.82)),
                        ),
                    ]),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child:
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_quotaBlocked,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: InputDecoration(
                        hintText: _quotaBlocked
                            ? 'Coach available in ${_remainingLabel()}'
                            : 'Write to your coach…',
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: tint(primary, 0.10)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: primary, width: 1.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17)),
                      ),
                      onPressed: _sending || _quotaBlocked
                          ? null
                          : () => _send(_controller.text),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});

  final _Msg msg;

  @override
  Widget build(BuildContext context) {
    final mine = msg.role == 'user';
    final width = MediaQuery.sizeOf(context).width * 0.8;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: width > 520 ? 520 : width),
        decoration: BoxDecoration(
          color: mine ? Theme.of(context).colorScheme.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(mine ? 20 : 6),
            bottomRight: Radius.circular(mine ? 6 : 20),
          ),
          border: !mine
              ? Border.all(color: tint(const Color(0xFF5B6CFF), 0.07))
              : null,
          boxShadow: [
            BoxShadow(
              color: tint(const Color(0xFF1B2559), 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            height: 1.35,
            color: mine
                ? Colors.white
                : (msg.isError ? lapseColor : const Color(0xFF1B2559)),
          ),
        ),
      ),
    );
  }
}
