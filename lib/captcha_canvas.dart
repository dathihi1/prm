import 'dart:math';

import 'package:flutter/material.dart';

class CaptchaCanvas extends StatelessWidget {
  const CaptchaCanvas({super.key, required this.text, this.height = 48});

  final String text;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(painter: CaptchaPainter(text)),
    );
  }
}

class CaptchaPainter extends CustomPainter {
  CaptchaPainter(this.text);

  final String text;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(text.hashCode);
    final backgroundPaint = Paint()..color = const Color(0xFFF4F6FA);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4)),
      backgroundPaint,
    );

    final noisePaint = Paint()
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (var index = 0; index < 7; index++) {
      noisePaint.color = _noiseColors[random.nextInt(_noiseColors.length)]
          .withValues(alpha: 0.55);
      final start = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final control = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final end = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
      canvas.drawPath(path, noisePaint);
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (var index = 0; index < 30; index++) {
      dotPaint.color = _noiseColors[random.nextInt(_noiseColors.length)]
          .withValues(alpha: 0.45);
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.8 + random.nextDouble() * 1.2,
        dotPaint,
      );
    }

    if (text.isEmpty) return;
    final cellWidth = size.width / text.length;
    for (var index = 0; index < text.length; index++) {
      final characterPainter = TextPainter(
        text: TextSpan(
          text: text[index],
          style: TextStyle(
            color: _textColors[random.nextInt(_textColors.length)],
            fontSize: min(27.0, size.height * 0.58),
            fontWeight: FontWeight.w800,
            fontStyle: index.isEven ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final center = Offset(
        cellWidth * (index + 0.5),
        size.height / 2 + (random.nextDouble() * 6 - 3),
      );
      final angle = random.nextDouble() * 0.34 - 0.17;

      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(angle);
      characterPainter.paint(
        canvas,
        Offset(-characterPainter.width / 2, -characterPainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CaptchaPainter oldDelegate) {
    return oldDelegate.text != text;
  }

  static const _textColors = <Color>[
    Color(0xFF183B73),
    Color(0xFF6A1B4D),
    Color(0xFF1B5E4B),
    Color(0xFF7A3D00),
  ];

  static const _noiseColors = <Color>[
    Color(0xFF2B4E8C),
    Color(0xFF9C4B79),
    Color(0xFF40826D),
    Color(0xFFB7791F),
  ];
}
