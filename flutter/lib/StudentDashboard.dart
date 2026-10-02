import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'Learn.dart' hide Duration;
import 'match.dart';
import 'EditProfilePage.dart';
import 'chat_list_page.dart';
import 'photo_helper.dart';
import 'app_nav_bar.dart';
import 'app_session.dart';
import 'birth_date_field.dart';
import 'app_theme.dart';
import 'api_config.dart';

class StudentDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  const StudentDashboard({super.key, required this.userData});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> with RouteAware {
  late Map<String, dynamic> _userData;
  int _currentIndex = 0;
  late AppLifecycleListener _lifecycleListener;

  // 🔹 ข้อมูลแมตช์ที่ยืนยันแล้วล่าสุด + คะแนนความเข้ากันได้ (match_score จาก match_table)
  Map<String, dynamic>? _currentMatch;
  bool _isLoadingScore = true;

  // 🔹 แปลงรหัสตัวเลข (int) ที่เก็บในฐานข้อมูลให้เป็นข้อความแสดงผล
  static const Map<int, String> _languageOptions = {
    1: 'ไทย',
    2: 'อังกฤษ',
    3: 'จีน',
    4: 'อื่นๆ',
  };
  static const Map<int, String> _knowledgeLevelOptions = {
    1: 'ประถมศึกษา',
    2: 'มัธยมศึกษา',
    3: 'อุดมศึกษา',
    4: 'สูงกว่าอุดมศึกษา',
    5: 'อื่นๆ',
  };
  static const Map<int, String> _courseInterestOptions = {
    1: 'เตรียมสอบ',
    2: 'งานอาชีพ',
    3: 'งานอดิเรก',
    4: 'อื่นๆ',
  };

  String _labelFor(Map<int, String> options, dynamic raw) {
    if (raw == null) return '-';
    final code = raw is int ? raw : int.tryParse(raw.toString());
    if (code == null) return '-';
    return options[code] ?? '-';
  }

  @override
  void initState() {
    super.initState();
    _userData = Map<String, dynamic>.from(widget.userData);
    AppSession.user.addListener(_syncUserData);
    _sendPing();
    _fetchLatestScore();
    _lifecycleListener = AppLifecycleListener(
      onResume: _sendPing, // กลับมาที่แอปก็ ping
      onHide: _sendLogout, // กดโฮม/ออกจากแอปก็ logout
    );
  }

  // 🔹 ดึงแมตช์ที่ยืนยันแล้วล่าสุดของนักเรียน พร้อมคะแนน compatibility ที่บันทึกไว้
  Future<void> _fetchLatestScore() async {
    try {
      final uri = Uri.parse(
        "$kApiBase/api_get_current_match.php"
        "?role=student&id=${_userData['student_id']}",
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      if (data['result'] == 1) {
        setState(() {
          _currentMatch = (data['has_match'] == true)
              ? Map<String, dynamic>.from(data as Map)
              : null;
          _isLoadingScore = false;
        });
      } else {
        setState(() => _isLoadingScore = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingScore = false);
    }
  }

  @override
  void dispose() {
    AppSession.user.removeListener(_syncUserData);
    routeObserver.unsubscribe(this);
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _sendPing() async {
    try {
      await http.post(
        Uri.parse('$kApiBase/api_admin.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'ping',
          'role': 'student',
          'id': _userData['student_id'],
        }),
      );
    } catch (_) {}
  }

  Future<void> _sendLogout() async {
    try {
      await http.post(
        Uri.parse('$kApiBase/api_admin.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'logout',
          'role': 'student',
          'id': _userData['student_id'],
        }),
      );
    } catch (_) {}
  }

  // 🔹 ดึงข้อมูลล่าสุดจาก AppSession (อาจถูกแก้ไขจากหน้าอื่น) มาแสดงบน Dashboard
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of<void>(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  // 🔹 เรียกเมื่อกลับมาถึงแดชบอร์ดจริง ๆ (จากหน้าใดก็ตามที่ซ้อนอยู่) → รีเซ็ตแท็บ + รีเฟรชข้อมูล/คะแนน
  @override
  void didPopNext() {
    setState(() => _currentIndex = 0);
    _syncUserData();
    _fetchLatestScore();
  }

  void _syncUserData() {
    if (AppSession.userData.isEmpty || !mounted) return;
    setState(() => _userData = AppSession.userData);
  }

  void _goToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          role: 'student',
          userData: _userData,
          onUpdated: (updated) => setState(() => _userData = updated),
        ),
      ),
    );
  }

  void _onNavTap(int index) {
    final String fullName =
        "${_userData['first_name_student']} ${_userData['last_name_student']}";
    final String studentId = _userData['student_id'];

    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        // อยู่หน้านี้แล้ว ไม่ต้อง navigate
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddLearnPage(studentId: studentId)),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchPage(
              role: 'student',
              userId: studentId,
              userName: fullName,
            ),
          ),
        );
        break;
      case 4:
        setState(() => _currentIndex = 0);
        _goToEditProfile();
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatListPage(role: 'student', userId: studentId),
          ),
        );
        break;
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await confirmDialog(
      context,
      title: 'ออกจากระบบ',
      message: 'คุณต้องการออกจากระบบใช่หรือไม่?',
      confirmLabel: 'ออกจากระบบ',
      danger: true,
    );
    if (!confirmed) return;
    await _sendLogout();
    if (mounted) Navigator.pop(context);
  }

  // canPop: false → ปุ่ม back ของเครื่องบนแดชบอร์ดต้องถามออกจากระบบก่อน (ไม่ถอยไปหน้าล็อกอินเงียบ ๆ)
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLogout();
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    const Color primaryColor = AppColors.studentAccent;
    final String fullName =
        "${_userData['first_name_student']} ${_userData['last_name_student']}";
    final String studentId = _userData['student_id'];
    final String education = _userData['education_level'] ?? '-';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'แดชบอร์ดผู้เรียน',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.textDark),
            tooltip: 'แก้ไขโปรไฟล์',
            onPressed: _goToEditProfile,
          ),
        ],
      ),

      // ── Bottom Navigation Bar ────────────────────────────────────────────
      bottomNavigationBar: AppNavBar(
        role: 'student',
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),

      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: _fetchLatestScore,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ── Hero header ──────────────────────────────────────────────
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                            border: Border.all(color: Colors.white, width: 3),
                            image:
                                buildPhotoUrl(
                                      kApiBase,
                                      _userData['photo_path'],
                                    ) !=
                                    null
                                ? DecorationImage(
                                    image: NetworkImage(
                                      buildPhotoUrl(
                                        kApiBase,
                                        _userData['photo_path'],
                                      )!,
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child:
                              buildPhotoUrl(
                                    kApiBase,
                                    _userData['photo_path'],
                                  ) ==
                                  null
                              ? const Icon(
                                  Icons.school_rounded,
                                  size: 52,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        GestureDetector(
                          onTap: _goToEditProfile,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: primaryColor, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt_outlined,
                              size: 20,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      education,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── เมนูหลัก (กริดใหญ่ กดง่าย) ───────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildQuickActionGrid(primaryColor),
              ),

              const SizedBox(height: 24),

              // ── การ์ดสรุปสถานะ/คะแนนการจับคู่ล่าสุด ─────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildScoreCard(primaryColor),
              ),

              const SizedBox(height: 24),

              // ── About section ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'เกี่ยวกับ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Divider(color: Colors.grey[300])),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _goToEditProfile,
                          child: const Text(
                            'แก้ไข',
                            style: TextStyle(
                              fontSize: 13,
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    _infoTile('ชื่อ-นามสกุล', fullName, Icons.person_outline),
                    _infoTile('รหัส', studentId, Icons.badge_outlined),
                    _infoTile(
                      'ชื่อผู้ใช้',
                      _userData['st_username'] ?? '-',
                      Icons.account_circle_outlined,
                    ),
                    _infoTile(
                      'เพศ',
                      _userData['gender_student'] ?? '-',
                      Icons.wc_outlined,
                    ),
                    _infoTile(
                      'อายุ',
                      '${ageFromBirthDate(_userData['birth_date']) ?? _userData['age_student'] ?? '-'} ปี',
                      Icons.cake_outlined,
                    ),
                    _infoTile(
                      'อาชีพ',
                      _userData['occupation'] ?? '-',
                      Icons.work_outline,
                    ),
                    _infoTile('การศึกษา', education, Icons.school_outlined),
                    _infoTile(
                      'อีเมล',
                      _userData['email_student'] ?? '-',
                      Icons.email_outlined,
                    ),
                    _infoTile(
                      'เบอร์โทร',
                      _userData['phone_number_student'] ?? '-',
                      Icons.phone_outlined,
                    ),
                    _infoTile(
                      'เขตที่เรียน',
                      _userData['learning_zone'] ?? '-',
                      Icons.map_outlined,
                    ),
                    _infoTile(
                      'ภาษาที่ใช้',
                      _labelFor(_languageOptions, _userData['language_used']),
                      Icons.language_outlined,
                    ),
                    _infoTile(
                      'ระดับความรู้ปัจจุบัน',
                      _labelFor(
                        _knowledgeLevelOptions,
                        _userData['knowledge_level'],
                      ),
                      Icons.auto_stories_outlined,
                    ),
                    _infoTile(
                      'วัตถุประสงค์การเรียน',
                      _labelFor(
                        _courseInterestOptions,
                        _userData['course_interest'],
                      ),
                      Icons.flag_outlined,
                    ),

                    const SizedBox(height: 24),

                    // Logout button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: const Text(
                          'ออกจากระบบ',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _confirmLogout,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 กริดเมนูหลัก ปุ่มใหญ่ กดง่าย เข้าถึงเมนูที่ใช้บ่อยได้ทันทีจากหน้าแรก
  Widget _buildQuickActionGrid(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'เมนูหลัก',
          style: TextStyle(
            fontSize: AppText.heading,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // สูงคงที่ตามขนาดตัวอักษร (ไม่ใช้อัตราส่วน เพราะจอแคบ/ตัวอักษรใหญ่จะล้น)
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent:
                112 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
          ),
          children: [
            _quickActionCard(
              icon: Icons.account_circle_outlined,
              label: 'โปรไฟล์ของฉัน',
              color: primaryColor,
              onTap: () => _onNavTap(4),
            ),
            _quickActionCard(
              icon: Icons.search,
              label: 'หาติวเตอร์',
              color: primaryColor,
              onTap: () => _onNavTap(2),
            ),
            _quickActionCard(
              icon: Icons.menu_book_outlined,
              label: 'ความต้องการเรียน',
              color: primaryColor,
              onTap: () => _onNavTap(1),
            ),
            _quickActionCard(
              icon: Icons.chat_bubble_outline,
              label: 'แชท',
              color: primaryColor,
              onTap: () => _onNavTap(3),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF7F7F8),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: color),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppText.body,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 การ์ดแสดงคะแนนความเข้ากันได้ (Score_student) ของคำขอเรียนล่าสุด
  Widget _buildScoreCard(Color primaryColor) {
    if (_isLoadingScore) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }

    if (_currentMatch == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[400]),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'ยังไม่มีการจับคู่ที่ยืนยันแล้ว ไปที่หน้า "จับคู่" เพื่อเริ่มค้นหาติวเตอร์',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ),
          ],
        ),
      );
    }

    final subject = _currentMatch!['subject']?.toString() ?? '-';
    final tutorName = _currentMatch!['partner_name']?.toString() ?? '-';
    final rawScore = _currentMatch!['score'];
    final double? score = rawScore == null
        ? null
        : (rawScore is num
              ? rawScore.toDouble()
              : double.tryParse(rawScore.toString()));
    final bool hasScore = score != null && score > 0;
    final Color badgeColor = hasScore ? scoreColor(score) : Colors.grey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.insights_rounded, color: primaryColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'จับคู่แล้ว: $subject กับ $tutorName',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  hasScore ? 'คะแนนความเข้ากันได้' : 'ไม่มีข้อมูลคะแนน',
                  style: TextStyle(
                    fontSize: AppText.caption,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: badgeColor.withOpacity(0.4)),
            ),
            child: Text(
              hasScore ? '${score.toStringAsFixed(1)}%' : '-',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    const Color primaryColor = AppColors.studentAccent;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: primaryColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: AppText.caption,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: AppText.bodyLg,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.grey[200]),
      ],
    );
  }
}
