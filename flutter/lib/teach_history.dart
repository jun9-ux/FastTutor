import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'teach.dart' as teach;
import 'app_theme.dart';
import 'api_config.dart';

T teachByIndex<T>(List<T> values, dynamic raw) {
  final idx = int.tryParse(raw?.toString() ?? '') ?? 0;
  if (idx < 0 || idx >= values.length) return values.first;
  return values[idx];
}

Widget teachSubHeader(String title) {
  return Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: Text(
      title,
      style: TextStyle(
        fontSize: AppText.caption,
        fontWeight: FontWeight.bold,
        color: _teachPrimary,
      ),
    ),
  );
}

Widget teachDetailRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _teachPrimary),
        const SizedBox(width: 8),
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
        ),
      ],
    ),
  );
}

const Color _teachPrimary = AppColors.tutorAccent;

/// แถวรายละเอียดของความต้องการ 1 รายการ (ใช้ร่วมกันทั้งหน้าประวัติและป๊อปอัป "ความต้องการของฉัน" ในหน้าจับคู่)
List<Widget> teachDetailRows(Map<String, dynamic> item) {
  final subject = item['subject_teach']?.toString();
  final title = (subject == null || subject.isEmpty) ? 'ไม่ระบุวิชา' : subject;
  return [
    teachSubHeader('เนื้อหาที่ต้องการสอน'),
    teachDetailRow(Icons.subject, 'วิชา/ความต้องการสอน', title),
    teachDetailRow(
      Icons.signal_cellular_alt,
      'ระดับที่ต้องการสอน',
      teach.teachableLevelLabel(
        teachByIndex(teach.TeachableLevel.values, item['teach_level']),
      ),
    ),
    teachSubHeader('รูปแบบการสอน'),
    teachDetailRow(
      Icons.workspace_premium_outlined,
      'ระดับความรู้ที่ชอบสอน',
      teach.teachableLevelLabel(
        teachByIndex(
          teach.TeachableLevel.values,
          item['tutor_knowledge_level_teach'],
        ),
      ),
    ),
    teachDetailRow(
      Icons.laptop_mac_outlined,
      'รูปแบบการเรียน',
      teach.learningFormatLabel(
        teachByIndex(
          teach.LearningFormat.values,
          item['learning_format_teach'],
        ),
      ),
    ),
    teachDetailRow(
      Icons.auto_stories_outlined,
      'วิธีการสอน',
      teach.teachingMethodLabel(
        teachByIndex(
          teach.TeachingMethod.values,
          item['teaching_method_teach'],
        ),
      ),
    ),
    teachDetailRow(
      Icons.style_outlined,
      'สไตล์การสอน',
      teach.teachingStyleLabel(
        teachByIndex(teach.TeachingStyle.values, item['teaching_style_teach']),
      ),
    ),
    teachDetailRow(
      Icons.translate_outlined,
      'ภาษาที่ใช้สอน',
      teach.teachingLanguageLabel(
        teachByIndex(
          teach.TeachingLanguage.values,
          item['teaching_language_teach'],
        ),
      ),
    ),
    teachDetailRow(
      Icons.group_outlined,
      'จำนวนผู้เรียนต่อคาบ',
      teach.groupSizeLabel(
        teachByIndex(teach.GroupSize.values, item['group_size_teach']),
      ),
    ),
    teachSubHeader('เวลา-สถานที่'),
    teachDetailRow(
      Icons.access_time_outlined,
      'ช่วงเวลาที่ต้องการสอน',
      teach.preferredTimeLabel(
        teachByIndex(teach.PreferredTime.values, item['preferred_time_teach']),
      ),
    ),
    teachDetailRow(
      Icons.hourglass_bottom_outlined,
      'ระยะเวลาต่อคาบ',
      teach.durationLabel(
        teachByIndex(teach.Duration.values, item['duration_teach']),
      ),
    ),
    teachDetailRow(
      Icons.location_on_outlined,
      'ระยะทางที่ยอมรับได้',
      teach.teachableDistanceLabel(
        teachByIndex(
          teach.TeachableDistance.values,
          item['teachable_distance_teach'],
        ),
      ),
    ),
    teachDetailRow(
      Icons.attach_money_outlined,
      'อัตราค่าสอนต่อชั่วโมง',
      teach.priceRangeLabel(
        teachByIndex(teach.PriceRange.values, item['teaching_rate_per_hour']),
      ),
    ),
    teachSubHeader('คุณสมบัตินักเรียนที่ต้องการ'),
    teachDetailRow(
      Icons.star_outline,
      'ประสบการณ์ที่ต้องการ',
      teach.experienceLevelLabel(
        teachByIndex(
          teach.ExperienceLevel.values,
          item['required_experience_teach'],
        ),
      ),
    ),
    teachDetailRow(
      Icons.school_outlined,
      'วุฒิการศึกษาที่ต้องการ',
      teach.educationQualificationLabel(
        teachByIndex(
          teach.EducationQualification.values,
          item['preferred_teaching_method_teach'],
        ),
      ),
    ),
    teachDetailRow(
      Icons.flag_outlined,
      'วัตถุประสงค์',
      teach.objectiveLabel(
        teachByIndex(teach.Objective.values, item['objective_teach']),
      ),
    ),
    teachDetailRow(
      Icons.wc_outlined,
      'เพศที่ต้องการ',
      teach.preferredGenderLabel(
        teachByIndex(
          teach.PreferredGender.values,
          item['preferred_gender_teach'],
        ),
      ),
    ),
  ];
}

/* ================= หน้าแสดงประวัติความต้องการสอน ================= */
class TeachHistoryPage extends StatefulWidget {
  final String tutorId;
  const TeachHistoryPage({super.key, required this.tutorId});

  @override
  State<TeachHistoryPage> createState() => _TeachHistoryPageState();
}

class _TeachHistoryPageState extends State<TeachHistoryPage> {
  static const Color primaryColor = AppColors.tutorAccent;

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(
        "$kApiBase/api_get_teach_history.php"
        "?tutor_id=${widget.tutorId}",
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);

      if (data['result'] == 1) {
        final list = (data['datalist'] as List?) ?? [];
        setState(() {
          _items = list
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'ไม่สามารถโหลดข้อมูลได้';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ กรุณาลองใหม่';
        _isLoading = false;
      });
    }
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final subject = item['subject_teach']?.toString();
    final title = (subject == null || subject.isEmpty)
        ? 'ไม่ระบุวิชา'
        : subject;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: CircleAvatar(
            backgroundColor: primaryColor.withOpacity(0.12),
            child: const Icon(
              Icons.cast_for_education_outlined,
              color: primaryColor,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Text(
            'รหัสรายการ: ${item['teach_req_id'] ?? '-'}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
          ),
          children: [
            ...teachDetailRows(item),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => teach.AddTeachPage(
                        tutorId: widget.tutorId,
                        initialData: item,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.content_copy, size: 18),
                label: const Text('ใช้ข้อมูลนี้เพิ่มความต้องการสอนใหม่'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: const BorderSide(color: primaryColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text(
              'ยังไม่มีประวัติการกรอกข้อมูลความต้องการสอน',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF999999), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ประวัติความต้องการสอน',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchHistory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                      ),
                      child: const Text(
                        'ลองใหม่',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _items.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _fetchHistory,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _items.length,
                itemBuilder: (_, i) => _buildCard(_items[i]),
              ),
            ),
    );
  }
}
