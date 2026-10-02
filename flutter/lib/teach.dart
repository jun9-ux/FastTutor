import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_nav_bar.dart';
import 'match.dart';
import 'EditProfilePage.dart';
import 'teach_history.dart';
import 'chat_list_page.dart';
import 'app_session.dart';
import 'app_theme.dart';
import 'api_config.dart';

/* ================= ENUM ================= */
enum TeachableLevel { beginner, intermediate, advanced, any }

enum Objective { exam, career, hobby, other }

enum PreferredTime { morning, afternoon, evening, weekend }

enum Duration { oneHour, onePointFiveHour, twoHour }

enum LearningFormat { online, offline, hybrid }

enum TeachableDistance { near13km, mid47km, far10kmUp }

enum PriceRange { low200to500, mid600to1000, high1000up }

enum ExperienceLevel { newbie, oneToThreeYears, moreThanThreeYears }

enum EducationQualification { bachelor, master, doctorate, notRequired }

enum GroupSize { oneOnOne, smallGroup }

enum TeachingStyle { strict, relaxed, interactive }

enum TeachingMethod { lecture, practice, caseStudy }

enum TeachingLanguage { thai, english, both }

enum PreferredGender { male, female, other }

/* ================= แปลข้อความ enum เป็นภาษาไทย ================= */
String teachableLevelLabel(TeachableLevel v) {
  const m = {
    TeachableLevel.beginner: 'เริ่มต้น',
    TeachableLevel.intermediate: 'กลาง',
    TeachableLevel.advanced: 'สูง',
    TeachableLevel.any: 'ทุกระดับ',
  };
  return m[v] ?? '-';
}

String objectiveLabel(Objective v) {
  const m = {
    Objective.exam: 'สอบเข้ามหาวิทยาลัย',
    Objective.career: 'ทักษะงาน',
    Objective.hobby: 'งานอดิเรก',
    Objective.other: 'อื่นๆ',
  };
  return m[v] ?? '-';
}

String preferredTimeLabel(PreferredTime v) {
  const m = {
    PreferredTime.morning: 'เช้า',
    PreferredTime.afternoon: 'บ่าย',
    PreferredTime.evening: 'เย็น',
    PreferredTime.weekend: 'วันหยุดสุดสัปดาห์',
  };
  return m[v] ?? '-';
}

String durationLabel(Duration v) {
  const m = {
    Duration.oneHour: '1 ชั่วโมง',
    Duration.onePointFiveHour: '1.5 ชั่วโมง',
    Duration.twoHour: '2 ชั่วโมง',
  };
  return m[v] ?? '-';
}

String learningFormatLabel(LearningFormat v) {
  const m = {
    LearningFormat.online: 'ออนไลน์',
    LearningFormat.offline: 'ออฟไลน์',
    LearningFormat.hybrid: 'ผสมผสาน',
  };
  return m[v] ?? '-';
}

String teachableDistanceLabel(TeachableDistance v) {
  const m = {
    TeachableDistance.near13km: 'รัศมี 1-3 กม.',
    TeachableDistance.mid47km: 'รัศมี 4-7 กม.',
    TeachableDistance.far10kmUp: 'รัศมี 10 กม.ขึ้นไป',
  };
  return m[v] ?? '-';
}

String priceRangeLabel(PriceRange v) {
  const m = {
    PriceRange.low200to500: '200-500 บาท/ชม.',
    PriceRange.mid600to1000: '600-1,000 บาท/ชม.',
    PriceRange.high1000up: '1,000 บาท/ชม.ขึ้นไป',
  };
  return m[v] ?? '-';
}

String experienceLevelLabel(ExperienceLevel v) {
  const m = {
    ExperienceLevel.newbie: 'มือใหม่',
    ExperienceLevel.oneToThreeYears: 'มีประสบการณ์ 1-3 ปี',
    ExperienceLevel.moreThanThreeYears: 'มากกว่า 3 ปี',
  };
  return m[v] ?? '-';
}

String educationQualificationLabel(EducationQualification v) {
  const m = {
    EducationQualification.bachelor: 'ปริญญาตรี',
    EducationQualification.master: 'ปริญญาโท',
    EducationQualification.doctorate: 'ปริญญาเอก',
    EducationQualification.notRequired: 'ไม่จำเป็น',
  };
  return m[v] ?? '-';
}

String groupSizeLabel(GroupSize v) {
  const m = {
    GroupSize.oneOnOne: 'สอนตัวต่อตัว',
    GroupSize.smallGroup: 'กลุ่มเล็ก',
  };
  return m[v] ?? '-';
}

String teachingStyleLabel(TeachingStyle v) {
  const m = {
    TeachingStyle.strict: 'เข้มงวด',
    TeachingStyle.relaxed: 'ผ่อนคลาย',
    TeachingStyle.interactive: 'มีปฏิสัมพันธ์',
  };
  return m[v] ?? '-';
}

String teachingMethodLabel(TeachingMethod v) {
  const m = {
    TeachingMethod.lecture: 'บรรยาย',
    TeachingMethod.practice: 'ฝึกปฏิบัติ',
    TeachingMethod.caseStudy: 'กรณีศึกษา',
  };
  return m[v] ?? '-';
}

String teachingLanguageLabel(TeachingLanguage v) {
  const m = {
    TeachingLanguage.thai: 'ไทย',
    TeachingLanguage.english: 'อังกฤษ',
    TeachingLanguage.both: 'ทั้งสอง',
  };
  return m[v] ?? '-';
}

String preferredGenderLabel(PreferredGender v) {
  const m = {
    PreferredGender.male: 'ชาย',
    PreferredGender.female: 'หญิง',
    PreferredGender.other: 'อื่นๆ',
  };
  return m[v] ?? '-';
}

/* ================= PAGE ================= */
class AddTeachPage extends StatefulWidget {
  final String tutorId;
  final Map<String, dynamic>? userData; // optional สำหรับ nav bar
  final Map<String, dynamic>?
  initialData; // optional ข้อมูลเดิมจากประวัติ สำหรับ prefill ฟอร์ม
  const AddTeachPage({
    super.key,
    required this.tutorId,
    this.userData,
    this.initialData,
  });

  @override
  State<AddTeachPage> createState() => _AddTeachPageState();
}

class _AddTeachPageState extends State<AddTeachPage> {
  final subjectController = TextEditingController();
  final int _currentIndex = 1; // เพิ่มความต้องการ

  TeachableLevel level = TeachableLevel.beginner;
  Objective objective = Objective.exam;
  PreferredTime time = PreferredTime.morning;
  Duration duration = Duration.oneHour;
  LearningFormat format = LearningFormat.online;
  TeachableDistance distance = TeachableDistance.near13km;
  PriceRange price = PriceRange.low200to500;
  ExperienceLevel experience = ExperienceLevel.newbie;
  EducationQualification edu = EducationQualification.notRequired;
  TeachableLevel tutorLevel = TeachableLevel.beginner;
  GroupSize group = GroupSize.oneOnOne;
  TeachingStyle style = TeachingStyle.relaxed;
  TeachingMethod method = TeachingMethod.practice;
  TeachingLanguage language = TeachingLanguage.thai;
  PreferredGender gender = PreferredGender.other;

  T _byIndex<T>(List<T> values, dynamic raw) {
    final idx = int.tryParse(raw?.toString() ?? '') ?? 0;
    if (idx < 0 || idx >= values.length) return values.first;
    return values[idx];
  }

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    if (data != null) {
      subjectController.text = data['subject_teach']?.toString() ?? '';
      level = _byIndex(TeachableLevel.values, data['teach_level']);
      objective = _byIndex(Objective.values, data['objective_teach']);
      time = _byIndex(PreferredTime.values, data['preferred_time_teach']);
      duration = _byIndex(Duration.values, data['duration_teach']);
      format = _byIndex(LearningFormat.values, data['learning_format_teach']);
      distance = _byIndex(
        TeachableDistance.values,
        data['teachable_distance_teach'],
      );
      price = _byIndex(PriceRange.values, data['teaching_rate_per_hour']);
      experience = _byIndex(
        ExperienceLevel.values,
        data['required_experience_teach'],
      );
      edu = _byIndex(
        EducationQualification.values,
        data['preferred_teaching_method_teach'],
      );
      tutorLevel = _byIndex(
        TeachableLevel.values,
        data['tutor_knowledge_level_teach'],
      );
      group = _byIndex(GroupSize.values, data['group_size_teach']);
      style = _byIndex(TeachingStyle.values, data['teaching_style_teach']);
      method = _byIndex(TeachingMethod.values, data['teaching_method_teach']);
      language = _byIndex(
        TeachingLanguage.values,
        data['teaching_language_teach'],
      );
      gender = _byIndex(PreferredGender.values, data['preferred_gender_teach']);
    }
  }

  bool _isSaving = false;

  Future<void> saveTeach() async {
    if (_isSaving) return;
    if (subjectController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("กรุณากรอกชื่อวิชา")));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final response = await http.post(
        Uri.parse("$kApiBase/api_add_teach.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "subject_teach": subjectController.text,
          "teach_level": level.index,
          "objective_teach": objective.index,
          "preferred_time_teach": time.index,
          "duration_teach": duration.index,
          "learning_format_teach": format.index,
          "teachable_distance_teach": distance.index,
          "teaching_rate_per_hour": price.index,
          "required_experience_teach": experience.index,
          "preferred_teaching_method_teach": edu.index,
          "tutor_knowledge_level_teach": tutorLevel.index,
          "group_size_teach": group.index,
          "teaching_style_teach": style.index,
          "teaching_method_teach": method.index,
          "teaching_language_teach": language.index,
          "preferred_gender_teach": gender.index,
          "tutor_id": widget.tutorId,
        }),
      );
      final result = jsonDecode(response.body);
      if (result["result"] == 1) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("บันทึกข้อมูลสำเร็จ")));
        _goToMatch(); // บันทึกสำเร็จแล้วไปหน้าจับคู่ทันที
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result["message"])));
      }
    } catch (_) {
      // เซิร์ฟเวอร์ล่ม/ตอบผิดรูปแบบ: แจ้งผู้ใช้ ไม่ปล่อย exception หลุด
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ กรุณาลองใหม่"),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    subjectController.dispose();
    super.dispose();
  }

  // ไปหน้าจับคู่ (ใช้ทั้งจากแท็บ "จับคู่" และหลังบันทึกความต้องการสำเร็จ)
  void _goToMatch() {
    final userData = widget.userData ?? AppSession.userData;
    final fullName =
        '${userData['first_name_tutor'] ?? ''} ${userData['last_name_tutor'] ?? ''}';
    goToTab(
      context,
      MatchPage(role: 'tutor', userId: widget.tutorId, userName: fullName),
    );
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    final userData = widget.userData ?? AppSession.userData;
    switch (index) {
      case 0:
        goToDashboard(context);
        break;
      case 1:
        break;
      case 2:
        _goToMatch();
        break;
      case 4:
        goToTab(
          context,
          EditProfilePage(role: 'tutor', userData: userData, onUpdated: (_) {}),
        );
        break;
      case 3:
        goToTab(context, ChatListPage(role: 'tutor', userId: widget.tutorId));
        break;
    }
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    const Color primaryColor = AppColors.tutorAccent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF444444),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: primaryColor, size: 20),
              hintText: label,
              hintStyle: const TextStyle(
                color: Color(0xFFBDBDBD),
                fontSize: 16,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
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
                borderSide: const BorderSide(color: primaryColor, width: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>(
    String label,
    IconData icon,
    T value,
    List<T> values,
    Function(T?) onChanged, {
    String Function(T)? displayText,
  }) {
    const Color primaryColor = AppColors.tutorAccent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF444444),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<T>(
            value: value,
            isExpanded: true,
            items: values
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(
                      displayText != null
                          ? displayText(e)
                          : e.toString().split('.').last,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: primaryColor, size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
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
                borderSide: const BorderSide(color: primaryColor, width: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    const Color primaryColor = AppColors.tutorAccent;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF444444),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = AppColors.tutorAccent;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'เพิ่มความต้องการสอน',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.history, color: primaryColor, size: 22),
            label: const Text(
              'ประวัติ',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeachHistoryPage(tutorId: widget.tutorId),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        role: 'tutor',
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('วิชาที่สอน', Icons.menu_book_outlined),
            _buildTextField(
              subjectController,
              'วิชาที่สอน',
              Icons.menu_book_outlined,
            ),
            _buildDropdown(
              'ระดับที่ต้องการสอน',
              Icons.signal_cellular_alt,
              level,
              TeachableLevel.values,
              (v) => setState(() => level = v!),
              displayText: teachableLevelLabel,
            ),
            _buildDropdown(
              'ระดับความรู้ที่ชอบสอน',
              Icons.workspace_premium_outlined,
              tutorLevel,
              TeachableLevel.values,
              (v) => setState(() => tutorLevel = v!),
              displayText: teachableLevelLabel,
            ),

            _sectionHeader('รูปแบบการสอน', Icons.cast_for_education_outlined),
            _buildDropdown(
              'รูปแบบการเรียน',
              Icons.laptop_mac_outlined,
              format,
              LearningFormat.values,
              (v) => setState(() => format = v!),
              displayText: learningFormatLabel,
            ),
            _buildDropdown(
              'วิธีการสอน',
              Icons.auto_stories_outlined,
              method,
              TeachingMethod.values,
              (v) => setState(() => method = v!),
              displayText: teachingMethodLabel,
            ),
            _buildDropdown(
              'สไตล์การสอน',
              Icons.style_outlined,
              style,
              TeachingStyle.values,
              (v) => setState(() => style = v!),
              displayText: teachingStyleLabel,
            ),
            _buildDropdown(
              'ภาษาที่ใช้สอน',
              Icons.translate_outlined,
              language,
              TeachingLanguage.values,
              (v) => setState(() => language = v!),
              displayText: teachingLanguageLabel,
            ),
            _buildDropdown(
              'จำนวนผู้เรียนต่อคาบ',
              Icons.group_outlined,
              group,
              GroupSize.values,
              (v) => setState(() => group = v!),
              displayText: groupSizeLabel,
            ),

            _sectionHeader('เวลาและสถานที่', Icons.schedule_outlined),
            _buildDropdown(
              'ช่วงเวลาที่ต้องการสอน',
              Icons.access_time_outlined,
              time,
              PreferredTime.values,
              (v) => setState(() => time = v!),
              displayText: preferredTimeLabel,
            ),
            _buildDropdown(
              'ระยะเวลาต่อคาบ',
              Icons.hourglass_bottom_outlined,
              duration,
              Duration.values,
              (v) => setState(() => duration = v!),
              displayText: durationLabel,
            ),
            _buildDropdown(
              'ระยะทางที่ยอมรับได้',
              Icons.location_on_outlined,
              distance,
              TeachableDistance.values,
              (v) => setState(() => distance = v!),
              displayText: teachableDistanceLabel,
            ),

            _sectionHeader('ราคาและคุณสมบัติ', Icons.monetization_on_outlined),
            _buildDropdown(
              'อัตราค่าสอนต่อชั่วโมง',
              Icons.attach_money_outlined,
              price,
              PriceRange.values,
              (v) => setState(() => price = v!),
              displayText: priceRangeLabel,
            ),
            _buildDropdown(
              'ประสบการณ์ที่ต้องการ',
              Icons.star_outline,
              experience,
              ExperienceLevel.values,
              (v) => setState(() => experience = v!),
              displayText: experienceLevelLabel,
            ),
            _buildDropdown(
              'วุฒิการศึกษาที่ต้องการ',
              Icons.school_outlined,
              edu,
              EducationQualification.values,
              (v) => setState(() => edu = v!),
              displayText: educationQualificationLabel,
            ),

            _sectionHeader('ความต้องการพิเศษ', Icons.tune_outlined),
            _buildDropdown(
              'วัตถุประสงค์',
              Icons.flag_outlined,
              objective,
              Objective.values,
              (v) => setState(() => objective = v!),
              displayText: objectiveLabel,
            ),
            _buildDropdown(
              'เพศที่ต้องการ',
              Icons.wc_outlined,
              gender,
              PreferredGender.values,
              (v) => setState(() => gender = v!),
              displayText: preferredGenderLabel,
            ),

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : saveTeach,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'บันทึกความต้องการสอน',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
