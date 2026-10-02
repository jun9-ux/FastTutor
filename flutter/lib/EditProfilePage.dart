import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'app_nav_bar.dart';
import 'Learn.dart' hide Duration;
import 'teach.dart' hide Duration;
import 'match.dart';
import 'chat_list_page.dart';
import 'photo_helper.dart';
import 'app_session.dart';
import 'birth_date_field.dart';
import 'app_theme.dart';
import 'api_config.dart';
import 'login.dart';

class EditProfilePage extends StatefulWidget {
  final String role;
  final Map<String, dynamic> userData;
  final void Function(Map<String, dynamic> updatedData) onUpdated;

  const EditProfilePage({
    super.key,
    required this.role,
    required this.userData,
    required this.onUpdated,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final int _currentIndex = 4; // อยู่หน้าแก้ไขข้อมูล

  late TextEditingController _fnameCtrl;
  late TextEditingController _lnameCtrl;
  DateTime? _birthDate; // วันเกิด (อายุคำนวณจากวันเกิดเสมอ จึงเพิ่มเองทุกปี)
  late TextEditingController _birthCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _occupationCtrl;
  late TextEditingController _subjectCtrl;
  late TextEditingController _learningZoneCtrl;
  late TextEditingController _teachingZoneCtrl;
  late TextEditingController _teachingExperienceCtrl;
  late TextEditingController _experienceCtrl;
  late TextEditingController _performanceCtrl;
  late TextEditingController _expertiseCtrl;

  String _gender = 'Male';
  String? _education;
  String? _eduQual;

  // 🔹 ฟิลด์เฉพาะนักเรียน (ตรงกับตาราง student ในฐานข้อมูล)
  int? _languageUsed;
  int? _knowledgeLevel;
  int? _courseInterest;

  // 🔹 ฟิลด์เฉพาะติวเตอร์ (ตรงกับตาราง tutor ในฐานข้อมูล)
  int? _languageTeach;
  int? _teachableLevel;

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

  String? _photoPath;
  XFile? _pendingPhoto; // รูปที่เลือกไว้แต่ยังไม่อัปโหลด จะอัปโหลดตอนกดบันทึก

  bool get _isStudent => widget.role == 'student';
  Color get _themeColor => AppColors.forRole(widget.role);
  String get _userId =>
      _isStudent ? widget.userData['student_id'] : widget.userData['tutor_id'];

  @override
  void initState() {
    super.initState();
    final d = widget.userData;
    _photoPath = d['photo_path']?.toString();
    _birthDate = parseBirthDate(d['birth_date']);
    _birthCtrl = TextEditingController(
      text: _birthDate == null ? '' : birthDateToDisplay(_birthDate!),
    );
    if (_isStudent) {
      _fnameCtrl = TextEditingController(text: d['first_name_student'] ?? '');
      _lnameCtrl = TextEditingController(text: d['last_name_student'] ?? '');
      _emailCtrl = TextEditingController(text: d['email_student'] ?? '');
      _phoneCtrl = TextEditingController(text: d['phone_number_student'] ?? '');
      _addressCtrl = TextEditingController(text: d['address_student'] ?? '');
      _occupationCtrl = TextEditingController(text: d['occupation'] ?? '');
      final existingEducation = d['education_level']?.toString();
      _education = _educationLevels.contains(existingEducation)
          ? existingEducation
          : null;
      _subjectCtrl = TextEditingController();
      _learningZoneCtrl = TextEditingController(text: d['learning_zone'] ?? '');
      _languageUsed = _toInt(d['language_used']);
      _knowledgeLevel = _toInt(d['knowledge_level']);
      _courseInterest = _toInt(d['course_interest']);
      _teachingZoneCtrl = TextEditingController();
      _teachingExperienceCtrl = TextEditingController();
      _experienceCtrl = TextEditingController();
      _performanceCtrl = TextEditingController();
      _expertiseCtrl = TextEditingController();
      _gender = _normalizeGender(d['gender_student']);
    } else {
      _fnameCtrl = TextEditingController(text: d['first_name_tutor'] ?? '');
      _lnameCtrl = TextEditingController(text: d['last_name_tutor'] ?? '');
      _emailCtrl = TextEditingController(text: d['email_tutor'] ?? '');
      _phoneCtrl = TextEditingController(text: d['phone_number_tutor'] ?? '');
      _addressCtrl = TextEditingController(text: d['address_tutor'] ?? '');
      _occupationCtrl = TextEditingController();
      _subjectCtrl = TextEditingController(text: d['subject_teach'] ?? '');
      _learningZoneCtrl = TextEditingController();
      final existingEduQual = d['education_qualification']?.toString();
      _eduQual = _educationLevels.contains(existingEduQual)
          ? existingEduQual
          : null;
      _teachingZoneCtrl = TextEditingController(text: d['teaching_zone'] ?? '');
      _languageTeach = _toInt(d['language_teach']);
      _teachableLevel = _toInt(d['teachable_level']);
      _teachingExperienceCtrl = TextEditingController(
        text: d['teaching_experience'] ?? '',
      );
      _experienceCtrl = TextEditingController(text: d['experience'] ?? '');
      _performanceCtrl = TextEditingController(text: d['performance'] ?? '');
      _expertiseCtrl = TextEditingController(text: d['expertise'] ?? '');
      _gender = _normalizeGender(d['gender_tutor']);
    }
    _initialSnapshot = _snapshot();
  }

  // 🔹 ค่าฟอร์มตอนเปิดหน้า ใช้เทียบว่ามีการแก้ไขที่ยังไม่บันทึกหรือไม่
  late String _initialSnapshot;

  String _snapshot() => jsonEncode([
    _fnameCtrl.text,
    _lnameCtrl.text,
    _birthDate == null ? null : birthDateToIso(_birthDate!),
    _emailCtrl.text,
    _phoneCtrl.text,
    _addressCtrl.text,
    _occupationCtrl.text,
    _subjectCtrl.text,
    _learningZoneCtrl.text,
    _teachingZoneCtrl.text,
    _teachingExperienceCtrl.text,
    _experienceCtrl.text,
    _performanceCtrl.text,
    _expertiseCtrl.text,
    _gender,
    _education,
    _eduQual,
    _languageUsed,
    _knowledgeLevel,
    _courseInterest,
    _languageTeach,
    _teachableLevel,
    _pendingPhoto?.path,
  ]);

  bool get _isDirty => _snapshot() != _initialSnapshot;

  // 🔹 ถ้ามีการแก้ไขที่ยังไม่บันทึก ให้ถามยืนยันก่อนออกจากหน้า
  Future<bool> _confirmLeave() async {
    if (!_isDirty) return true;
    return confirmDialog(
      context,
      title: 'ยังไม่ได้บันทึกข้อมูล',
      message:
          'คุณแก้ไขข้อมูลแต่ยังไม่ได้บันทึก แน่ใจหรือไม่ว่าต้องการออกจากหน้านี้?',
      confirmLabel: 'ออกโดยไม่บันทึก',
      danger: true,
    );
  }

  int? _toInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    return int.tryParse(val.toString());
  }

  String _normalizeGender(dynamic val) {
    final s = val?.toString() ?? '';
    if (s == 'Female') return 'Female';
    if (s == 'Other') return 'Other';
    return 'Male';
  }

  // บน Windows desktop กล้อง (ImageSource.camera) ยังไม่รองรับใน image_picker
  // จึงให้เลือกไฟล์รูปจากเครื่องได้เลย (ImageSource.gallery เปิดเป็น file picker บน Windows)
  bool get _isWindows => !kIsWeb && Platform.isWindows;

  Future<void> _pickPhoto() async {
    ImageSource? source;
    if (_isWindows) {
      source = ImageSource.gallery;
    } else {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('ถ่ายรูป'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('เลือกจากคลังภาพ'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    }
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked == null) return;

    setState(() => _pendingPhoto = picked);
  }

  // อัปโหลดรูปที่เลือกไว้ตอนกดบันทึก คืน photo_path ใหม่ หรือ null ถ้าล้มเหลว
  Future<String?> _uploadPendingPhoto(XFile photo) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$kApiBase/api_upload_photo.php'),
      );
      request.fields['role'] = widget.role;
      request.fields['id'] = _userId;
      request.files.add(await http.MultipartFile.fromPath('photo', photo.path));

      final streamed = await request.send().timeout(
        const Duration(seconds: 20),
      );
      final res = await http.Response.fromStream(streamed);
      final data = jsonDecode(res.body);

      if (data['result'] == 1) return data['photo_path']?.toString();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${data['message']}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ กรุณาลองใหม่')),
        );
      }
    }
    return null;
  }

  @override
  void dispose() {
    _fnameCtrl.dispose();
    _lnameCtrl.dispose();
    _birthCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _occupationCtrl.dispose();
    _subjectCtrl.dispose();
    _learningZoneCtrl.dispose();
    _teachingZoneCtrl.dispose();
    _teachingExperienceCtrl.dispose();
    _experienceCtrl.dispose();
    _performanceCtrl.dispose();
    _expertiseCtrl.dispose();
    super.dispose();
  }

  // ข้อความช่วยใต้ช่องวันเกิด: อายุที่คำนวณสดจากวันเกิดที่เลือก
  String? get _birthAgeText {
    final age = ageFromBirthDate(_birthDate);
    return age == null ? null : 'อายุ $age ปี';
  }

  Future<void> _chooseBirthDate() async {
    final picked = await pickBirthDate(context, initial: _birthDate);
    if (picked == null || !mounted) return;
    setState(() {
      _birthDate = picked;
      _birthCtrl.text = birthDateToDisplay(picked);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final confirmed = await confirmDialog(
      context,
      title: 'ยืนยันการแก้ไขข้อมูล',
      message: 'แน่ใจหรือไม่ว่าต้องการบันทึกการแก้ไขข้อมูลโปรไฟล์?',
      confirmLabel: 'บันทึก',
    );
    if (!confirmed || !mounted) return;
    setState(() => _isLoading = true);

    final pending = _pendingPhoto;
    if (pending != null) {
      final newPath = await _uploadPendingPhoto(pending);
      if (!mounted) return;
      if (newPath == null) {
        setState(() => _isLoading = false);
        return;
      }
      setState(() {
        _photoPath = newPath;
        _pendingPhoto = null;
      });
    }

    final Map<String, dynamic> body = {
      "role": widget.role,
      "first_name": _fnameCtrl.text.trim(),
      "last_name": _lnameCtrl.text.trim(),
      "gender": _gender,
      "birth_date": _birthDate == null ? null : birthDateToIso(_birthDate!),
      "email": _emailCtrl.text.trim(),
      "phone": _phoneCtrl.text.trim(),
      "address": _addressCtrl.text.trim(),
    };

    if (_isStudent) {
      body["student_id"] = widget.userData['student_id'];
      body["occupation"] = _occupationCtrl.text.trim();
      body["education_level"] = _education ?? '';
      body["learning_zone"] = _learningZoneCtrl.text.trim();
      body["language_used"] = _languageUsed;
      body["knowledge_level"] = _knowledgeLevel;
      body["course_interest"] = _courseInterest;
    } else {
      body["tutor_id"] = widget.userData['tutor_id'];
      body["subject_teach"] = _subjectCtrl.text.trim();
      body["education_qualification"] = _eduQual ?? '';
      body["teaching_zone"] = _teachingZoneCtrl.text.trim();
      body["language_teach"] = _languageTeach;
      body["teachable_level"] = _teachableLevel;
      body["teaching_experience"] = _teachingExperienceCtrl.text.trim();
      body["experience"] = _experienceCtrl.text.trim();
      body["performance"] = _performanceCtrl.text.trim();
      body["expertise"] = _expertiseCtrl.text.trim();
    }

    try {
      final res = await http
          .post(
            Uri.parse("$kApiBase/api_update_profile.php"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      setState(() => _isLoading = false);

      if (data['result'] == 1) {
        final newData = Map<String, dynamic>.from(data['datalist']);
        AppSession.userData = newData;
        widget.onUpdated(newData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('อัปเดตโปรไฟล์สำเร็จ'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${data['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบบัญชีของฉัน'),
        content: const Text(
          'ข้อมูลทั้งหมดของคุณ (โปรไฟล์ ประวัติการเรียน/สอน การจับคู่ '
          'ข้อความแชท และการแจ้งเตือน) จะถูกลบถาวรและไม่สามารถกู้คืนได้ '
          'ต้องการดำเนินการต่อหรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('ดำเนินการต่อ'),
          ),
        ],
      ),
    );

    if (proceed != true || !mounted) return;
    await _promptPasswordAndDelete();
  }

  Future<void> _promptPasswordAndDelete() async {
    final passwordCtrl = TextEditingController();
    bool isSubmitting = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('ยืนยันตัวตน'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('กรอกรหัสผ่านของคุณเพื่อยืนยันการลบบัญชี'),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'รหัสผ่าน',
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('ยกเลิก'),
            ),
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (passwordCtrl.text.isEmpty) {
                        setDialogState(() => errorText = 'กรุณากรอกรหัสผ่าน');
                        return;
                      }
                      setDialogState(() {
                        isSubmitting = true;
                        errorText = null;
                      });
                      final message = await _deleteAccount(passwordCtrl.text);
                      // สำเร็จ (message == null): _deleteAccount นำทางกลับหน้าล็อกอินแล้ว
                      // ห้าม pop ซ้ำ ไม่งั้นจะปิดหน้าล็อกอินที่เพิ่งเปิดจนสแตกว่าง
                      if (message != null) {
                        setDialogState(() {
                          isSubmitting = false;
                          errorText = message;
                        });
                      }
                    },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('ลบบัญชี'),
            ),
          ],
        ),
      ),
    );
  }

  /// ลบบัญชีจริงผ่าน API — คืนค่า null เมื่อสำเร็จ (และนำทางออกไปหน้า login แล้ว)
  /// หรือคืนข้อความ error เมื่อไม่สำเร็จ (เพื่อโชว์ใน dialog ยืนยันรหัสผ่าน)
  Future<String?> _deleteAccount(String password) async {
    try {
      final res = await http
          .post(
            Uri.parse("$kApiBase/api_admin.php"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "action": "delete_account",
              "role": widget.role,
              "id": _userId,
              "password": password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);

      if (data['result'] == 1) {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const Login()),
            (route) => false,
          );
        }
        return null;
      }
      return data['message']?.toString() ?? 'ลบบัญชีไม่สำเร็จ';
    } catch (e) {
      return 'เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ กรุณาลองใหม่';
    }
  }

  Future<void> _onNavTap(int index) async {
    if (index == _currentIndex) return;
    if (!await _confirmLeave() || !mounted) return;
    final String userId = _isStudent
        ? widget.userData['student_id']
        : widget.userData['tutor_id'];
    final String firstName = _isStudent
        ? widget.userData['first_name_student'] ?? ''
        : widget.userData['first_name_tutor'] ?? '';
    final String lastName = _isStudent
        ? widget.userData['last_name_student'] ?? ''
        : widget.userData['last_name_tutor'] ?? '';
    final String fullName = '$firstName $lastName';

    switch (index) {
      case 0:
        goToDashboard(context);
        break;
      case 1:
        goToTab(
          context,
          _isStudent
              ? AddLearnPage(studentId: userId)
              : AddTeachPage(tutorId: userId),
        );
        break;
      case 2:
        goToTab(
          context,
          MatchPage(role: widget.role, userId: userId, userName: fullName),
        );
        break;
      case 4:
        break; // อยู่หน้านี้แล้ว
      case 3:
        goToTab(context, ChatListPage(role: widget.role, userId: userId));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // canPop: false → ปุ่มย้อนกลับ (AppBar / ปุ่ม back ของเครื่อง) ต้องผ่าน _confirmLeave ก่อน
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && mounted) Navigator.pop(this.context);
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'แก้ไขโปรไฟล์',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      bottomNavigationBar: AppNavBar(
        role: widget.role,
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _themeColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: _themeColor.withOpacity(0.15),
                            backgroundImage: _pendingPhoto != null
                                ? FileImage(File(_pendingPhoto!.path))
                                : buildPhotoUrl(kApiBase, _photoPath) != null
                                ? NetworkImage(
                                    buildPhotoUrl(kApiBase, _photoPath)!,
                                  )
                                : null,
                            child:
                                _pendingPhoto == null &&
                                    buildPhotoUrl(kApiBase, _photoPath) == null
                                ? Icon(
                                    _isStudent ? Icons.school : Icons.person,
                                    size: 50,
                                    color: _themeColor,
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: _pickPhoto,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _themeColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: Text(
                          'เปลี่ยนรูป',
                          style: TextStyle(
                            color: _themeColor,
                            fontSize: AppText.body,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        _isStudent ? 'โปรไฟล์ผู้เรียน' : 'โปรไฟล์ผู้สอน',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: AppText.caption,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    _sectionHeader('ข้อมูลส่วนตัว', Icons.person_outline),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            _fnameCtrl,
                            'ชื่อ',
                            Icons.badge_outlined,
                            required: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            _lnameCtrl,
                            'นามสกุล',
                            Icons.badge_outlined,
                            required: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _genderDropdown(),
                    const SizedBox(height: 4),
                    _field(
                      _birthCtrl,
                      'วันเกิด',
                      Icons.cake_outlined,
                      required: true,
                      readOnly: true,
                      onTap: _chooseBirthDate,
                      helperText: _birthAgeText,
                    ),

                    if (_isStudent) ...[
                      const SizedBox(height: 4),
                      _field(_occupationCtrl, 'อาชีพ', Icons.work_outline),
                      const SizedBox(height: 4),
                      _educationDropdown(),
                      const SizedBox(height: 4),
                      _field(
                        _learningZoneCtrl,
                        'เขตที่เรียน',
                        Icons.map_outlined,
                      ),
                      const SizedBox(height: 4),
                      _optionDropdown<int>(
                        label: 'ภาษาที่ใช้',
                        icon: Icons.language_outlined,
                        value: _languageUsed,
                        options: _languageOptions,
                        onChanged: (v) => setState(() => _languageUsed = v),
                      ),
                      const SizedBox(height: 4),
                      _optionDropdown<int>(
                        label: 'ระดับความรู้ปัจจุบัน',
                        icon: Icons.auto_stories_outlined,
                        value: _knowledgeLevel,
                        options: _knowledgeLevelOptions,
                        onChanged: (v) => setState(() => _knowledgeLevel = v),
                      ),
                      const SizedBox(height: 4),
                      _optionDropdown<int>(
                        label: 'วัตถุประสงค์การเรียน',
                        icon: Icons.flag_outlined,
                        value: _courseInterest,
                        options: _courseInterestOptions,
                        onChanged: (v) => setState(() => _courseInterest = v),
                      ),
                    ],
                    if (!_isStudent) ...[
                      const SizedBox(height: 4),
                      _field(
                        _subjectCtrl,
                        'วิชาที่สอน',
                        Icons.book_outlined,
                        required: true,
                      ),
                      const SizedBox(height: 4),
                      _eduQualDropdown(),
                      const SizedBox(height: 4),
                      _field(
                        _teachingZoneCtrl,
                        'โซนที่สอน',
                        Icons.map_outlined,
                      ),
                      const SizedBox(height: 4),
                      _optionDropdown<int>(
                        label: 'ภาษาที่สอนได้',
                        icon: Icons.language_outlined,
                        value: _languageTeach,
                        options: _languageTeachOptions,
                        onChanged: (v) => setState(() => _languageTeach = v),
                      ),
                      const SizedBox(height: 4),
                      _optionDropdown<int>(
                        label: 'ระดับที่สอนได้',
                        icon: Icons.stairs_outlined,
                        value: _teachableLevel,
                        options: _teachableLevelOptions,
                        onChanged: (v) => setState(() => _teachableLevel = v),
                      ),
                      const SizedBox(height: 4),
                      _field(
                        _teachingExperienceCtrl,
                        'ประสบการณ์สอน',
                        Icons.timeline_outlined,
                      ),
                      const SizedBox(height: 4),
                      _field(
                        _experienceCtrl,
                        'ประวัติการสอน',
                        Icons.history_edu_outlined,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 4),
                      _field(
                        _performanceCtrl,
                        'ผลงาน/ใบรับรอง',
                        Icons.workspace_premium_outlined,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 4),
                      _field(
                        _expertiseCtrl,
                        'ความเชี่ยวชาญ',
                        Icons.star_outline,
                        maxLines: 3,
                      ),
                    ],

                    const SizedBox(height: 24),
                    _sectionHeader('ข้อมูลติดต่อ', Icons.contact_mail_outlined),
                    const SizedBox(height: 12),
                    _field(
                      _emailCtrl,
                      'อีเมล',
                      Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 4),
                    _field(
                      _phoneCtrl,
                      'เบอร์โทรศัพท์',
                      Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 4),
                    _field(
                      _addressCtrl,
                      'ที่อยู่',
                      Icons.location_on_outlined,
                      maxLines: 3,
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _save,
                        icon: const Icon(Icons.save),
                        label: const Text(
                          'บันทึกการเปลี่ยนแปลง',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _themeColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 8),
                    _sectionHeader(
                      'พื้นที่อันตราย',
                      Icons.warning_amber_rounded,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _confirmDeleteAccount,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'ลบบัญชีของฉัน',
                          style: TextStyle(fontSize: 16, color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _themeColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: AppText.heading,
            fontWeight: FontWeight.bold,
            color: _themeColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: _themeColor.withOpacity(0.3))),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool required = false,
    bool readOnly = false,
    VoidCallback? onTap,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        validator: (v) {
          final t = (v ?? '').trim();
          if (t.isEmpty) return required ? 'กรุณากรอก$label' : null;
          if (keyboardType == TextInputType.number) {
            final n = int.tryParse(t);
            if (n == null || n < 1 || n > 120) return '$labelไม่ถูกต้อง';
          }
          if (keyboardType == TextInputType.emailAddress &&
              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
            return 'รูปแบบอีเมลไม่ถูกต้อง';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          prefixIcon: Icon(icon, size: 20, color: Colors.grey[600]),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _themeColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _genderDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _gender,
        decoration: InputDecoration(
          labelText: 'เพศ',
          prefixIcon: Icon(
            Icons.wc_outlined,
            size: 20,
            color: Colors.grey[600],
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _themeColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        items: const [
          DropdownMenuItem(value: 'Male', child: Text('ชาย')),
          DropdownMenuItem(value: 'Female', child: Text('หญิง')),
          DropdownMenuItem(value: 'Other', child: Text('อื่นๆ')),
        ],
        onChanged: (v) => setState(() => _gender = v!),
      ),
    );
  }

  Widget _optionDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required Map<T, String> options,
    required ValueChanged<T?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: Colors.grey[600]),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _themeColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        hint: Text('เลือก$label'),
        items: options.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _educationDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _education,
        decoration: InputDecoration(
          labelText: 'ระดับการศึกษา',
          prefixIcon: Icon(
            Icons.school_outlined,
            size: 20,
            color: Colors.grey[600],
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _themeColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        hint: const Text('เลือกระดับการศึกษา'),
        items: _educationLevels
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => setState(() => _education = v),
      ),
    );
  }

  Widget _eduQualDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _eduQual,
        decoration: InputDecoration(
          labelText: 'วุฒิการศึกษา',
          prefixIcon: Icon(
            Icons.workspace_premium_outlined,
            size: 20,
            color: Colors.grey[600],
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _themeColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        hint: const Text('เลือกวุฒิการศึกษา'),
        items: _educationLevels
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
        onChanged: (v) => setState(() => _eduQual = v),
      ),
    );
  }
}
