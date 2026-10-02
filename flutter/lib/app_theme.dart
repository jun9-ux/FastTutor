import 'package:flutter/material.dart';
import 'photo_helper.dart';

/// ชุดสีกลางของแอป (โทนส้ม-ดำ) ใช้แทนค่าสีที่เคยกระจัดกระจายอยู่ทุกไฟล์
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFFF7A50);
  static const Color primaryDark = Color(0xFFE85F36);
  static const Color studentAccent = Color(0xFFAE917C);
  static const Color tutorAccent = Color(0xFF607D8B);

  /// สี accent ตามบทบาทผู้ใช้ ('student' หรือ 'tutor') ใช้แยกโทนสีของสองบทบาทให้ต่างกันชัดเจน
  static Color forRole(String role) =>
      role == 'student' ? studentAccent : tutorAccent;
  static const Color dark = Color(0xFF1C1C1E);
  static const Color scaffoldBg = Color(0xFFF7F7F8);
  static const Color cardWhite = Colors.white;
  static const Color online = Color(0xFF4CAF50);
  static const Color bubbleReceived = Color(0xFFF0F0F0);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color textGray = Color(0xFF8A8A8E);
}

/// ขนาดตัวหนังสือมาตรฐานทั้งแอป (เพื่อการเข้าถึงง่าย อ่านง่ายสำหรับผู้ใช้ทุกวัย)
class AppText {
  AppText._();

  static const double caption = 13; // ป้าย/คำอธิบายย่อย
  static const double body = 15; // เนื้อหาทั่วไป
  static const double bodyLg =
      16; // ข้อความสำคัญ เช่น bubble แชท, ค่าข้อมูลโปรไฟล์
  static const double heading = 18; // หัวข้อ section
  static const double title = 22; // ชื่อหน้า/ชื่อผู้ใช้
}

/// ขนาดพื้นที่กดมาตรฐานทั้งแอป
class AppSizes {
  AppSizes._();

  static const double minTouchTarget = 48; // ปุ่มไอคอนขั้นต่ำ
  static const double buttonHeight = 56; // ปุ่มหลัก
}

class AppTheme {
  AppTheme._();

  static ThemeData get themeData => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    scaffoldBackgroundColor: AppColors.scaffoldBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textDark,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: AppColors.textDark),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    ),
  );
}

/// Avatar วงกลม พร้อมจุดสถานะออนไลน์สีเขียวมุมขวาล่าง (แสดงเมื่อ isOnline = true)
/// ใช้ [buildPhotoUrl] จาก photo_helper.dart เพื่อโหลดรูปโปรไฟล์ที่อัปโหลดไว้ ถ้าไม่มีจะแสดง fallback แทน
class AvatarWithStatus extends StatelessWidget {
  final String apiBase;
  final dynamic photoPath;
  final double radius;
  final bool isOnline;
  final Widget fallback;
  final Color backgroundColor;

  const AvatarWithStatus({
    super.key,
    required this.apiBase,
    required this.photoPath,
    required this.fallback,
    this.radius = 24,
    this.isOnline = false,
    this.backgroundColor = const Color(0xFFFFE8DD),
  });

  @override
  Widget build(BuildContext context) {
    final url = buildPhotoUrl(apiBase, photoPath);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor,
          backgroundImage: url != null ? NetworkImage(url) : null,
          child: url == null ? fallback : null,
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.36,
              height: radius * 0.36,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// เปิด dialog ยืนยันก่อนทำสิ่งสำคัญ (ออกจากระบบ, ปฏิเสธคำขอ ฯลฯ)
/// คืนค่า true ถ้าผู้ใช้กดยืนยัน, false ถ้ากดยกเลิกหรือปิด dialog
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'ยืนยัน',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message, style: const TextStyle(fontSize: AppText.body)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: danger ? Colors.red : AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Badge วงกลมสีส้มแสดงจำนวนที่ยังไม่อ่าน ไม่แสดงอะไรเลยถ้า count เป็น 0
class UnreadBadge extends StatelessWidget {
  final int count;
  const UnreadBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return CircleAvatar(
      radius: 13,
      backgroundColor: AppColors.primary,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(color: Colors.white, fontSize: AppText.caption),
      ),
    );
  }
}
