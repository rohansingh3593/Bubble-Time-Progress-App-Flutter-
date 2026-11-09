import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A scrolling, heartbeat-style trace driven by actual microphone loudness.
/// Mounted only while recording; no audio is retained by this widget.
class VoiceListeningIndicator extends StatefulWidget {
  final ValueListenable<double> level;
  final int maxSeconds;

  const VoiceListeningIndicator({
    super.key,
    required this.level,
    required this.maxSeconds,
  });

  @override
  State<VoiceListeningIndicator> createState() =>
      _VoiceListeningIndicatorState();
}

class _VoiceListeningIndicatorState extends State<VoiceListeningIndicator> {
  static const _interval = Duration(milliseconds: 80);
  final _history = List<double>.filled(48, 0, growable: true);
  late final Timer _timer;
  double _level = 0;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_interval, (timer) {
      setState(() {
        _level = widget.level.value.clamp(0.0, 1.0);
        _history.removeAt(0);
        _history.add(_level);
        _seconds = (timer.tick * _interval.inMilliseconds ~/ 1000)
            .clamp(0, widget.maxSeconds);
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.mic, color: colors.onPrimaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Listening...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.onPrimaryContainer,
                      )),
            ),
            Text(
                '0:${_seconds.toString().padLeft(2, '0')} / 0:${widget.maxSeconds}',
                style: TextStyle(color: colors.onPrimaryContainer)),
          ]),
          Semantics(
            label: 'Microphone sound level',
            value: '${(_level * 100).round()} percent',
            child: SizedBox(
              height: 80,
              width: double.infinity,
              child: CustomPaint(
                painter: _VoiceWaveformPainter(
                    List<double>.of(_history), colors.onPrimaryContainer),
              ),
            ),
          ),
          Text(_level > 0.1 ? 'Sound detected' : 'Speak now...',
              style: TextStyle(color: colors.onPrimaryContainer)),
          const SizedBox(height: 4),
          Text('Your words will appear after you tap Stop.',
              style: TextStyle(color: colors.onPrimaryContainer)),
        ],
      ),
    );
  }
}

class _VoiceWaveformPainter extends CustomPainter {
  final List<double> levels;
  final Color color;

  _VoiceWaveformPainter(this.levels, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final middle = size.height / 2;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, middle), Offset(size.width, middle), paint);
    final path = Path()..moveTo(0, middle);
    final width = size.width / levels.length;
    for (var i = 0; i < levels.length; i++) {
      final x = i * width;
      final height = levels[i] * (middle - 6);
      path
        ..lineTo(x + width * 0.25, middle - height)
        ..lineTo(x + width * 0.65, middle + height * 0.7)
        ..lineTo(x + width, middle);
    }
    paint
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..color = color;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _VoiceWaveformPainter oldDelegate) =>
      color != oldDelegate.color || !listEquals(levels, oldDelegate.levels);
}
