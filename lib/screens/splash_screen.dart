import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The first Flutter frame, visible while the account is being restored.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isCompleted && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF5B6CFF),
        body: DecoratedBox(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4758E8), Color(0xFF7564E8), Color(0xFF9B78E9)],
          )),
          child: SizedBox.expand(
              child: SafeArea(
            child: Center(
                child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final entrance =
                        Curves.easeOutCubic.transform(_controller.value);
                    final text = Curves.easeOut.transform(
                        ((_controller.value - 0.25) / 0.75).clamp(0.0, 1.0));
                    return Column(mainAxisSize: MainAxisSize.min, children: [
                      Semantics(
                        label: 'BM Habits logo',
                        image: true,
                        child: Transform.scale(
                            scale: 0.8 + entrance * 0.2,
                            child: SizedBox(
                                width: 168,
                                height: 168,
                                child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CustomPaint(
                                          size: const Size(168, 168),
                                          painter: _ProgressRing(entrance)),
                                      Container(
                                          width: 126,
                                          height: 126,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withAlpha(28),
                                            borderRadius:
                                                BorderRadius.circular(38),
                                            border: Border.all(
                                                color:
                                                    Colors.white.withAlpha(70)),
                                          ),
                                          child: const Icon(Icons.eco_rounded,
                                              color: Colors.white, size: 70)),
                                      Positioned(
                                          right: 12,
                                          bottom: 12,
                                          child: Transform.scale(
                                              scale: entrance,
                                              child: const CircleAvatar(
                                                  radius: 18,
                                                  backgroundColor:
                                                      Color(0xFFBFF4DE),
                                                  child: Icon(
                                                      Icons.check_rounded,
                                                      color: Color(0xFF287662),
                                                      size: 24)))),
                                    ]))),
                      ),
                      const SizedBox(height: 30),
                      Opacity(
                          opacity: text,
                          child: Transform.translate(
                              offset: Offset(0, 12 * (1 - text)),
                              child: const Column(children: [
                                Text('BM Habits',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 38,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -1)),
                                SizedBox(height: 10),
                                Text('Small steps. Every day.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 16)),
                              ]))),
                    ]);
                  }),
            )),
          )),
        ),
      );
}

class _ProgressRing extends CustomPainter {
  const _ProgressRing(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(rect, paint..color = Colors.white.withAlpha(30));
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false,
        paint..color = Colors.white.withAlpha(180));
  }

  @override
  bool shouldRepaint(_ProgressRing oldDelegate) =>
      oldDelegate.progress != progress;
}
