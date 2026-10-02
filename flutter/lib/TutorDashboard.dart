import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'teach.dart' hide Duration;
import 'match.dart';
import 'EditProfilePage.dart';
import 'chat_list_page.dart';
import 'photo_helper.dart';
import 'app_nav_bar.dart';
import 'app_session.dart';
import 'birth_date_field.dart';
import 'app_theme.dart';
import 'api_config.dart';

class TutorDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;
  const TutorDashboard({super.key, required this.userData});

  @override
  State<TutorDashboard> createState() => _TutorDashboardState();
}

class _TutorDashboardState extends State<TutorDashboard> with RouteAware {
  late Map<String, dynamic> _userData;
  int _currentIndex = 0;
  late AppLifecycleListener _lifecycleListener;

  // 🔹 ข้อมูลแมตช์ที่ยืนยันแล้วล่าสุด + คะแนนความเข้ากันได้ (match_score จาก match_table)
  Map<String, dynamic>? _currentMatch;
  bool _isLoadingScore = true;

  // 🔹 แปลงรหัสตัวเลข (int) ที่เก็บในฐานข้อมูลให้เป็นข้อความแสดงผล
  static const Map<int, String> _languageTeachOptions = {
    1: 'ไทย',
    2: 'อังกฤษ',
    3: 'จีน',
    4: 'อื่นๆ',
  };
  static const Map<int, String> _teachableLevelOptions = {
    1: 'เริ่มต้น',
    2: 'กลาง',
    3: 'สูง',
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
      onResume: _sendPing,
      onHide: _sendLogout,
    );
  }

  // 🔹 ดึงแมตช์ที่ยืนยันแล้วล่าสุดของติวเตอร์ พร้อมคะแนน compatibility ที่บันทึกไว้
  Future<void> _fetchLatestScore() async {
    try {
      final uri = Uri.parse(
        "$kApiBase/api_get_current_match.php"
        "?role=tutor&id=${_userData['tutor_id']}",
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
          'role': 'tutor',
          'id': _userData['tutor_id'],
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
          'role': 'tutor',
          'id': _userData['tutor_id'],
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

  void _goToEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          role: 'tutor',
          userData: _userData,
          onUpdated: (updated) => setState(() => _userData = updated),
        ),
      ),
    );
  }

  void _onNavTap(int index) {
    final String fullName =
        "${_userData['first_name_tutor']} ${_userData['last_name_tutor']}";
    final String tutorId = _userData['tutor_id'];

    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddTeachPage(tutorId: tutorId)),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                MatchPage(role: 'tutor', userId: tutorId, userName: fullName),
          ),
        );
        break;
      case 4:
        setState(() => _currentIndex = 0);
        _goToEdit();
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatListPage(role: 'tutor', userId: tutorId),
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
    const Color primaryColor = AppColors.tutorAccent;
    final String fullName =
        "${_userData['first_name_tutor']} ${_userData['last_name_tutor']}";
    final String tutorId = _userData['tutor_id'];
    final String education = _userData['education_qualification'] ?? '-';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'แดชบอร์ดผู้สอน',
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
            onPressed: _goToEdit,
          ),
        ],
      ),

      // ── Bottom Navigation Bar ────────────────────────────────────────────
      bottomNavigationBar: AppNavBar(
        role: 'tutor',
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
                                  Icons.person_rounded,
                                  size: 52,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        GestureDetector(
                          onTap: _goToEdit,
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
                          onTap: _goToEdit,
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
                    _infoTile('รหัสผู้สอน', tutorId, Icons.badge_outlined),
                    _infoTile(
                      'วิชาที่สอน',
                      _userData['subject_teach'] ?? '-',
                      Icons.menu_book_outlined,
                    ),
                    _infoTile(
                      'วุฒิการศึกษา',
                      education,
                      Icons.workspace_premium_outlined,
                    ),
                    _infoTile(
                      'เพศ',
                      _userData['gender_tutor'] ?? '-',
                      Icons.wc_outlined,
                    ),
                    _infoTile(
                      'อายุ',
                      '${ageFromBirthDate(_userData['birth_date']) ?? _userData['age_tutor'] ?? '-'} ปี',
                      Icons.cake_outlined,
                    ),
                    _infoTile(
                      'อีเมล',
                      _userData['email_tutor'] ?? '-',
                      Icons.email_outlined,
                    ),
                    _infoTile(
                      'เบอร์โทร',
                      _userData['phone_number_tutor'] ?? '-',
                      Icons.phone_outlined,
                    ),
                    _infoTile(
                      'โซนที่สอน',
                      _userData['teaching_zone'] ?? '-',
                      Icons.map_outlined,
                    ),
                    _infoTile(
                      'ภาษาที่สอนได้',
                      _labelFor(
                        _languageTeachOptions,
                        _userData['language_teach'],
                      ),
                      Icons.language_outlined,
                    ),
                    _infoTile(
                      'ระดับที่สอนได้',
                      _labelFor(
                        _teachableLevelOptions,
                        _userData['teachable_level'],
                      ),
                      Icons.stairs_outlined,
                    ),
                    _infoTile(
                      'ประสบการณ์สอน',
                      _userData['teaching_experience'] ?? '-',
                      Icons.timeline_outlined,
                    ),
                    _infoTile(
                      'ประวัติการสอน',
                      _userData['experience'] ?? '-',
                      Icons.history_edu_outlined,
                    ),
                    _infoTile(
                      'ผลงาน/ใบรับรอง',
                      _userData['performance'] ?? '-',
                      Icons.workspace_premium_outlined,
                    ),
                    _infoTile(
                      'ความเชี่ยวชาญ',
                      _userData['expertise'] ?? '-',
                      Icons.star_outline,
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
              label: 'หานักเรียน',
              color: primaryColor,
              onTap: () => _onNavTap(2),
            ),
            _quickActionCard(
              icon: Icons.menu_book_outlined,
              label: 'ความต้องการสอน',
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

  // 🔹 การ์ดแสดงคะแนนความเข้ากันได้ (Score_tutor) ของคำขอสอนล่าสุด
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
                'ยังไม่มีการจับคู่ที่ยืนยันแล้ว ไปที่หน้า "จับคู่" เพื่อเริ่มค้นหานักเรียน',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ),
          ],
        ),
      );
    }

    final subject = _currentMatch!['subject']?.toString() ?? '-';
    final studentName = _currentMatch!['partner_name']?.toString() ?? '-';
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
                  'จับคู่แล้ว: $subject กับ $studentName',
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
    const Color primaryColor = AppColors.tutorAccent;
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
