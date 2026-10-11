import 'dart:convert';
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

          // 1) จำนวนผู้ใช้งาน (ค่าปัจจุบัน)
          _sectionCard(
            title: 'จำนวนผู้ใช้งาน',
            icon: Icons.groups_outlined,
            scope: 'ข้อมูล ณ ตอนนี้',
            why: 'แสดงจำนวนสมาชิกแต่ละประเภทที่อยู่ในระบบตอนนี้',
            guide:
                'ตัวเลขนี้เป็นจำนวนบัญชีทั้งหมดในระบบ จึงไม่เปลี่ยนตามช่วงวันที่ที่เลือก\n'
                'หากผู้เรียนเพิ่มเร็วกว่าผู้สอน ควรดูส่วน “วิชาที่ขาดผู้สอน” ประกอบ',
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
            ]),
          ),
          const SizedBox(height: 16),

          // 2) วิชาที่ขาดผู้สอน (ค่าปัจจุบัน)
          _sectionCard(
            title: 'วิชาที่ขาดผู้สอน',
            icon: Icons.person_search_outlined,
            scope: 'ข้อมูล ณ ตอนนี้',
            why: 'แสดงวิชาที่มีผู้เรียนรอมากกว่าจำนวนผู้สอนที่พร้อมรับ',
            guide:
                'จำนวนผู้สอนที่ยังขาด = ผู้เรียนที่กำลังหา − ผู้สอนที่พร้อมรับในวิชาเดียวกัน\n'
                'วิชาที่ขาดมากควรได้รับการประชาสัมพันธ์หรือรับสมัครผู้สอนเพิ่ม\n'
                'ระบบรวมชื่อวิชาที่ต่างกันเฉพาะตัวพิมพ์เล็ก–ใหญ่และช่องว่างหัวท้าย',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metricGrid([
                  _Metric(
                    'ผู้เรียนที่กำลังหาผู้สอน',
                    '${report['active_learn_count'] ?? 0}',
                    Icons.hourglass_empty_rounded,
                    Colors.deepOrange,
                  ),
                  _Metric(
                    'ผู้สอนที่พร้อมรับผู้เรียน',
                    '${report['active_teach_count'] ?? 0}',
                    Icons.how_to_reg_outlined,
                    Colors.indigo,
                  ),
                ]),
                const SizedBox(height: 16),
                const Text(
                  'จำนวนผู้สอนที่ยังขาดในแต่ละวิชา',
                  style: TextStyle(
                    fontSize: AppText.body,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                subjectGaps.isEmpty
                    ? _emptyText('ตอนนี้ยังไม่มีผู้เรียนที่กำลังหาผู้สอน')
                    : _gapList(subjectGaps),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3) ผลการจับคู่
          _sectionCard(
            title: 'ผลการจับคู่',
            icon: Icons.handshake_outlined,
            scope: 'ช่วงวันที่ที่เลือก',
            why: 'สรุปจำนวนคำขอและผลการตอบรับในช่วงวันที่ที่เลือก',
            guide:
                'อัตราการยืนยันคำขอ = ยืนยันแล้ว ÷ (ยืนยันแล้ว + ปฏิเสธ)\n'
                'คำขอที่รอการตอบรับยังไม่ถูกนำมาคำนวณ เพราะยังไม่มีผลตัดสิน\n'
                'หากมีคำขอรอจำนวนมาก ควรแจ้งเตือนให้ผู้ใช้ตอบรับหรือปฏิเสธ',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metricGrid([
                  _Metric(
                    'คำขอทั้งหมด',
                    '${report['total_matches'] ?? 0}',
                    Icons.swap_horiz_rounded,
                    Colors.blueGrey,
                  ),
                  _Metric(
                    'ยืนยันจับคู่แล้ว',
                    '${report['confirmed_matches'] ?? confirmed}',
                    Icons.handshake_outlined,
                    Colors.green,
                  ),
                  _Metric(
                    'รอการตอบรับ',
                    '$pending',
                    Icons.schedule_outlined,
                    Colors.orange,
                  ),
                  _Metric(
                    'ปฏิเสธ',
                    '$rejected',
                    Icons.close_rounded,
                    Colors.red,
                  ),
                ]),
                const SizedBox(height: 12),
                _rateSummary(successRate),
                if (successRate == null)
                  _note(
                    'ยังไม่มีคำขอที่ได้รับการยืนยันหรือปฏิเสธ จึงยังคำนวณอัตราการยืนยันไม่ได้',
                  ),
                const SizedBox(height: 16),
                _matchStatusChart(pending, confirmed, rejected),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4) วิชาที่มีการจับคู่มากที่สุด
          _sectionCard(
            title: 'วิชาที่มีการจับคู่มากที่สุด',
            icon: Icons.bar_chart_outlined,
            scope: 'ช่วงวันที่ที่เลือก',
            why: 'จัดอันดับวิชาจากจำนวนการจับคู่ที่ได้รับการยืนยันแล้ว',
            guide:
                'ใช้ดูว่าวิชาใดเกิดการจับคู่จริงมากที่สุด\n'
                'สามารถเปลี่ยนช่วงวันที่เพื่อเปรียบเทียบความต้องการในแต่ละช่วง เช่น ก่อนสอบ',
            child: topSubjects.isEmpty
                ? _emptyText('ยังไม่มีการจับคู่ที่ได้รับการยืนยันในช่วงนี้')
                : _rankedList(topSubjects, 'subject'),
          ),
          const SizedBox(height: 16),

          // 5) การติดต่อหลังจับคู่
          _sectionCard(
            title: 'การติดต่อหลังจับคู่',
            icon: Icons.forum_outlined,
            scope: 'ช่วงวันที่ที่เลือก',
            why: 'ตรวจว่าคู่ที่ยืนยันแล้วเริ่มพูดคุยเพื่อนัดหมายกันหรือยัง',
            guide:
                'นับจากคู่ที่ยืนยันการจับคู่ในช่วงวันที่ที่เลือก\n'
                'หากคู่ที่ยังไม่เริ่มสนทนามีจำนวนมาก ควรเพิ่มข้อความแนะนำหรือแจ้งเตือนให้เริ่มนัดหมาย',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metricGrid([
                  _Metric(
                    'คู่ที่เริ่มสนทนาแล้ว',
                    '${report['confirmed_with_chat_count'] ?? report['chat_rooms'] ?? 0}',
                    Icons.meeting_room_outlined,
                    Colors.indigo,
                  ),
                  _Metric(
                    'คู่ที่ยังไม่เริ่มสนทนา',
                    '${report['chat_rooms_silent'] ?? 0}',
                    Icons.speaker_notes_off_outlined,
                    Colors.deepOrange,
                  ),
                  _Metric(
                    'อัตราคู่ที่เริ่มสนทนา',
                    chatRate != null ? '$chatRate%' : '-',
                    Icons.mark_chat_read_outlined,
                    Colors.green,
                  ),
                ]),
                if (chatRate == null)
                  _note(
                    'ยังไม่มีคู่ที่ยืนยันการจับคู่ในช่วงนี้ จึงยังคำนวณอัตราการเริ่มสนทนาไม่ได้',
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

  /// รายการวิชาที่มีผู้เรียนรอมากกว่าผู้สอนที่พร้อมรับ
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
                      'ผู้เรียน $demand คน • ผู้สอน $supply คน',
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
                  color: c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  gap > 0 ? 'ยังขาด $gap คน' : 'มีผู้สอนเพียงพอ',
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
            color: Colors.black.withValues(alpha: 0.04),
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
    String? why, // คำอธิบายสั้น ๆ ของส่วนนี้ (แสดงตลอด)
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
            color: Colors.black.withValues(alpha: 0.04),
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

  Widget _rateSummary(dynamic successRate) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up_rounded, color: Colors.green),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'อัตราการยืนยันคำขอ',
              style: TextStyle(
                fontSize: AppText.body,
                color: AppColors.textDark,
              ),
            ),
          ),
          Text(
            successRate != null ? '$successRate%' : '-',
            style: const TextStyle(
              fontSize: AppText.title,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'สัดส่วนสถานะคำขอ',
          style: TextStyle(
            fontSize: AppText.body,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                if (confirmed > 0)
                  Expanded(
                    flex: confirmed,
                    child: Container(color: confirmedColor),
                  ),
                if (pending > 0)
                  Expanded(
                    flex: pending,
                    child: Container(color: pendingColor),
                  ),
                if (rejected > 0)
                  Expanded(
                    flex: rejected,
                    child: Container(color: rejectedColor),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _legendRow('ยืนยันจับคู่แล้ว', confirmed, confirmedColor),
        const SizedBox(height: 8),
        _legendRow('รอการตอบรับ', pending, pendingColor),
        const SizedBox(height: 8),
        _legendRow('ปฏิเสธ', rejected, rejectedColor),
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

/// คำอธิบายสั้น ๆ + ปุ่ม ⓘ สำหรับกางรายละเอียดเพิ่มเติม
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
                child: Text(
                  widget.why,
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
                  'วิธีอ่านและสิ่งที่ควรทำ',
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
