import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'Learn.dart' as learn;
import 'app_theme.dart';
import 'api_config.dart';

T learnByIndex<T>(List<T> values, dynamic raw) {
  final idx = int.tryParse(raw?.toString() ?? '') ?? 0;
  if (idx < 0 || idx >= values.length) return values.first;
  return values[idx];
}

Widget learnSubHeader(String title) {
  return Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 6),
    child: Text(
      title,
      style: TextStyle(
        fontSize: AppText.caption,
        fontWeight: FontWeight.bold,
        color: _learnPrimary,
      ),
    ),
  );
}

Widget learnDetailRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _learnPrimary),
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

const Color _learnPrimary = AppColors.studentAccent;

/// แถวรายละเอียดของความต้องการ 1 รายการ (ใช้ร่วมกันทั้งหน้าประวัติและป๊อปอัป "ความต้องการของฉัน" ในหน้าจับคู่)
List<Widget> learnDetailRows(Map<String, dynamic> item) {
  final subject = item['subject_learn']?.toString();
  final title = (subject == null || subject.isEmpty) ? 'ไม่ระบุวิชา' : subject;
  return [
    learnSubHeader('เนื้อหาที่ต้องการ'),
    learnDetailRow(Icons.subject, 'วิชา/ความต้องการเรียน', title),
    learnDetailRow(
      Icons.signal_cellular_alt,
      'ระดับเนื้อหา',
      learn.teachableLevelLabel(
        learnByIndex(learn.TeachableLevel.values, item['content_level']),
      ),
    ),
    learnDetailRow(
      Icons.flag_outlined,
      'วัตถุประสงค์',
      learn.objectiveLabel(
        learnByIndex(learn.Objective.values, item['objective_learn']),
      ),
    ),
    learnSubHeader('เวลา-สถานที่'),
    learnDetailRow(
      Icons.access_time_outlined,
      'ช่วงเวลาที่ต้องการเรียน',
      learn.preferredTimeLabel(
        learnByIndex(learn.PreferredTime.values, item['preferred_time_learn']),
      ),
    ),
    learnDetailRow(
      Icons.hourglass_bottom_outlined,
      'ระยะเวลาต่อคาบ',
      learn.durationLabel(
        learnByIndex(learn.Duration.values, item['duration_learn']),
      ),
    ),
    learnDetailRow(
      Icons.laptop_mac_outlined,
      'รูปแบบการเรียน',
      learn.learningFormatLabel(
        learnByIndex(
          learn.LearningFormat.values,
          item['learning_format_learn'],
        ),
      ),
    ),
    learnDetailRow(
      Icons.location_on_outlined,
      'ระยะทางที่ยอมรับได้',
      learn.teachableDistanceLabel(
        learnByIndex(
          learn.TeachableDistance.values,
          item['teachable_distance_learn'],
        ),
      ),
    ),
    learnDetailRow(
      Icons.attach_money_outlined,
      'งบประมาณต่อชั่วโมง',
      learn.priceRangeLabel(
        learnByIndex(learn.PriceRange.values, item['budget_per_hour']),
      ),
    ),
    learnSubHeader('คุณสมบัติติวเตอร์ที่ต้องการ'),
    learnDetailRow(
      Icons.star_outline,
      'ประสบการณ์ที่ต้องการ',
      learn.experienceLevelLabel(
        learnByIndex(
          learn.ExperienceLevel.values,
          item['required_experience_learn'],
        ),
      ),
    ),
    learnDetailRow(
      Icons.school_outlined,
      'วุฒิการศึกษาที่ต้องการ',
      learn.educationQualificationLabel(
        learnByIndex(
          learn.EducationQualification.values,
          item['preferred_teaching_method_learn'],
        ),
      ),
    ),
    learnDetailRow(
      Icons.workspace_premium_outlined,
      'ระดับความรู้ที่ชอบสอน',
      learn.teachableLevelLabel(
        learnByIndex(
          learn.TeachableLevel.values,
          item['tutor_knowledge_level_learn'],
        ),
      ),
    ),
    learnSubHeader('รูปแบบการเรียน'),
    learnDetailRow(
      Icons.group_outlined,
      'จำนวนผู้เรียนต่อคาบ',
      learn.groupSizeLabel(
        learnByIndex(learn.GroupSize.values, item['group_size_learn']),
      ),
    ),
    learnDetailRow(
      Icons.style_outlined,
      'สไตล์การสอน',
      learn.teachingStyleLabel(
        learnByIndex(learn.TeachingStyle.values, item['teaching_style_learn']),
      ),
    ),
    learnDetailRow(
      Icons.auto_stories_outlined,
      'วิธีการสอน',
      learn.teachingMethodLabel(
        learnByIndex(
          learn.TeachingMethod.values,
          item['teaching_method_learn'],
        ),
      ),
    ),
    learnDetailRow(
      Icons.translate_outlined,
      'ภาษาที่ใช้สอน',
      learn.teachingLanguageLabel(
        learnByIndex(
          learn.TeachingLanguage.values,
          item['teaching_language_learn'],
        ),
      ),
    ),
    learnDetailRow(
      Icons.wc_outlined,
      'เพศที่ต้องการ',
      learn.preferredGenderLabel(
        learnByIndex(
          learn.PreferredGender.values,
          item['preferred_gender_learn'],
        ),
      ),
    ),
  ];
}

/* ================= หน้าแสดงประวัติความต้องการเรียน ================= */
class LearnHistoryPage extends StatefulWidget {
  final String studentId;
  const LearnHistoryPage({super.key, required this.studentId});

  @override
  State<LearnHistoryPage> createState() => _LearnHistoryPageState();
}

class _LearnHistoryPageState extends State<LearnHistoryPage> {
  static const Color primaryColor = AppColors.studentAccent;

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
        "$kApiBase/api_get_learn_history.php"
        "?student_id=${widget.studentId}",
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
    final subject = item['subject_learn']?.toString();
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
            child: const Icon(Icons.menu_book_outlined, color: primaryColor),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Text(
            'รหัสรายการ: ${item['learn_reg_id'] ?? '-'}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
          ),
          children: [
            ...learnDetailRows(item),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => learn.AddLearnPage(
                        studentId: widget.studentId,
                        initialData: item,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.content_copy, size: 18),
                label: const Text('ใช้ข้อมูลนี้เพิ่มความต้องการเรียนใหม่'),
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
              'ยังไม่มีประวัติการกรอกข้อมูลความต้องการเรียน',
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
          'ประวัติความต้องการเรียน',
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
