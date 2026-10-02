import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_theme.dart';

/// แท็บ "รายงาน" ในหน้าแดชบอร์ดแอดมิน — สรุปสถิติภาพรวมของระบบเป็นการ์ดตัวเลข + กราฟ
class AdminReportTab extends StatefulWidget {
  final Uri adminUri;
  const AdminReportTab({super.key, required this.adminUri});

  @override
  State<AdminReportTab> createState() => _AdminReportTabState();
}

class _AdminReportTabState extends State<AdminReportTab> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _report;
  DateTimeRange? _dateRange;

  static const Color _navy = AppColors.dark;
  static const Color _accent = AppColors.primary;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateRange,
      helpText: 'เลือกช่วงวันที่สำหรับรายงาน',
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _fetchReport();
    }
  }

  void _clearDateRange() {
    setState(() => _dateRange = null);
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{'action': 'get_report'};
      if (_dateRange != null) {
        body['start_date'] = _fmtDate(_dateRange!.start);
        body['end_date'] = _fmtDate(_dateRange!.end);
      }
      final res = await http
          .post(
            widget.adminUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['result'] == 1) {
        setState(() {
          _report = Map<String, dynamic>.from(data['report']);
          _loading = false;
        });
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'ไม่สามารถโหลดรายงานได้';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ กรุณาลองใหม่';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 56, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('ลองใหม่'),
                style: ElevatedButton.styleFrom(backgroundColor: _accent),
                onPressed: _fetchReport,
              ),
            ],
          ),
        ),
      );
    }

    final report = _report!;
    final statusCounts = Map<String, dynamic>.from(
      report['match_status_counts'] ?? {},
    );
    final int pending = (statusCounts['pending'] as num?)?.toInt() ?? 0;
    final int confirmed = (statusCounts['confirmed'] as num?)?.toInt() ?? 0;
    final int rejected = (statusCounts['rejected'] as num?)?.toInt() ?? 0;
    List<Map<String, dynamic>> listOf(String key) =>
        List<Map<String, dynamic>>.from(
          (report[key] as List? ?? []).map((e) => Map<String, dynamic>.from(e)),
        );
    final topSubjects = listOf('top_subjects');
    final topTutors = listOf('top_tutors');
    final subjectGaps = listOf('subject_gaps');
    final successRate = report['success_rate'];
    final chatRate = report['confirmed_with_chat_rate'];

    return RefreshIndicator(
      onRefresh: _fetchReport,
      color: _accent,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _dateFilterBar(),
          const SizedBox(height: 16),

          // 1) ภาพรวมผู้ใช้ (ค่าปัจจุบัน)
          _sectionCard(
            title: 'ภาพรวมผู้ใช้',
            icon: Icons.groups_outlined,
            scope: 'ข้อมูลปัจจุบัน',
            why:
                'บอกขนาดระบบและสัดส่วนผู้เรียนต่อผู้สอน เพื่อดูว่าฝั่งใดขาดแคลน',
            guide:
                'ผู้เรียนมากกว่าผู้สอนมาก → คนหาผู้สอนไม่เจอ ควรรับสมัครติวเตอร์เพิ่ม\n'
                'จำนวนออนไลน์น้อยผิดปกติ → ตรวจว่าแอปและระบบใช้งานได้ตามปกติ\n'
                'ตัวเลขส่วนนี้เป็นค่า ณ ตอนนี้ ไม่ขึ้นกับช่วงวันที่ที่เลือก',
            child: _metricGrid([
              _Metric(
                'นักเรียนทั้งหมด',
                '${report['total_students'] ?? 0}',
                Icons.school_outlined,
                _accent,
              ),
              _Metric(
                'ติวเตอร์ทั้งหมด',
                '${report['total_tutors'] ?? 0}',
                Icons.person_pin_outlined,
                Colors.indigo,
              ),
              _Metric(
                'นักเรียนออนไลน์ตอนนี้',
                '${report['online_students'] ?? 0}',
                Icons.wifi_tethering,
                Colors.green,
              ),
              _Metric(
                'ติวเตอร์ออนไลน์ตอนนี้',
                '${report['online_tutors'] ?? 0}',
                Icons.wifi_tethering,
                Colors.teal,
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // 2) ประสิทธิภาพการจับคู่
          _sectionCard(
            title: 'ประสิทธิภาพการจับคู่',
            icon: Icons.pie_chart_outline,
            scope: 'ตามช่วงวันที่',
            why:
                'เป็นตัวชี้วัดหลักว่าระบบจับคู่ช่วยให้คนได้เรียน/สอนจริงหรือไม่',
            guide:
                'อัตราสำเร็จ = สำเร็จ ÷ (สำเร็จ + ปฏิเสธ) ไม่นับคำขอที่ยังรอยืนยันเพราะยังไม่มีผลตัดสิน\n'
                'อัตราสำเร็จต่ำ/ปฏิเสธสูง → เงื่อนไขหรือคะแนนที่ใช้จับคู่อาจไม่ตรงความต้องการจริง\n'
                'รอยืนยันเยอะ → อีกฝ่ายไม่ตอบ ควรเตือนให้ตอบคำขอ',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metricGrid([
                  _Metric(
                    'คำขอจับคู่ทั้งหมด',
                    '${report['total_matches'] ?? 0}',
                    Icons.swap_horiz_rounded,
                    Colors.blueGrey,
                  ),
                  _Metric(
                    'จับคู่สำเร็จ',
                    '${report['confirmed_matches'] ?? confirmed}',
                    Icons.handshake_outlined,
                    _accent,
                  ),
                  _Metric(
                    'อัตราสำเร็จ',
                    successRate != null ? '$successRate%' : '-',
                    Icons.trending_up_rounded,
                    Colors.green,
                  ),
                ]),
                if (successRate == null)
                  _note(
                    'ยังไม่มีคำขอที่ตัดสินแล้ว (สำเร็จ/ปฏิเสธ) ในช่วงนี้ จึงยังคำนวณอัตราสำเร็จไม่ได้',
                  ),
                const SizedBox(height: 16),
                _matchStatusChart(pending, confirmed, rejected),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3) อุปสงค์–อุปทาน (ค่าปัจจุบัน)
          _sectionCard(
            title: 'อุปสงค์–อุปทาน',
            icon: Icons.balance_outlined,
            scope: 'ข้อมูลปัจจุบัน',
            why: 'ชี้ว่าควรหาผู้สอนวิชาไหนเพิ่ม และมีคนรอจับคู่กี่คน',
            guide:
                'ส่วนต่าง = จำนวนผู้เรียนที่ต้องการ − จำนวนผู้สอนที่เปิดรับของวิชานั้น\n'
                'ส่วนต่างสูง = วิชาที่มีคนรอแต่ไม่มีผู้สอน ควรประชาสัมพันธ์รับสมัครติวเตอร์วิชานั้น\n'
                'ชื่อวิชาเป็นข้อความที่ผู้ใช้พิมพ์เอง จึงนับเฉพาะชื่อที่ตรงกัน (ไม่สนตัวพิมพ์เล็ก/ใหญ่และช่องว่างหัวท้าย)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metricGrid([
                  _Metric(
                    'ผู้เรียนที่รอจับคู่',
                    '${report['active_learn_count'] ?? 0}',
                    Icons.hourglass_empty_rounded,
                    Colors.deepOrange,
                  ),
                  _Metric(
                    'ผู้สอนที่เปิดรับ',
                    '${report['active_teach_count'] ?? 0}',
                    Icons.how_to_reg_outlined,
                    Colors.indigo,
                  ),
                ]),
                const SizedBox(height: 16),
                const Text(
                  'วิชาที่ผู้เรียนต้องการมากกว่าผู้สอน',
                  style: TextStyle(
                    fontSize: AppText.body,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                subjectGaps.isEmpty
                    ? _emptyText('ตอนนี้ไม่มีความต้องการเรียนที่เปิดอยู่')
                    : _gapList(subjectGaps),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4) วิชายอดนิยม
          _sectionCard(
            title: 'วิชายอดนิยม (แมตช์มากที่สุด)',
            icon: Icons.bar_chart_outlined,
            scope: 'ตามช่วงวันที่',
            why:
                'รู้ว่าวิชาไหนคือความต้องการหลักของตลาด เพื่อวางแผนเนื้อหาและโปรโมชัน',
            guide:
                'เลือกช่วงวันที่ต่างกันเพื่อดูแนวโน้มตามฤดูกาล เช่น ช่วงก่อนสอบ',
            child: topSubjects.isEmpty
                ? _emptyText('ยังไม่มีข้อมูลการแมตช์')
                : _rankedList(topSubjects, 'subject'),
          ),
          const SizedBox(height: 16),

          // 5) ผู้สอนยอดนิยม
          _sectionCard(
            title: 'ผู้สอนยอดนิยม (แมตช์สำเร็จมากที่สุด)',
            icon: Icons.star_border_rounded,
            scope: 'ตามช่วงวันที่',
            why:
                'ยกย่องผู้สอนคุณภาพ และเฝ้าดูความเสี่ยงที่งานกระจุกตัวกับผู้สอนไม่กี่คน',
            guide:
                'ผู้สอนคนเดียวได้แมตช์เกินครึ่ง → เสี่ยงหากเขาออกจากระบบ ควรกระจายคู่ให้ผู้สอนคนอื่นหรือหาผู้สอนสำรอง',
            child: topTutors.isEmpty
                ? _emptyText('ยังไม่มีข้อมูลผู้สอนที่แมตช์สำเร็จ')
                : _rankedList(topTutors, 'tutor_name'),
          ),
          const SizedBox(height: 16),

          // 6) การใช้งานแชท
          _sectionCard(
            title: 'การใช้งานแชท',
            icon: Icons.forum_outlined,
            scope: 'ตามช่วงวันที่',
            why:
                'แมตช์สำเร็จแต่ไม่คุยกัน = จับคู่แล้วไม่เกิดการเรียนจริง ซึ่งดูจากจำนวนแมตช์อย่างเดียวไม่เห็น',
            guide:
                'ห้องแชทที่ไม่มีการคุยกัน = แมตช์ที่ยืนยันแล้ว (เปิดห้องแชทได้) แต่ยังไม่มีใครส่งข้อความสักข้อความ\n'
                'ห้องที่ไม่มีการคุยกันมาก / สัดส่วนต่ำ → ผู้ใช้อาจไม่รู้ว่าต้องนัดหมายต่อหลังจับคู่ ควรปรับข้อความแจ้งเตือนหรือเพิ่มขั้นตอนนำทางหลังจับคู่สำเร็จ\n'
                'นับจากแมตช์ที่ยืนยันในช่วงวันที่ที่เลือก',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metricGrid([
                  _Metric(
                    'ห้องแชทที่ไม่มีการคุยกัน',
                    '${report['chat_rooms_silent'] ?? 0}',
                    Icons.speaker_notes_off_outlined,
                    Colors.deepOrange,
                  ),
                  _Metric(
                    'ห้องแชทที่มีการคุย',
                    '${report['chat_rooms'] ?? 0}',
                    Icons.meeting_room_outlined,
                    Colors.indigo,
                  ),
                  _Metric(
                    'แมตช์สำเร็จที่มีการคุยกัน',
                    chatRate != null ? '$chatRate%' : '-',
                    Icons.mark_chat_read_outlined,
                    Colors.green,
                  ),
                ]),
                if (chatRate == null)
                  _note(
                    'ยังไม่มีแมตช์ที่ยืนยันในช่วงนี้ จึงยังคำนวณสัดส่วนไม่ได้',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyText(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.grey, fontSize: AppText.body),
      ),
    ),
  );

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: AppText.caption, color: Colors.grey),
    ),
  );

  /// รายการวิชาที่ผู้เรียนต้องการมากกว่าผู้สอน: ต้องการ/ผู้สอน/ส่วนต่าง
  Widget _gapList(List<Map<String, dynamic>> items) {
    return Column(
      children: items.map((g) {
        final int gap = (g['gap'] as num?)?.toInt() ?? 0;
        final int demand = (g['demand'] as num?)?.toInt() ?? 0;
        final int supply = (g['supply'] as num?)?.toInt() ?? 0;
        final Color c = gap > 0 ? Colors.deepOrange : Colors.green;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g['subject']?.toString() ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppText.body,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'ต้องการเรียน $demand • ผู้สอน $supply',
                      style: const TextStyle(
                        fontSize: AppText.caption,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  gap > 0 ? 'ขาดผู้สอน $gap' : 'ผู้สอนเพียงพอ',
                  style: TextStyle(
                    fontSize: AppText.caption,
                    fontWeight: FontWeight.w600,
                    color: c,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _dateFilterBar() {
    final label = _dateRange == null
        ? 'ทั้งหมด (ทุกวัน)'
        : '${_fmtDate(_dateRange!.start)} ถึง ${_fmtDate(_dateRange!.end)}';
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(label, overflow: TextOverflow.ellipsis),
            style: OutlinedButton.styleFrom(
              foregroundColor: _navy,
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (_dateRange != null) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: _clearDateRange,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'ล้างตัวกรอง',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF1F1F1),
              foregroundColor: _navy,
            ),
          ),
        ],
      ],
    );
  }

  Widget _rankedList(List<Map<String, dynamic>> items, String nameKey) {
    const rankColors = [
      Color(0xFFFFC107),
      Color(0xFFB0BEC5),
      Color(0xFFCD7F32),
    ];
    return Column(
      children: List.generate(items.length, (i) {
        final item = items[i];
        final name = item[nameKey]?.toString() ?? '-';
        final count = (item['cnt'] as num).toInt();
        final rankColor = i < rankColors.length
            ? rankColors[i]
            : Colors.grey[300]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: rankColor,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: AppText.caption,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppText.body,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Text(
                '$count แมตช์',
                style: const TextStyle(
                  fontSize: AppText.body,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _metricGrid(List<_Metric> items) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // ความสูงคงที่ตามขนาดตัวอักษร (ไม่ใช้อัตราส่วน เพราะจอแคบ/ตัวอักษรใหญ่จะล้น)
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent:
            144 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
      ),
      children: items.map((m) => _metricCard(m)).toList(),
    );
  }

  Widget _metricCard(_Metric m) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(m.icon, color: m.color, size: 26),
          const SizedBox(height: 10),
          Text(
            m.value,
            style: TextStyle(
              fontSize: AppText.title,
              fontWeight: FontWeight.bold,
              color: m.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            m.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: AppText.caption,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    String? scope, // ขอบเขตข้อมูล: "ข้อมูลปัจจุบัน" หรือ "ตามช่วงวันที่"
    String? why, // ทำไมแอดมินต้องดูส่วนนี้ (แสดงตลอด)
    String? guide, // วิธีอ่านผลและควรทำอะไรต่อ (กดไอคอน ⓘ เพื่อกาง)
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _navy, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppText.heading,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (scope != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F1F1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    scope,
                    style: const TextStyle(
                      fontSize: AppText.caption,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (why != null) _WhyBlock(why: why, guide: guide),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _matchStatusChart(int pending, int confirmed, int rejected) {
    final total = pending + confirmed + rejected;
    if (total == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'ยังไม่มีข้อมูลการจับคู่',
            style: TextStyle(color: Colors.grey, fontSize: AppText.body),
          ),
        ),
      );
    }
    const confirmedColor = Color(0xFF4CAF50);
    const pendingColor = Color(0xFFF59E0B);
    const rejectedColor = Color(0xFFE24B4A);

    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _DonutChartPainter(
              values: [confirmed, pending, rejected],
              colors: const [confirmedColor, pendingColor, rejectedColor],
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legendRow('ยืนยันแล้ว', confirmed, confirmedColor),
              const SizedBox(height: 10),
              _legendRow('รอยืนยัน', pending, pendingColor),
              const SizedBox(height: 10),
              _legendRow('ปฏิเสธแล้ว', rejected, rejectedColor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendRow(String label, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: AppText.body,
              color: AppColors.textDark,
            ),
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontSize: AppText.body,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// บรรทัด "ทำไมต้องดู" (แสดงตลอด) + ปุ่ม ⓘ กางคำแนะนำ "อ่านผลอย่างไร / ควรทำอะไรต่อ"
class _WhyBlock extends StatefulWidget {
  final String why;
  final String? guide;
  const _WhyBlock({required this.why, this.guide});

  @override
  State<_WhyBlock> createState() => _WhyBlockState();
}

class _WhyBlockState extends State<_WhyBlock> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'ทำไมต้องดู: ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: widget.why),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: AppText.caption,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
            ),
            if (widget.guide != null)
              IconButton(
                tooltip: 'วิธีอ่านผลและสิ่งที่ควรทำ',
                onPressed: () => setState(() => _open = !_open),
                icon: Icon(
                  _open ? Icons.expand_less : Icons.info_outline,
                  size: 20,
                  color: _open ? AppColors.primary : Colors.grey,
                ),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        if (_open && widget.guide != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'อ่านผลอย่างไร / ควรทำอะไรต่อ',
                  style: TextStyle(
                    fontSize: AppText.caption,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.guide!,
                  style: const TextStyle(
                    fontSize: AppText.caption,
                    color: Color(0xFF555555),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Metric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _Metric(this.label, this.value, this.icon, this.color);
}

/// วาดกราฟโดนัทแบบเรียบง่าย ไม่พึ่งพา package ภายนอก
class _DonutChartPainter extends CustomPainter {
  final List<int> values;
  final List<Color> colors;
  _DonutChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const strokeWidth = 22.0;
    double startAngle = -math.pi / 2;

    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = (values[i] / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}
