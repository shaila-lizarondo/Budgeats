import 'package:flutter/material.dart';

/// A compact, scalable wallet mark for Budgeats.
class BudgeatsLogo extends StatelessWidget {
  final double size;

  const BudgeatsLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Budgeats wallet logo',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _BudgeatsLogoPainter()),
      ),
    );
  }
}

class _BudgeatsLogoPainter extends CustomPainter {
  static const _outline = Color(0xFF59422F);
  static const _gold = Color(0xFFFFC940);
  static const _goldLight = Color(0xFFFFE27A);
  static const _wallet = Color(0xFFC99B79);
  static const _walletLight = Color(0xFFD9AF8D);
  static const _green = Color(0xFF77B95B);
  static const _greenLight = Color(0xFF9BCB70);
  static const _blush = Color(0xFFE99A9C);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final outline = Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    _drawSparkle(canvas, const Offset(33, 19), 5.4, outline);
    _drawSparkle(canvas, const Offset(89, 32), 4.4, outline);
    _drawSparkle(canvas, const Offset(11, 59), 4.3, outline);

    _drawCoin(canvas, const Offset(13, 39), 8.4, outline);
    _drawCoin(canvas, const Offset(53, 15), 8.0, outline);
    _drawCoin(canvas, const Offset(88, 45), 8.2, outline);

    final leftNote = Path()
      ..moveTo(25, 53)
      ..lineTo(27, 39)
      ..lineTo(51, 27)
      ..lineTo(65, 42)
      ..lineTo(62, 54)
      ..close();
    canvas.drawPath(leftNote, Paint()..color = _greenLight);
    canvas.drawPath(leftNote, outline);

    final rightNote = Path()
      ..moveTo(38, 53)
      ..lineTo(57, 31)
      ..lineTo(76, 39)
      ..lineTo(79, 54)
      ..close();
    canvas.drawPath(rightNote, Paint()..color = _green);
    canvas.drawPath(rightNote, outline);

    final billFold = Path()
      ..moveTo(31, 48)
      ..lineTo(53, 37)
      ..lineTo(66, 43);
    canvas.drawPath(billFold, outline);
    final billFold2 = Path()
      ..moveTo(47, 49)
      ..lineTo(63, 39)
      ..lineTo(75, 46);
    canvas.drawPath(billFold2, outline);

    final walletRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(15, 45, 69, 42),
      const Radius.circular(11),
    );
    final walletPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_walletLight, _wallet],
      ).createShader(const Rect.fromLTWH(15, 45, 69, 42));
    canvas.drawRRect(walletRect, walletPaint);
    canvas.drawRRect(walletRect, outline);

    final topSeam = Path()
      ..moveTo(17, 54)
      ..cubicTo(31, 58, 57, 57, 82, 53);
    canvas.drawPath(topSeam, outline);

    final pocketSeam = Path()
      ..moveTo(23, 77)
      ..lineTo(64, 77);
    canvas.drawPath(
      pocketSeam,
      Paint()
        ..color = _walletLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    for (var x = 25.0; x <= 59; x += 5) {
      canvas.drawCircle(
        Offset(x, 77),
        0.65,
        Paint()..color = const Color(0xFFF3D5B9),
      );
    }

    final clasp = RRect.fromRectAndRadius(
      const Rect.fromLTWH(74, 62, 16, 15),
      const Radius.circular(5),
    );
    canvas.drawRRect(clasp, Paint()..color = _walletLight);
    canvas.drawRRect(clasp, outline);
    canvas.drawCircle(const Offset(82, 69.5), 3.4, Paint()..color = _gold);
    canvas.drawCircle(
      const Offset(82, 69.5),
      3.4,
      Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7,
    );

    canvas.drawCircle(const Offset(41, 64), 1.5, Paint()..color = _outline);
    canvas.drawCircle(const Offset(57, 64), 1.5, Paint()..color = _outline);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(49, 70), width: 6, height: 4.2),
      Paint()..color = _outline,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(34, 70), width: 5, height: 2.2),
      Paint()..color = _blush.withValues(alpha: 0.85),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(64, 70), width: 5, height: 2.2),
      Paint()..color = _blush.withValues(alpha: 0.85),
    );

    canvas.restore();
  }

  void _drawCoin(Canvas canvas, Offset center, double radius, Paint outline) {
    canvas.drawCircle(center, radius, Paint()..color = _gold);
    canvas.drawCircle(center, radius, outline);
    canvas.drawCircle(
      center,
      radius - 2.3,
      Paint()
        ..color = _goldLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawSparkle(
      Canvas canvas, Offset center, double radius, Paint outline) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
          center.dx + 1, center.dy - 1, center.dx + radius, center.dy)
      ..quadraticBezierTo(
          center.dx + 1, center.dy + 1, center.dx, center.dy + radius)
      ..quadraticBezierTo(
          center.dx - 1, center.dy + 1, center.dx - radius, center.dy)
      ..quadraticBezierTo(
          center.dx - 1, center.dy - 1, center.dx, center.dy - radius)
      ..close();
    canvas.drawPath(path, Paint()..color = _gold);
    canvas.drawPath(path, outline);
  }

  @override
  bool shouldRepaint(covariant _BudgeatsLogoPainter oldDelegate) => false;
}
