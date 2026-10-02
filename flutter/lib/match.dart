import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_nav_bar.dart';
import 'Learn.dart' hide Duration;
import 'teach.dart' hide Duration;
import 'learn_history.dart' show learnDetailRows;
import 'teach_history.dart' show teachDetailRows;
import 'EditProfilePage.dart';
import 'notifications_page.dart';
import 'chat_list_page.dart';
import 'photo_helper.dart';
import 'app_session.dart';
import 'app_theme.dart';
import 'api_config.dart';

String levelLabel(int v) {
  const l = ['เริ่มต้น', 'กลาง', 'สูง', 'ทุกระดับ'];
  return (v >= 0 && v < l.length) ? l[v] : '-';
}

String formatLabel(int v) {
  const l = ['ออนไลน์', 'ออฟไลน์', 'ผสมผสาน'];
  return (v >= 0 && v < l.length) ? l[v] : '-';
}

String priceLabel(int v) {
  const l = ['200-500 ฿/ชม.', '600-1,000 ฿/ชม.', '1,000+ ฿/ชม.'];
  return (v >= 0 && v < l.length) ? l[v] : '-';
}

String timeLabel(int v) {
  const l = ['เช้า', 'บ่าย', 'เย็น', 'วันหยุด'];
  return (v >= 0 && v < l.length) ? l[v] : '-';
}

// ฟังก์ชันหลัก: กำหนดสีของคะแนนความเข้ากันได้ โดยใช้เกณฑ์ที่กำหนดไว้เพื่อแสดงสีเขียวสำหรับคะแนนสูง, สีส้มสำหรับคะแนนปานกลาง และสีแดงสำหรับคะแนนต่ำ
Color scoreColor(double s) {
  if (s >= 80) return const Color(0xFF2E7D32);
  if (s >= 60) return const Color(0xFFF57F17);
  return const Color(0xFFC62828);
}

class MatchPage extends StatefulWidget {
  final String role;
  final String userId;
  final String userName;

  const MatchPage({
    super.key,
    required this.role,
    required this.userId,
    required this.userName,
  });

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _matches = [];
  String _mySubject = '';
  String _reqId = '';
  Map<String, dynamic>?
  _myRequest; // ความต้องการปัจจุบัน (แถวที่ใช้จับคู่) จาก api_matching
  final Map<String, String> _cardStatus = {};
  final Map<String, String> _cardMatchId =
      {}; // cardKey -> match_id (สำหรับคำขอที่ pending)
  final int _currentIndex = 2; // จับคู่

  int _unreadCount = 0;
  Timer? _notifTimer;

  @override
  void initState() {
    super.initState();
    _fetchMatches();
    _fetchUnreadCount();
    // ดึงจำนวนแจ้งเตือนใหม่ทุก 20 วินาที
    _notifTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _fetchUnreadCount(),
    );
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    super.dispose();
  }

  // ── ฟังก์ชันหลัก: ดึงจำนวนการแจ้งเตือนที่ยังไม่ได้อ่าน เพื่อแสดง badge บนไอคอนกระดิ่ง ───────────────────────
  Future<void> _fetchUnreadCount() async {
    try {
      final res = await http
          .get(
            Uri.parse(
              "$kApiBase/api_get_notifications.php?role=${widget.role}&id=${widget.userId}",
            ),
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      if (data['result'] == 1 && mounted) {
        setState(() => _unreadCount = (data['unread'] as num? ?? 0).toInt());
      }
    } catch (_) {
      // เงียบไว้ ไม่ต้องรบกวนผู้ใช้ถ้าดึงจำนวนแจ้งเตือนไม่สำเร็จ
    }
  }

  void _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NotificationsPage(role: widget.role, userId: widget.userId),
      ),
    );
    // เมื่อกลับมาจากหน้าแจ้งเตือน ให้รีเฟรชทั้งจำนวนที่ยังไม่อ่านและรายการจับคู่
    // (เผื่อมีการยืนยัน/ปฏิเสธคำขอเกิดขึ้นระหว่างอยู่ในหน้านั้น)
    _fetchUnreadCount();
    _fetchMatches();
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    switch (index) {
      case 0:
        goToDashboard(context);
        break;
      case 1:
        goToTab(
          context,
          _isStudent
              ? AddLearnPage(studentId: widget.userId)
              : AddTeachPage(tutorId: widget.userId),
        );
        break;
      case 2:
        break;
      case 4:
        goToTab(
          context,
          EditProfilePage(
            role: widget.role,
            userData: AppSession.userData,
            onUpdated: (_) {},
          ),
        );
        break;
      case 3:
        goToTab(
          context,
          ChatListPage(role: widget.role, userId: widget.userId),
        );
        break;
    }
  }

  bool get _isStudent => widget.role == 'student';
  Color get _themeColor => AppColors.forRole(widget.role);
  // ── ฟังก์ชันหลัก: ดึงข้อมูลคู่ที่เหมาะสมจาก API และจัดการสถานะการ Match ───────────────────────
  Future<void> _fetchMatches() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await http
          .post(
            Uri.parse("$kApiBase/api_matching.php"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"role": widget.role, "id": widget.userId}),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['result'] == 1) {
        final matches = List<Map<String, dynamic>>.from(data['matches'] ?? []);
        setState(() {
          _matches = matches;
          _mySubject = data['subject'] ?? '';
          _reqId = _isStudent
              ? (data['learn_id'] ?? '')
              : (data['teach_id'] ?? '');
          _myRequest = data['my_request'] is Map
              ? Map<String, dynamic>.from(data['my_request'] as Map)
              : null;
          _isLoading = false;
          // เติมสถานะคำขอที่มีอยู่แล้ว (pending/accepted) จาก server ลงในการ์ด
          for (final m in matches) {
            final String cardKey = _isStudent
                ? (m['teach_req_id']?.toString() ?? '')
                : (m['learn_reg_id']?.toString() ?? '');
            final String? reqStatus = m['request_status'] as String?;
            if (cardKey.isEmpty || reqStatus == null) continue;
            if (reqStatus == 'pending') {
              _cardStatus[cardKey] = 'pending';
            } else if (reqStatus == 'accepted') {
              _cardStatus[cardKey] = 'accepted';
            }
            // ถ้า rejected จะไม่ตั้งสถานะ เพื่อให้ผู้ใช้ส่งคำขอใหม่ได้
          }
        });
      } else {
        setState(() {
          _error = data['message'] ?? 'เกิดข้อผิดพลาด';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้\n$e';
        _isLoading = false;
      });
    }
  }

  // ── ฟังก์ชันหลัก: ส่ง "คำขอจับคู่" ไปยังอีกฝ่าย (ไม่ยืนยันทันที ต้องรออีกฝ่ายกดยอมรับ) หรือซ่อนการ์ดออกจากรายการของฉัน ─────
  Future<void> _saveMatch(Map<String, dynamic> m, String action) async {
    final String teachReqId = m['teach_req_id']?.toString() ?? '';
    final String learnRegId = m['learn_reg_id']?.toString() ?? '';
    final String cardKey = _isStudent ? teachReqId : learnRegId;

    if (action == 'reject') {
      // "ปฏิเสธ" ในหน้านี้คือการซ่อนการ์ดจากรายการแนะนำของฉันเอง ไม่ใช่การตอบคำขอที่ส่งเข้ามา
      setState(() => _cardStatus[cardKey] = 'rejected');
      return;
    }

    setState(() => _cardStatus[cardKey] = 'loading');
    try {
      final res = await http
          .post(
            Uri.parse("$kApiBase/api_send_request.php"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "sender_role": widget.role,
              "teach_req_id": teachReqId,
              "learn_reg_id": learnRegId,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      if (data['result'] == 1) {
        setState(() {
          _cardStatus[cardKey] = 'pending';
          if (data['match_id'] != null) {
            _cardMatchId[cardKey] = data['match_id'].toString();
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📨 ส่งคำขอจับคู่แล้ว กำลังรอการยืนยันจากอีกฝ่าย'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } else if (data['result'] == 2) {
        // มีคำขอ/การจับคู่อยู่แล้วสำหรับคู่นี้
        setState(() => _cardStatus[cardKey] = 'pending');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ℹ️ ${data['message']}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        setState(() => _cardStatus[cardKey] = '');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${data['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _cardStatus[cardKey] = '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ เชื่อมต่อไม่ได้'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          _isStudent ? 'ผู้สอนที่เหมาะสม' : 'ผู้เรียนที่เหมาะสม',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textDark),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.textDark,
                ),
                onPressed: _openNotifications,
              ),
              if (_unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        _unreadCount > 9 ? '9+' : '$_unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textDark),
            onPressed: _fetchMatches,
          ),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        role: widget.role,
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
      body: _isLoading
          ? _buildLoading()
          : _error != null
          ? _buildError()
          : _matches.isEmpty
          ? _buildEmpty()
          : _buildContent(),
    );
  }

  Widget _buildLoading() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: _themeColor),
        const SizedBox(height: 16),
        const Text(
          'กำลังค้นหาคู่ที่เหมาะสม...',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    ),
  );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 72, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('ลองใหม่'),
            style: ElevatedButton.styleFrom(backgroundColor: _themeColor),
            onPressed: _fetchMatches,
          ),
        ],
      ),
    ),
  );

  Widget _buildEmpty() => Column(
    children: [
      // ไม่พบคู่ ผู้ใช้ยิ่งอยากดูว่าตัวเองตั้งเงื่อนไขอะไรไว้ (อาจเข้มเกินไป)
      if (_myRequest != null) _buildRequestBanner(),
      Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 72, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'ยังไม่พบคู่ที่เหมาะสม',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ลองปรับเงื่อนไขหรือรอให้มีผู้ลงทะเบียนเพิ่ม',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  // ── แถบสรุปด้านบนหน้าจับคู่: ความต้องการที่ใช้จับคู่ + ปุ่มดูรายละเอียด ───────────
  Widget _buildRequestBanner({String? foundText}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                children: [
                  TextSpan(
                    text: '${widget.userName} ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _themeColor,
                    ),
                  ),
                  TextSpan(
                    text:
                        '($_reqId) • วิชา: $_mySubject${foundText == null ? '' : '\n'}',
                  ),
                  if (foundText != null)
                    TextSpan(
                      text: foundText,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _themeColor,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_myRequest != null)
            TextButton.icon(
              onPressed: _showMyRequest,
              icon: Icon(
                Icons.assignment_outlined,
                size: 18,
                color: _themeColor,
              ),
              label: Text(
                'ความต้องการของฉัน',
                style: TextStyle(
                  color: _themeColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  // ── ป๊อปอัปรายละเอียดความต้องการปัจจุบัน (แถวเดียวกับที่ใช้คำนวณคู่) ─────────────
  void _showMyRequest() {
    final req = _myRequest;
    if (req == null) return;
    final rows = _isStudent ? learnDetailRows(req) : teachDetailRows(req);
    final String subject =
        (_isStudent ? req['subject_learn'] : req['subject_teach'])
            ?.toString() ??
        _mySubject;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isStudent
                            ? 'ความต้องการเรียนของฉัน'
                            : 'ความต้องการสอนของฉัน',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _themeColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$subject  ($_reqId)',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _themeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'กำลังรอจับคู่',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _themeColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...rows,
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetCtx);
                            // ฟอร์มเติมค่าเดิม บันทึกแล้วทับแถว active เดิม แล้วกลับมาจับคู่
                            goToTab(
                              context,
                              _isStudent
                                  ? AddLearnPage(
                                      studentId: widget.userId,
                                      initialData: req,
                                    )
                                  : AddTeachPage(
                                      tutorId: widget.userId,
                                      initialData: req,
                                    ),
                            );
                          },
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('แก้ไขความต้องการ'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _themeColor,
                            side: BorderSide(color: _themeColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: const Text('ปิด'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── ฟังก์ชันหลัก: สร้างส่วนแสดงผลหลักเมื่อมีคู่ที่เหมาะสมปรากฏ โดยแสดงข้อมูลเบื้องต้นและจำนวนคู่ที่พบได้อย่างสวยงาม ───────────────────────
  Widget _buildContent() {
    return Column(
      children: [
        _buildRequestBanner(
          foundText: 'พบ ${_matches.length} คู่ที่เข้ากันได้',
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: _matches.length,
            itemBuilder: (ctx, i) => _buildCard(_matches[i], i),
          ),
        ),
      ],
    );
  }

  // ── Card แบบ thumbnail-left + info-right (เหมือนภาพแรก) ─────────────────
  Widget _buildCard(Map<String, dynamic> m, int index) {
    final double score = (m['score'] as num).toDouble();
    final Color scoreClr = scoreColor(score);
    final String name = _isStudent
        ? (m['tutor_name'] ?? '-')
        : (m['student_name'] ?? '-');
    final String gender = m['gender'] ?? '-';
    final int age = (m['age'] as num? ?? 0).toInt();
    final String subj = m['subject'] ?? '-';
    final int level = (m['level'] as num? ?? 0).toInt();
    final int fmt = (m['format'] as num? ?? 0).toInt();
    final int timeSlot = (m['time'] as num? ?? 0).toInt();
    final int price = _isStudent
        ? (m['rate'] as num? ?? 0).toInt()
        : (m['budget'] as num? ?? 0).toInt();
    final detail = Map<String, dynamic>.from(m['score_detail'] ?? {});
    final String cardKey = _isStudent
        ? (m['teach_req_id']?.toString() ?? '')
        : (m['learn_reg_id']?.toString() ?? '');
    final String status = _cardStatus[cardKey] ?? '';

    Color borderColor = Colors.transparent;
    if (status == 'accepted') borderColor = Colors.green;
    if (status == 'pending') borderColor = Colors.orange.withOpacity(0.6);
    if (status == 'rejected') borderColor = Colors.red.withOpacity(0.4);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _showDetail(m),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Avatar block (thumbnail) ─────────────────────────────────
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 76,
                        height: 90,
                        decoration: BoxDecoration(
                          color: _themeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          image: buildPhotoUrl(kApiBase, m['photo_url']) != null
                              ? DecorationImage(
                                  image: NetworkImage(
                                    buildPhotoUrl(kApiBase, m['photo_url'])!,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: buildPhotoUrl(kApiBase, m['photo_url']) == null
                            ? Icon(
                                _isStudent
                                    ? Icons.person_rounded
                                    : Icons.school_rounded,
                                size: 42,
                                color: _themeColor,
                              )
                            : null,
                      ),
                      Positioned(top: -6, left: -6, child: _rankBadge(index)),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // ── Info column ──────────────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subject label + score badge
                        Row(
                          children: [
                            Text(
                              subj,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _themeColor,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: scoreClr.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: scoreClr.withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                '${score.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: scoreClr,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),

                        // Name (bold)
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A2E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),

                        // Gender + Age
                        Text(
                          '$gender • $age ปี',
                          style: TextStyle(
                            fontSize: 15,
                            color: _themeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Chips
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            _chip(
                              Icons.signal_cellular_alt,
                              levelLabel(level),
                              Colors.purple,
                            ),
                            _chip(
                              Icons.attach_money,
                              priceLabel(price),
                              Colors.orange,
                            ),
                            _chip(
                              Icons.laptop_mac,
                              formatLabel(fmt),
                              Colors.teal,
                            ),
                            _chip(
                              Icons.access_time,
                              timeLabel(timeSlot),
                              Colors.indigo,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Score bars mini
                        _scoreBars(detail),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey[200]),
          _buildActionBar(m, status, cardKey),
        ],
      ),
    );
  }

  // ── ฟังก์ชันหลัก: สร้างแถบแอคชันที่ปรากฏด้านล่างของการ์ดแต่ละใบ โดยเปลี่ยนแปลงตามสถานะการ Match (loading, accepted, rejected) ───────────────────────
  Widget _buildActionBar(
    Map<String, dynamic> m,
    String status,
    String cardKey,
  ) {
    if (status == 'loading') {
      return Container(
        height: 52,
        decoration: const BoxDecoration(
          color: Color(0xFFF5F5F5),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (status == 'pending') {
      return Container(
        height: 52,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF8E1),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_top, color: Colors.orange[700], size: 18),
            const SizedBox(width: 8),
            Text(
              'ส่งคำขอแล้ว รอการยืนยัน',
              style: TextStyle(
                color: Colors.orange[800],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    if (status == 'accepted') {
      return Container(
        height: 52,
        decoration: const BoxDecoration(
          color: Color(0xFFE8F5E9),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            SizedBox(width: 8),
            Text(
              'จับคู่แล้ว รอการนัดหมาย',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    if (status == 'rejected') {
      return Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel, color: Colors.red[300], size: 20),
            const SizedBox(width: 8),
            Text(
              'ปฏิเสธแล้ว',
              style: TextStyle(
                color: Colors.red[400],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () => setState(() => _cardStatus[cardKey] = ''),
              child: const Text('เลิกทำ', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      );
    }
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final confirmed = await confirmDialog(
                  context,
                  title: 'ไม่สนใจรายการนี้',
                  message: 'คุณต้องการซ่อนรายการนี้ออกจากคำแนะนำใช่หรือไม่?',
                  confirmLabel: 'ไม่สนใจ',
                  danger: true,
                );
                if (confirmed) _saveMatch(m, 'reject');
              },
              child: Container(
                height: 52,
                color: const Color(0xFFFFF0F0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close, color: Colors.red[400], size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'ปฏิเสธ',
                      style: TextStyle(
                        color: Colors.red[600],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(width: 1, height: 52, color: Colors.grey[200]),
          Expanded(
            child: InkWell(
              onTap: () => _confirmAccept(m),
              child: Container(
                height: 52,
                color: const Color(0xFFF0FFF4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.send_rounded,
                      color: Colors.green[600],
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ส่งคำขอ',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ฟังก์ชันหลัก: แสดงหน้าต่างยืนยันก่อนยอมรับ Match พร้อมสรุปคะแนนและข้อมูลเบื้องต้น ───────────────────────
  void _confirmAccept(Map<String, dynamic> m) {
    final String name = _isStudent
        ? (m['tutor_name'] ?? '-')
        : (m['student_name'] ?? '-');
    final double score = (m['score'] as num).toDouble();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.send_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('ส่งคำขอจับคู่'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('คู่ที่เลือก: $name'),
            const SizedBox(height: 4),
            Text(
              'คะแนน: ${score.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'ระบบจะส่งคำขอจับคู่ไปแจ้งเตือนอีกฝ่าย และต้องรอให้อีกฝ่ายกดยืนยันก่อนจึงจะจับคู่กันสำเร็จ',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(context);
              _saveMatch(m, 'accept');
            },
            child: const Text('ส่งคำขอ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── ฟังก์ชันหลัก: แสดงรายละเอียดของคู่ที่เหมาะสมในรูปแบบ Modal Bottom Sheet พร้อมข้อมูลครบถ้วนและคะแนนแต่ละด้านอย่างชัดเจน ───────────────────────
  void _showDetail(Map<String, dynamic> m) {
    final double score = (m['score'] as num).toDouble();
    final color = scoreColor(score);
    final detail = Map<String, dynamic>.from(m['score_detail'] ?? {});
    final String name = _isStudent
        ? (m['tutor_name'] ?? '-')
        : (m['student_name'] ?? '-');
    final int level = (m['level'] as num? ?? 0).toInt();
    final int fmt = (m['format'] as num? ?? 0).toInt();
    final int time = (m['time'] as num? ?? 0).toInt();
    final int price = _isStudent
        ? (m['rate'] as num? ?? 0).toInt()
        : (m['budget'] as num? ?? 0).toInt();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withOpacity(0.1),
                                border: Border.all(color: color, width: 3),
                              ),
                              child: Center(
                                child: Text(
                                  '${score.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'คะแนนความเข้ากันได้',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${m['gender'] ?? '-'} • อายุ ${m['age'] ?? '-'} ปี',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const Divider(height: 28),
                      _detailRow(
                        Icons.book_outlined,
                        'วิชา',
                        m['subject'] ?? '-',
                      ),
                      _detailRow(
                        Icons.signal_cellular_alt,
                        'ระดับ',
                        levelLabel(level),
                      ),
                      _detailRow(Icons.attach_money, 'ราคา', priceLabel(price)),
                      _detailRow(Icons.laptop_mac, 'รูปแบบ', formatLabel(fmt)),
                      _detailRow(
                        Icons.access_time,
                        'ช่วงเวลา',
                        timeLabel(time),
                      ),
                      _detailRow(
                        Icons.school_outlined,
                        'การศึกษา',
                        m['education'] ?? '-',
                      ),
                      _detailRow(
                        Icons.email_outlined,
                        'อีเมล',
                        m['email'] ?? '-',
                      ),
                      _detailRow(
                        Icons.phone_outlined,
                        'เบอร์โทร',
                        m['phone'] ?? '-',
                      ),
                      const Divider(height: 28),
                      const Text(
                        'คะแนนแต่ละด้าน',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _scoreBarsLarge(detail),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── ฟังก์ชันหลัก: สร้าง badge แสดงอันดับของคู่ที่เหมาะสมในรูปแบบวงกลม พร้อมสีที่แตกต่างกันสำหรับอันดับ 1-3 และอันดับอื่นๆ ───────────────────────
  Widget _rankBadge(int i) {
    final colors = [
      Colors.amber[600],
      Colors.grey[400],
      const Color(0xFFCD7F32),
    ];
    final bg = i < 3 ? colors[i] : Colors.grey[200];
    final txt = i < 3 ? Colors.white : Colors.grey[600];
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(
        child: Text(
          '${i + 1}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: txt,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
  // ── ฟังก์ชันหลัก: สร้างแถบแสดงคะแนนแต่ละด้านในรูปแบบที่กะทัดรัด เหมาะสำหรับการแสดงในการ์ด โดยมีสีที่แตกต่างกันตามแต่ละด้านและแสดงเปอร์เซ็นต์อย่างชัดเจน ───────────────────────
  Widget _scoreBars(Map<String, dynamic> detail) {
    final items = [
      {'label': 'วิชา', 'key': 'subject', 'color': Colors.blue},
      {'label': 'ระดับ', 'key': 'level', 'color': Colors.purple},
      {'label': 'เวลา', 'key': 'time', 'color': Colors.orange},
      {'label': 'ราคา', 'key': 'price', 'color': Colors.green},
      {'label': 'รูปแบบการสอน', 'key': 'style', 'color': Colors.red},
      {'label': 'ภาษา', 'key': 'language', 'color': Colors.teal},
    ];
    return Column(
      children: items.map((item) {
        final double val = (detail[item['key']] as num? ?? 0).toDouble();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  item['label'] as String,
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: val / 100,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      item['color'] as Color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 34,
                child: Text(
                  '${val.toInt()}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _scoreBarsLarge(Map<String, dynamic> detail) {
    final items = [
      {'label': 'วิชา (25%)', 'key': 'subject', 'color': Colors.blue},
      {'label': 'ระดับ (15%)', 'key': 'level', 'color': Colors.purple},
      {'label': 'เวลา (20%)', 'key': 'time', 'color': Colors.orange},
      {'label': 'ราคา (15%)', 'key': 'price', 'color': Colors.green},
      {'label': 'รูปแบบการสอน (10%)', 'key': 'style', 'color': Colors.red},
      {'label': 'ภาษา (10%)', 'key': 'language', 'color': Colors.teal},
      {'label': 'ระยะทาง (5%)', 'key': 'distance', 'color': Colors.brown},
    ];
    return Column(
      children: items.map((item) {
        final double val = (detail[item['key']] as num? ?? 0).toDouble();
        final Color c = item['color'] as Color;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item['label'] as String,
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    '${val.toInt()}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: c,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: val / 100,
                  minHeight: 9,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(c),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: Colors.grey[500]),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 15),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ),
      ],
    ),
  );
}
