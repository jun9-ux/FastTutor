import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_theme.dart';
import 'birth_date_field.dart';
import 'api_config.dart';

class Register extends StatefulWidget {
  const Register({super.key});
  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final fnameCtrl = TextEditingController();
  final lnameCtrl = TextEditingController();
  final genderCtrl = TextEditingController();
  final birthCtrl = TextEditingController();
  DateTime? birthDate; // วันเกิด (อายุคำนวณจากวันเกิดเสมอ จึงเพิ่มเองทุกปี)
  final occupationCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final learningZoneCtrl = TextEditingController();
  final teachingZoneCtrl = TextEditingController();
  final teachingExperienceCtrl = TextEditingController();
  final experienceCtrl = TextEditingController();
  final performanceCtrl = TextEditingController();
  final expertiseCtrl = TextEditingController();

  String gender = "Male";
  String role = "student";
  bool isLoading = false;
  bool _obscurePassword = true;

  // 🔹 ฟิลด์เฉพาะนักเรียน (ตรงกับตาราง student ในฐานข้อมูล)
  // language_used: 1=ไทย, 2=อังกฤษ, 3=จีน, 4=อื่นๆ
  static const Map<int, String> _languageOptions = {
    1: 'ไทย',
    2: 'อังกฤษ',
    3: 'จีน',
    4: 'อื่นๆ',
  };
  // knowledge_level: 1=ประถมศึกษา, 2=มัธยมศึกษา, 3=อุดมศึกษา, 4=สูงกว่า, 5=อื่นๆ
  static const Map<int, String> _knowledgeLevelOptions = {
    1: 'ประถมศึกษา',
    2: 'มัธยมศึกษา',
    3: 'อุดมศึกษา',
    4: 'สูงกว่าอุดมศึกษา',
    5: 'อื่นๆ',
  };
  // course_interest: 1=สอบ, 2=งานอาชีพ, 3=งานอดิเรก, 4=อื่นๆ
  static const Map<int, String> _courseInterestOptions = {
    1: 'เตรียมสอบ',
    2: 'งานอาชีพ',
    3: 'งานอดิเรก',
    4: 'อื่นๆ',
  };

  int? languageUsed;
  int? knowledgeLevel;
  int? courseInterest;

  // 🔹 ฟิลด์เฉพาะติวเตอร์ (ตรงกับตาราง tutor ในฐานข้อมูล)
  // language_teach: 1=ไทย, 2=อังกฤษ, 3=จีน, 4=อื่นๆ
  static const Map<int, String> _languageTeachOptions = {
    1: 'ไทย',
    2: 'อังกฤษ',
    3: 'จีน',
    4: 'อื่นๆ',
  };
  // teachable_level: 1=เริ่มต้น, 2=กลาง, 3=สูง, 4=อื่นๆ
  static const Map<int, String> _teachableLevelOptions = {
    1: 'เริ่มต้น',
    2: 'กลาง',
    3: 'สูง',
    4: 'อื่นๆ',
  };

  int? languageTeach;
  int? teachableLevel;

  static const List<String> _educationLevels = [
    'ประถมศึกษา',
    'มัธยมศึกษาตอนต้น',
    'มัธยมศึกษาตอนปลาย',
    'ปวช.',
    'ปวส.',
    'ปริญญาตรี',
    'ปริญญาโท',
    'ปริญญาเอก',
  ];
  String educationLevel =
      _educationLevels.first; // ใช้กับนักเรียน (ระดับการศึกษา)
  String educationQualification =
      _educationLevels.first; // ใช้กับติวเตอร์ (วุฒิการศึกษา)

  // 🔹 เก็บข้อความ error รายฟิลด์ (สำหรับกรณีข้อมูลซ้ำ)
  String? emailError;
  String? phoneError;
  String? usernameError;

  Future<void> _chooseBirthDate() async {
    final picked = await pickBirthDate(context, initial: birthDate);
    if (picked == null || !mounted) return;
    setState(() {
      birthDate = picked;
      final age = ageFromBirthDate(picked);
      birthCtrl.text =
          '${birthDateToDisplay(picked)}${age == null ? '' : '  (อายุ $age ปี)'}';
    });
  }

  Future<void> register() async {
    // เคลียร์ error เก่าทุกครั้งที่กดสมัครใหม่
    setState(() {
      emailError = null;
      phoneError = null;
      usernameError = null;
    });

    if (fnameCtrl.text.isEmpty ||
        lnameCtrl.text.isEmpty ||
        usernameCtrl.text.isEmpty ||
        passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("กรอกข้อมูลให้ครบ")));
      return;
    }
    if (birthDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("กรุณาเลือกวันเกิด")));
      return;
    }

    setState(() => isLoading = true);

    try {
      var uri = Uri.parse("$kApiBase/register.php");
      var response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "role": role,
          "first_name": fnameCtrl.text,
          "last_name": lnameCtrl.text,
          "gender": gender,
          "birth_date": birthDateToIso(birthDate!),
          "occupation": role == "student" ? occupationCtrl.text : "",
          "education_level": role == "student" ? educationLevel : "",
          "subject_teach": role == "tutor" ? occupationCtrl.text : "",
          "education_qualification": role == "tutor"
              ? educationQualification
              : "",
          "email": emailCtrl.text,
          "phone": phoneCtrl.text,
          "address": addressCtrl.text,
          "username": usernameCtrl.text,
          "password": passwordCtrl.text,
          if (role == "student") "learning_zone": learningZoneCtrl.text,
          if (role == "student") "language_used": languageUsed,
          if (role == "student") "knowledge_level": knowledgeLevel,
          if (role == "student") "course_interest": courseInterest,
          if (role == "tutor") "teaching_zone": teachingZoneCtrl.text,
          if (role == "tutor") "language_teach": languageTeach,
          if (role == "tutor") "teachable_level": teachableLevel,
          if (role == "tutor")
            "teaching_experience": teachingExperienceCtrl.text,
          if (role == "tutor") "experience": experienceCtrl.text,
          if (role == "tutor") "performance": performanceCtrl.text,
          if (role == "tutor") "expertise": expertiseCtrl.text,
        }),
      );

      setState(() => isLoading = false);

      var resp = jsonDecode(response.body);

      if (resp['result'] == 1) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("สมัครสมาชิกสำเร็จ"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        // 🔹 ถ้ามี duplicate_fields ส่งมา ให้ไปโชว์ error ใต้ช่องนั้นๆ
        final List<dynamic> duplicateFields = resp['duplicate_fields'] ?? [];

        setState(() {
          if (duplicateFields.contains("email")) {
            emailError = "อีเมลนี้ถูกใช้งานแล้ว";
          }
          if (duplicateFields.contains("phone")) {
            phoneError = "เบอร์โทรศัพท์นี้ถูกใช้งานแล้ว";
          }
          if (duplicateFields.contains("username")) {
            usernameError = "ชื่อผู้ใช้นี้ถูกใช้งานแล้ว";
          }
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(resp['message'] ?? "เกิดข้อผิดพลาด กรุณาลองใหม่"),
                ),
              ],
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ กรุณาลองใหม่"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? errorText,
    VoidCallback? onChangedClearError,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    const Color primaryColor = AppColors.primary;
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
            obscureText: isPassword ? _obscurePassword : false,
            keyboardType: keyboardType,
            readOnly: readOnly,
            onTap: onTap,
            maxLines: isPassword ? 1 : maxLines,
            onChanged: (_) => onChangedClearError?.call(),
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: errorText != null ? Colors.redAccent : primaryColor,
                size: 20,
              ),
              hintText: label,
              hintStyle: const TextStyle(
                color: Color(0xFFBDBDBD),
                fontSize: 16,
              ),
              errorText: errorText,
              errorStyle: const TextStyle(
                fontSize: 15,
                color: Colors.redAccent,
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
                borderSide: BorderSide(
                  color: errorText != null
                      ? Colors.redAccent
                      : const Color(0xFFDDDDDD),
                  width: 1.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(
                  color: errorText != null ? Colors.redAccent : primaryColor,
                  width: 1.8,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.8,
                ),
              ),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    const Color primaryColor = AppColors.primary;
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
            items: items,
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
    const Color primaryColor = AppColors.primary;
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
    const Color primaryColor = AppColors.primary;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'สมัครสมาชิก',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdown<String>(
              label: 'บทบาท',
              icon: Icons.badge_outlined,
              value: role,
              items: const [
                DropdownMenuItem(value: "student", child: Text("นักเรียน")),
                DropdownMenuItem(value: "tutor", child: Text("ติวเตอร์")),
              ],
              onChanged: (value) => setState(() => role = value!),
            ),
            const SizedBox(height: 8),
            _sectionHeader('ข้อมูลส่วนตัว', Icons.person_outline),
            _buildTextField(fnameCtrl, 'ชื่อ', Icons.person_outline),
            _buildTextField(lnameCtrl, 'นามสกุล', Icons.person_outline),
            _buildDropdown<String>(
              label: 'เพศ',
              icon: Icons.wc_outlined,
              value: gender,
              items: const [
                DropdownMenuItem(value: "Male", child: Text("ชาย")),
                DropdownMenuItem(value: "Female", child: Text("หญิง")),
                DropdownMenuItem(value: "Other", child: Text("อื่นๆ")),
              ],
              onChanged: (value) => setState(() => gender = value!),
            ),
            _buildTextField(
              birthCtrl,
              'วันเกิด',
              Icons.cake_outlined,
              readOnly: true,
              onTap: _chooseBirthDate,
            ),
            if (role == "student")
              _buildTextField(occupationCtrl, 'อาชีพ', Icons.work_outline),
            if (role == "tutor")
              _buildTextField(
                occupationCtrl,
                'วิชาที่สอน',
                Icons.menu_book_outlined,
              ),
            if (role == "student")
              _buildDropdown<String>(
                label: 'ระดับการศึกษา',
                icon: Icons.school_outlined,
                value: educationLevel,
                items: _educationLevels
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) => setState(() => educationLevel = value!),
              ),
            if (role == "tutor")
              _buildDropdown<String>(
                label: 'วุฒิการศึกษา',
                icon: Icons.workspace_premium_outlined,
                value: educationQualification,
                items: _educationLevels
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (value) =>
                    setState(() => educationQualification = value!),
              ),
            if (role == "tutor") ...[
              _sectionHeader('ข้อมูลการสอน', Icons.cast_for_education_outlined),
              _buildTextField(
                teachingZoneCtrl,
                'โซนที่สอน',
                Icons.map_outlined,
              ),
              _buildDropdown<int?>(
                label: 'ภาษาที่สอนได้',
                icon: Icons.language_outlined,
                value: languageTeach,
                items: _languageTeachOptions.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => languageTeach = value),
              ),
              _buildDropdown<int?>(
                label: 'ระดับที่สอนได้',
                icon: Icons.stairs_outlined,
                value: teachableLevel,
                items: _teachableLevelOptions.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => teachableLevel = value),
              ),
              _buildTextField(
                teachingExperienceCtrl,
                'ประสบการณ์สอน',
                Icons.timeline_outlined,
              ),
              _buildTextField(
                experienceCtrl,
                'ประวัติการสอน',
                Icons.history_edu_outlined,
                maxLines: 3,
              ),
              _buildTextField(
                performanceCtrl,
                'ผลงาน/ใบรับรอง',
                Icons.workspace_premium_outlined,
                maxLines: 3,
              ),
              _buildTextField(
                expertiseCtrl,
                'ความเชี่ยวชาญ',
                Icons.star_outline,
                maxLines: 3,
              ),
            ],
            if (role == "student") ...[
              _sectionHeader('ข้อมูลการเรียน', Icons.menu_book_outlined),
              _buildTextField(
                learningZoneCtrl,
                'เขตที่เรียน',
                Icons.map_outlined,
              ),
              _buildDropdown<int?>(
                label: 'ภาษาที่ใช้',
                icon: Icons.language_outlined,
                value: languageUsed,
                items: _languageOptions.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => languageUsed = value),
              ),
              _buildDropdown<int?>(
                label: 'ระดับความรู้ปัจจุบัน',
                icon: Icons.auto_stories_outlined,
                value: knowledgeLevel,
                items: _knowledgeLevelOptions.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => knowledgeLevel = value),
              ),
              _buildDropdown<int?>(
                label: 'วัตถุประสงค์การเรียน',
                icon: Icons.flag_outlined,
                value: courseInterest,
                items: _courseInterestOptions.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => courseInterest = value),
              ),
            ],
            _sectionHeader('ข้อมูลติดต่อ', Icons.contact_mail_outlined),
            _buildTextField(
              emailCtrl,
              'อีเมล',
              Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              errorText: emailError,
              onChangedClearError: () {
                if (emailError != null) setState(() => emailError = null);
              },
            ),
            _buildTextField(
              phoneCtrl,
              'เบอร์โทรศัพท์',
              Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              errorText: phoneError,
              onChangedClearError: () {
                if (phoneError != null) setState(() => phoneError = null);
              },
            ),
            _buildTextField(addressCtrl, 'ที่อยู่', Icons.location_on_outlined),
            _sectionHeader('บัญชีผู้ใช้', Icons.account_circle_outlined),
            _buildTextField(
              usernameCtrl,
              'ชื่อผู้ใช้',
              Icons.account_circle_outlined,
              errorText: usernameError,
              onChangedClearError: () {
                if (usernameError != null) setState(() => usernameError = null);
              },
            ),
            _buildTextField(
              passwordCtrl,
              'รหัสผ่าน',
              Icons.lock_outline,
              isPassword: true,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  disabledBackgroundColor: const Color(0xFFB0A8F4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'สมัครสมาชิก',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "มีบัญชีอยู่แล้ว? ",
                    style: TextStyle(color: Color(0xFF888888), fontSize: 15),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'เข้าสู่ระบบ',
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
