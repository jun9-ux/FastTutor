import 'app_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'StudentDashboard.dart';
import 'TutorDashboard.dart';
import 'register.dart';
import 'admin_dashboard_page.dart';
import 'app_session.dart';
import 'app_theme.dart';
import 'api_config.dart';
import 'fast_tutor_mark.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with SingleTickerProviderStateMixin {
  final TextEditingController usernameCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  bool _obscureText = true;
  bool _isLoading = false;

  // 🔹 ไอคอน FastTutor พุ่งเข้ามาจากนอกจอด้วยความเร็วสูงแล้ว spring เข้าที่
  // ก่อนฟอร์ม login จะ cascade เข้ามาทีละส่วน เล่นทุกครั้งที่หน้านี้ถูกสร้างใหม่ (initState)
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );
    final reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (reduceMotion) {
      _intro.value = 1.0;
    } else {
      _intro.forward();
    }
  }

  void _skipIntro() {
    if (_intro.value < 1.0) _intro.value = 1.0;
  }

  /// ความคืบหน้า (0..1) ของ [_intro] ภายในช่วง [start]-[end] ที่กำหนด
  double _p(double start, double end) {
    if (end <= start) return _intro.value >= end ? 1 : 0;
    return ((_intro.value - start) / (end - start)).clamp(0.0, 1.0);
  }

  /// ไอคอนฟรุบขึ้นมาตรงตำแหน่งเดิม (ไม่ลอยมาจากไหน) — สเกล 0 พร้อม fade แล้วเด้งเข้าที่
  double _markScale() {
    final raw = _p(0.0, 0.45);
    if (raw <= 0) return 0.0;
    return Curves.easeOutBack.transform(raw);
  }

  /// ความโปร่งใสของไอคอนตอนฟรุบขึ้นมา (0-35%)
  double _markOpacity() {
    return Curves.easeOut.transform(_p(0.0, 0.35));
  }

  /// วงแหวนกระเพื่อมออกจากจุดศูนย์กลางตอนไอคอน "เบรก" เข้าที่ (50%-65%)
  Widget _ringPulse() {
    final raw = _p(0.50, 0.65);
    if (raw <= 0) return const SizedBox.shrink();
    final eased = Curves.easeOut.transform(raw);
    final size = 30 + 130 * eased;
    return Opacity(
      opacity: ((1 - eased) * 0.55).clamp(0.0, 1.0),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }

  /// ครอบ [child] ด้วย fade + เลื่อนขึ้นเล็กน้อย ตามช่วง [start]-[end] ของ [_intro]
  /// ใช้ cascade เนื้อหาแต่ละส่วนของฟอร์มเข้ามาทีละชิ้นหลังวงโคจรล็อกกันติด
  Widget _reveal(double start, double end, Widget child, {double dy = 14}) {
    final t = Curves.easeOut.transform(_p(start, end));
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, dy * (1 - t)), child: child),
    );
  }

  @override
  void dispose() {
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    _intro.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final headers = {
        'Content-Type': 'application/json; charset=UTF-8',
        "Accept": "application/json",
      };

      final dataPost = {
        'username': usernameCtrl.text,
        'password': passwordCtrl.text,
      };

      final uri = Uri.parse("$kApiBase/login.php");

      final response = await http
          .post(uri, headers: headers, body: jsonEncode(dataPost))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() => _isLoading = false);

      final respJson = json.decode(response.body) as Map<String, dynamic>;

      if (respJson['result'] == 1) {
        final role = respJson['role'];

        if (role == "student") {
          final userData = Map<String, dynamic>.from(respJson['datalist']);
          AppSession.userData = userData;
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: kDashboardRoute),
              builder: (_) => StudentDashboard(userData: userData),
            ),
          );
        } else if (role == "tutor") {
          final userData = Map<String, dynamic>.from(respJson['datalist']);
          AppSession.userData = userData;
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: kDashboardRoute),
              builder: (_) => TutorDashboard(userData: userData),
            ),
          );
        } else if (role == "admin") {
          final adminData = respJson['datalist'] != null
              ? Map<String, dynamic>.from(respJson['datalist'])
              : <String, dynamic>{};
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDashboardPage(adminData: adminData),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              respJson['message']?.toString() ?? 'เข้าสู่ระบบไม่สำเร็จ',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ กรุณาลองใหม่'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = AppColors.primary;
    const Color labelColor = Color(0xFF444444);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _skipIntro(),
          child: AnimatedBuilder(
            animation: _intro,
            builder: (context, _) => Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // --- หัวข้อ Sign In ---
                    _reveal(
                      0.55,
                      0.68,
                      const Center(
                        child: Text(
                          'เข้าสู่ระบบ',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // --- Illustration: ไอคอน FastTutor พุ่งเข้ามาเร็วแล้ว spring เข้าที่ ---
                    Center(
                      child: SizedBox(
                        width: 280,
                        height: 240,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            _ringPulse(),
                            Opacity(
                              opacity: _markOpacity(),
                              child: Transform.scale(
                                scale: _markScale(),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const FastTutorMark(size: 120),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // --- "Fast" พุ่งเข้ามาชน "Tutor" จากด้านซ้าย ---
                                        Builder(
                                          builder: (context) {
                                            final flyT = Curves.easeIn
                                                .transform(_p(0.66, 0.80));
                                            final impactT = _p(0.80, 0.90);
                                            final bounce = impactT > 0
                                                ? (Curves.elasticOut.transform(
                                                            impactT,
                                                          ) -
                                                          1) *
                                                      3
                                                : 0.0;
                                            final dx =
                                                (1 - flyT) * -80 + bounce;
                                            return Opacity(
                                              opacity: flyT > 0 ? 1 : 0,
                                              child: Transform.translate(
                                                offset: Offset(dx, 0),
                                                child: const Text(
                                                  'Fast',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w800,
                                                    color: primaryColor,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        // --- "Tutor" รออยู่กับที่ fade เข้ามาก่อน ---
                                        Opacity(
                                          opacity: Curves.easeOut.transform(
                                            _p(0.60, 0.72),
                                          ),
                                          child: const Text(
                                            'Tutor',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.dark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- Label + Input: Username ---
                    _reveal(
                      0.62,
                      0.75,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ชื่อผู้ใช้ / Username',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: labelColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: usernameCtrl,
                            decoration: InputDecoration(
                              hintText: 'ชื่อผู้ใช้ / Username',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBDBDBD),
                                fontSize: 16,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDDDDDD),
                                  width: 1.2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDDDDDD),
                                  width: 1.2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(
                                  color: primaryColor,
                                  width: 1.8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Label + Input: Password ---
                    _reveal(
                      0.70,
                      0.83,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'รหัสผ่าน / Password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: labelColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: passwordCtrl,
                            obscureText: _obscureText,
                            decoration: InputDecoration(
                              hintText: 'กรอกรหัสผ่าน / Enter Password',
                              hintStyle: const TextStyle(
                                color: Color(0xFFBDBDBD),
                                fontSize: 16,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDDDDDD),
                                  width: 1.2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDDDDDD),
                                  width: 1.2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: const BorderSide(
                                  color: primaryColor,
                                  width: 1.8,
                                ),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureText
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureText = !_obscureText;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- ปุ่ม Sign In ---
                    _reveal(
                      0.80,
                      0.92,
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'เข้าสู่ระบบ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- Divider ---
                    _reveal(
                      0.86,
                      0.96,
                      const Row(
                        children: [
                          Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'หรือ',
                              style: TextStyle(
                                color: Color(0xFFBDBDBD),
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- Footer: Sign Up ---
                    _reveal(
                      0.90,
                      1.0,
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "ยังไม่มีบัญชี? ",
                              style: TextStyle(
                                color: Color(0xFF888888),
                                fontSize: 15,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const Register(),
                                  ),
                                );
                              },
                              child: const Text(
                                'สมัครสมาชิก',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
