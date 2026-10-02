import 'package:flutter/material.dart';
import 'app_theme.dart';

/// ชื่อ route ของแดชบอร์ด (ตั้งตอนล็อกอิน) ใช้เป็นจุดอ้างอิงของการนำทางระหว่างแท็บ
const String kDashboardRoute = 'dashboard';

/// ให้แดชบอร์ดรู้ว่า "กลับมาถึงหน้าตัวเองแล้วจริง ๆ" (ผ่าน RouteAware.didPopNext)
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

bool _isDashboardRoute(Route<dynamic> r) =>
    r.settings.name == kDashboardRoute || r.isFirst;

/// แท็บ "โปรไฟล์": ถอยทุกหน้าที่ซ้อนอยู่จนถึงแดชบอร์ด
void goToDashboard(BuildContext context) =>
    Navigator.popUntil(context, _isDashboardRoute);

/// สลับไปหน้าแท็บอื่น: แทนที่ทุกหน้าที่อยู่เหนือแดชบอร์ด ทำให้สแตกเป็น
/// แดชบอร์ด → หน้าแท็บนี้ เสมอ (back จากหน้าแท็บจึงกลับแดชบอร์ด)
void goToTab(BuildContext context, Widget page) => Navigator.pushAndRemoveUntil(
  context,
  MaterialPageRoute(builder: (_) => page),
  _isDashboardRoute,
);

/// currentIndex: 0=โปรไฟล์, 1=เพิ่มความต้องการ, 2=จับคู่, 3=แชท, 4=แก้ไขข้อมูล
/// onTap: callback เมื่อกดปุ่ม
class AppNavBar extends StatelessWidget {
  final String role;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppNavBar({
    super.key,
    required this.role,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = AppColors.forRole(role);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.dark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.dark,
          selectedItemColor: accent,
          unselectedItemColor: Colors.grey[400],
          selectedFontSize: AppText.caption,
          unselectedFontSize: AppText.caption,
          iconSize: 26,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: AppText.caption,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: AppText.caption),
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'โปรไฟล์',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.add_circle_outline),
              activeIcon: const Icon(Icons.add_circle_rounded),
              label: role == 'student' ? 'เพิ่มการเรียน' : 'เพิ่มการสอน',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.manage_search_outlined),
              activeIcon: Icon(Icons.manage_search_rounded),
              label: 'จับคู่',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble_rounded),
              label: 'แชท',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person_rounded),
              label: 'แก้ไขข้อมูล',
            ),
          ],
        ),
      ),
    );
  }
}
