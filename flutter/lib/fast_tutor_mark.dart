import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ไอคอนแบรนด์ FastTutor — สายฟ้าเลเยอร์ (navy/blue/gold) พร้อม speed-line
/// สวมหมวกครุย ใช้เฉพาะที่โลโก้เท่านั้น ไม่ใช้สีชุดนี้ที่อื่นในแอป (แอปยังคงใช้
/// AppColors.primary สีส้มเป็นสีหลักของ UI ทั้งหมดตามเดิม)
class _LogoColors {
  _LogoColors._();
  static const navy = Color(0xFF1B3A5C);
  static const blue = Color(0xFF2E86C1);
  static const gold = Color(0xFFD9A441);
  static const lightBlue = Color(0xFF4FA8E0);
}

class FastTutorMark extends StatelessWidget {
  final double size;
  const FastTutorMark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FastTutorPainter()),
    );
  }
}

class _FastTutorPainter extends CustomPainter {
  Offset _pt(Size size, double x, double y) =>
      Offset(size.width * x / 100, size.height * y / 100);

  Path _boltPath(Size size, List<List<double>> pts) {
    final path = Path()
      ..moveTo(
        _pt(size, pts[0][0], pts[0][1]).dx,
        _pt(size, pts[0][0], pts[0][1]).dy,
      );
    for (final p in pts.skip(1)) {
      path.lineTo(_pt(size, p[0], p[1]).dx, _pt(size, p[0], p[1]).dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // ---- ขยาย+จัดกึ่งกลางสายฟ้า+หมวกครุยให้เต็มพื้นที่ ไม่มีกรอบ/วงแหวนล้อม ----
    canvas.save();
    final centroid = _pt(size, 53.5, 52.5);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(0.98);
    canvas.translate(-centroid.dx, -centroid.dy);

    // ---- สายฟ้า: ชั้นหลัง (navy, เยื้อง) ----
    canvas.drawPath(
      _boltPath(size, [
        [67, 7],
        [29, 57],
        [49, 57],
        [37, 101],
        [81, 43],
        [57, 43],
      ]),
      Paint()..color = _LogoColors.navy,
    );

    // ---- สายฟ้า: ชั้นหลัก (blue) ----
    canvas.drawPath(
      _boltPath(size, [
        [63, 4],
        [25, 54],
        [45, 54],
        [33, 98],
        [77, 40],
        [53, 40],
      ]),
      Paint()..color = _LogoColors.blue,
    );

    // ---- สายฟ้า: ริ้วไฮไลต์ (gold) ----
    canvas.drawPath(
      _boltPath(size, [
        [60, 14],
        [36, 50],
        [48, 50],
        [40, 82],
        [66, 46],
        [52, 46],
      ]),
      Paint()..color = _LogoColors.gold,
    );

    // ---- หมวกครุย ----
    canvas.save();
    final capCenter = _pt(size, 56, 15);
    canvas.translate(capCenter.dx, capCenter.dy);
    canvas.rotate(-0.18);
    final s = size.width / 100;

    // โดมหมวก (ฟ้า มน) — ส่วนหัวหมวกที่โผล่ใต้แผ่น
    final domeRect = Rect.fromCenter(
      center: Offset(0, 8 * s),
      width: 22 * s,
      height: 18 * s,
    );
    canvas.drawArc(
      domeRect,
      math.pi,
      math.pi,
      true,
      Paint()..color = _LogoColors.lightBlue,
    );

    // แผ่นหมวก
    final board = Path()
      ..moveTo(-26 * s, 0)
      ..lineTo(0, -9 * s)
      ..lineTo(26 * s, 0)
      ..lineTo(0, 9 * s)
      ..close();
    canvas.drawPath(board, Paint()..color = _LogoColors.navy);

    // เส้นไฮไลต์ขอบบน-ซ้ายของแผ่นหมวก ให้ดูมีมิติ
    final highlight = Path()
      ..moveTo(-24 * s, -0.8 * s)
      ..lineTo(0, -8.6 * s)
      ..lineTo(1.6 * s, -7.8 * s)
      ..lineTo(-22.4 * s, 0)
      ..close();
    canvas.drawPath(
      highlight,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );

    // ปุ่มกลางแผ่นหมวก (จุดยึดพู่ห้อย)
    final buttonCenter = Offset(0, -9 * s);
    canvas.drawCircle(buttonCenter, 2.2 * s, Paint()..color = _LogoColors.gold);

    // พู่ห้อย
    final tasselPaint = Paint()
      ..color = _LogoColors.navy
      ..strokeWidth = 2.6 * s
      ..strokeCap = StrokeCap.round;
    final tasselEnd = Offset(5 * s, 28 * s);
    canvas.drawLine(buttonCenter, tasselEnd, tasselPaint);
    canvas.drawCircle(tasselEnd, 3.4 * s, Paint()..color = _LogoColors.gold);

    canvas.restore(); // ปิด rotate ของหมวกครุย
    canvas.restore(); // ปิด scale+translate จัดกึ่งกลาง
  }

  @override
  bool shouldRepaint(covariant _FastTutorPainter oldDelegate) => false;
}
