import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project/birth_date_field.dart';

/// วันเกิดที่ทำให้ ณ วันนี้อายุ [years] ปีพอดี (รูปแบบ YYYY-MM-DD เหมือนที่เซิร์ฟเวอร์ส่ง)
String birthDateForAge(int years) {
  final n = DateTime.now();
  return birthDateToIso(DateTime(n.year - years, n.month, n.day));
}

/// เซิร์ฟเวอร์จำลอง: ตอบตาม path ของ API จริง (รูปแบบคำตอบอ่านจากโค้ดแอป/ไฟล์ PHP)
/// เก็บสถานะและ body ที่แอปส่งมา เพื่อให้เทสต์ตรวจได้ว่าแอปส่งข้อมูลถูกต้อง
class FakeBackend {
  /// โหมดล้มเหลวของ endpoint: path -> 'error500' | 'badjson' | 'timeout'
  final Map<String, String> failures = {};

  /// หน่วงเวลาตอบของ endpoint (ไว้ทดสอบกดซ้ำระหว่างรอ)
  final Map<String, Duration> delays = {};

  /// รายงานของแอดมิน (get_report): รอ 2 / ยืนยัน 3 / ปฏิเสธ 1 → คำขอทั้งหมด 6, อัตราสำเร็จ 75%
  Map<String, dynamic> report = {
    'total_students': 12,
    'total_tutors': 5,
    'total_admins': 1,
    'online_students': 4,
    'online_tutors': 2,
    'total_matches': 6,
    'match_status_counts': {'pending': 2, 'confirmed': 3, 'rejected': 1},
    'avg_match_score': 88.5,
    'top_subjects': [
      {'subject': 'คณิตศาสตร์', 'cnt': 3},
      {'subject': 'ฟิสิกส์', 'cnt': 2},
    ],
    'active_learn_count': 7,
    'active_teach_count': 3,
    'top_tutors': [
      {'tutor_id': 'TU001', 'tutor_name': 'อนุชา สอนดี', 'cnt': 3},
    ],
    'confirmed_matches': 3,
    'decided_matches': 4,
    'success_rate': 75.0,
    'rejection_rate': 25.0,
    'subject_gaps': [
      {'subject': 'เคมี', 'demand': 4, 'supply': 0, 'gap': 4},
      {'subject': 'คณิตศาสตร์', 'demand': 2, 'supply': 2, 'gap': 0},
    ],
    'chat_messages': 40,
    'chat_rooms': 2,
    'chat_rooms_silent': 1, // ยืนยัน 3 ห้อง คุยกัน 2 ห้อง (66.7%) ไม่คุย 1 ห้อง
    'confirmed_with_chat_rate': 66.7,
  };

  /// ให้ api_matching ส่ง my_request (ความต้องการปัจจุบัน) กลับมาหรือไม่ (false = จำลองเซิร์ฟเวอร์รุ่นเก่า)
  bool includeMyRequest = true;

  /// ความต้องการเรียน/สอนปัจจุบัน (แถว active) ที่ api_matching ส่งกลับใน my_request
  Map<String, dynamic> currentLearn = {
    'learn_reg_id': 'LR001',
    'subject_learn': 'ฟิสิกส์',
    'content_level': 1,
    'objective_learn': 0,
    'preferred_time_learn': 1,
    'duration_learn': 1,
    'learning_format_learn': 0,
    'teachable_distance_learn': 1,
    'budget_per_hour': 1,
    'required_experience_learn': 1,
    'preferred_teaching_method_learn': 0,
    'tutor_knowledge_level_learn': 1,
    'group_size_learn': 0,
    'teaching_style_learn': 0,
    'teaching_method_learn': 0,
    'teaching_language_learn': 0,
    'preferred_gender_learn': 0,
    'student_id': 'ST900',
    'learn_status': 'active',
  };

  Map<String, dynamic> currentTeach = {
    'teach_req_id': 'TR001',
    'subject_teach': 'ภาษาอังกฤษ',
    'teach_level': 1,
    'objective_teach': 0,
    'preferred_time_teach': 1,
    'duration_teach': 1,
    'learning_format_teach': 0,
    'teachable_distance_teach': 1,
    'teaching_rate_per_hour': 1,
    'required_experience_teach': 1,
    'preferred_teaching_method_teach': 0,
    'tutor_knowledge_level_teach': 1,
    'group_size_teach': 0,
    'teaching_style_teach': 0,
    'teaching_method_teach': 0,
    'teaching_language_teach': 0,
    'preferred_gender_teach': 0,
    'tutor_id': 'TU900',
    'teach_status': 'active',
  };

  /// ให้ api_add_learn/api_add_teach ตอบ result=0 พร้อมข้อความนี้
  String? rejectSaveMessage;

  /// ทุกคำขอที่เข้ามา: {method, path, query, body}
  final List<Map<String, dynamic>> requests = [];

  Map<String, dynamic> student = {
    'student_id': 'ST900',
    'first_name_student': 'สมชาย',
    'last_name_student': 'ทดสอบ',
    'gender_student': 'Male',
    'age_student': 16,
    'birth_date': birthDateForAge(16),
    'occupation': 'นักเรียน',
    'education_level': 'มัธยมศึกษาตอนต้น',
    'email_student': 'somchai@test.com',
    'phone_number_student': '0812345678',
    'address_student': '1 ถนนทดสอบ',
    'learning_zone': 'ขอนแก่น',
    'language_used': 1,
    'knowledge_level': 2,
    'course_interest': 1,
    'st_username': 'somchai',
    'is_online': 1,
    'photo_path': null,
  };

  Map<String, dynamic> tutor = {
    'tutor_id': 'TU900',
    'first_name_tutor': 'อนุชา',
    'last_name_tutor': 'สอนดี',
    'gender_tutor': 'Male',
    'age_tutor': 30,
    'birth_date': birthDateForAge(30),
    'subject_teach': 'คณิตศาสตร์',
    'education_qualification': 'ปริญญาตรี',
    'email_tutor': 'anucha@test.com',
    'phone_number_tutor': '0898765432',
    'address_tutor': '2 ถนนครู',
    'teaching_zone': 'ขอนแก่น',
    'language_teach': 1,
    'teachable_level': 2,
    'teaching_experience': '3 ปี',
    'experience': 'สอนพิเศษ',
    'performance': 'ดี',
    'expertise': 'เลข',
    'tu_username': 'anucha',
    'is_online': 1,
    'photo_path': null,
  };

  Map<String, dynamic> admin = {
    'admin_id': 'AD001',
    'first_name': 'แอดมิน',
    'last_name': 'ระบบ',
    'email': 'admin@test.com',
  };

  /// รหัสผ่านที่ยอมรับ (ทุกบัญชีใช้รหัสเดียวกัน)
  String goodPassword = 'pass1234';

  bool hasCurrentMatch = true;
  double currentScore = 87.5;

  List<Map<String, dynamic>> matches = [
    {
      'tutor_name': 'อนุชา สอนดี',
      'student_name': 'สมชาย ทดสอบ',
      'subject': 'คณิตศาสตร์',
      'level': 2,
      'format': 1,
      'time': 1,
      'rate': 300,
      'budget': 300,
      'age': 30,
      'gender': 'Male',
      'education': 'ปริญญาตรี',
      'email': 'a@test.com',
      'phone': '0800000000',
      'photo_url': null,
      'score': 91.2,
      'score_detail': {},
      'teach_req_id': 'TR001',
      'learn_reg_id': 'LR001',
      'request_status': null,
    },
  ];

  List<Map<String, dynamic>> notifications = [];
  List<Map<String, dynamic>> conversations = [
    {
      'match_id': 'M001',
      'partner_name': 'อนุชา สอนดี',
      'subject': 'คณิตศาสตร์',
      'last_message': 'สวัสดีครับ',
      'unread_count': 2,
      'partner_is_online': 1,
      'partner_photo_url': null,
    },
  ];
  List<Map<String, dynamic>> messages = [];
  List<Map<String, dynamic>> learnHistory = [
    {
      'learn_reg_id': 'LR001',
      'subject_learn': 'ฟิสิกส์',
      'content_level': 1,
      'objective_learn': 0,
      'preferred_time_learn': 1,
      'duration_learn': 1,
      'learning_format_learn': 0,
      'teachable_distance_learn': 1,
      'budget_per_hour': 1,
      'required_experience_learn': 1,
      'preferred_teaching_method_learn': 0,
      'tutor_knowledge_level_learn': 1,
      'group_size_learn': 0,
      'teaching_style_learn': 0,
      'teaching_method_learn': 0,
      'teaching_language_learn': 0,
      'preferred_gender_learn': 0,
    },
  ];
  List<Map<String, dynamic>> teachHistory = [];

  int count(String path) => requests.where((r) => r['path'] == path).length;
  List<Map<String, dynamic>> callsTo(String path) =>
      requests.where((r) => r['path'] == path).toList();

  late final MockClient client = MockClient(_handle);

  Future<http.Response> _handle(http.Request req) async {
    final path = req.url.pathSegments.isEmpty ? '' : req.url.pathSegments.last;
    Map<String, dynamic> body = {};
    if (req.method == 'POST' && req.body.isNotEmpty) {
      try {
        body = Map<String, dynamic>.from(jsonDecode(req.body) as Map);
      } catch (_) {}
    }
    requests.add({
      'method': req.method,
      'path': path,
      'query': req.url.queryParameters,
      'body': body,
    });

    final delay = delays[path];
    if (delay != null) await Future<void>.delayed(delay);

    final fail = failures[path];
    if (fail == 'error500') return http.Response('server error', 500);
    if (fail == 'badjson') return http.Response('<html>oops</html>', 200);
    if (fail == 'timeout') {
      await Completer<void>().future; // ไม่ตอบ (ผู้เรียกมี .timeout เอง)
    }

    Map<String, dynamic> ok([Map<String, dynamic> extra = const {}]) => {
      'result': 1,
      'message': 'success',
      ...extra,
    };
    http.Response json(Map<String, dynamic> m) => http.Response(
      jsonEncode(m),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

    switch (path) {
      case 'login.php':
        final u = body['username'];
        final p = body['password'];
        if (p != goodPassword) {
          return json({'result': 0, 'message': 'fail', 'datalist': null});
        }
        if (u == 'admin') {
          return json(ok({'role': 'admin', 'datalist': admin}));
        }
        if (u == student['st_username']) {
          return json(ok({'role': 'student', 'datalist': student}));
        }
        if (u == tutor['tu_username']) {
          return json(ok({'role': 'tutor', 'datalist': tutor}));
        }
        return json({'result': 0, 'message': 'fail', 'datalist': null});

      case 'api_admin.php':
        final action = body['action'];
        if (action == 'ping' || action == 'logout') return json(ok());
        if (action == 'delete_account') {
          if (body['password'] != goodPassword) {
            return json({'result': 0, 'message': 'รหัสผ่านไม่ถูกต้อง'});
          }
          return json(ok());
        }
        if (action == 'get_users') {
          return json(ok({'students': [], 'tutors': [], 'summary': {}}));
        }
        if (action == 'get_admins') return json(ok({'admins': []}));
        if (action == 'get_report') return json(ok({'report': report}));
        return json(ok({'datalist': [], 'data': []}));

      case 'api_get_current_match.php':
        if (!hasCurrentMatch) return json(ok({'has_match': false}));
        return json(
          ok({
            'has_match': true,
            'partner_name': 'อนุชา สอนดี',
            'subject': 'คณิตศาสตร์',
            'score': currentScore,
          }),
        );

      case 'api_matching.php':
        return json(
          ok({
            'matches': matches,
            'subject': 'คณิตศาสตร์',
            'learn_id': 'LR001',
            'teach_id': 'TR001',
            if (includeMyRequest)
              'my_request': body['role'] == 'student'
                  ? currentLearn
                  : currentTeach,
          }),
        );

      case 'api_send_request.php':
        return json(ok({'match_id': 'M001'}));

      case 'api_get_notifications.php':
        final unread = notifications.where((n) => n['is_read'] != 1).length;
        return json(
          ok({
            'notifications': notifications,
            'unread': unread,
            'unread_count': unread,
          }),
        );

      case 'api_mark_notification_read.php':
      case 'api_respond_request.php':
        return json(ok({'match_id': 'M001'}));

      case 'api_get_conversations.php':
        return json(ok({'conversations': conversations}));

      case 'api_get_messages.php':
        return json(
          ok({
            'messages': messages,
            'partner_name': 'อนุชา สอนดี',
            'subject': 'คณิตศาสตร์',
          }),
        );

      case 'api_send_message.php':
        messages.add({
          'chat_message': body['message'] ?? body['chat_message'] ?? '',
          'sender_role': body['role'] ?? body['sender_role'] ?? 'student',
        });
        return json(ok());

      case 'api_add_learn.php':
      case 'api_add_teach.php':
        if (rejectSaveMessage != null) {
          return json({'result': 0, 'message': rejectSaveMessage});
        }
        return json(ok({'message': 'บันทึกสำเร็จ'}));

      case 'api_get_learn_history.php':
        return json(ok({'datalist': learnHistory}));
      case 'api_get_teach_history.php':
        return json(ok({'datalist': teachHistory}));

      case 'api_update_profile.php':
        final isStudent = body['role'] == 'student';
        final target = isStudent ? student : tutor;
        final s = isStudent ? '_student' : '_tutor';
        target['first_name$s'] = body['first_name'];
        target['last_name$s'] = body['last_name'];
        // เหมือนเซิร์ฟเวอร์จริง: ถ้าส่ง birth_date มา เก็บไว้แล้วคำนวณอายุจากวันเกิด
        final birth = body['birth_date'];
        if (birth != null) {
          target['birth_date'] = birth;
          target['age$s'] = ageFromBirthDate(birth);
        }
        target['email$s'] = body['email'];
        target['phone_number$s'] = body['phone_number'] ?? body['phone'];
        target['address$s'] = body['address'];
        return json({
          'result': 1,
          'message': 'อัปเดตโปรไฟล์สำเร็จ',
          'datalist': target,
        });

      case 'register.php':
        return json(ok());
    }
    return http.Response('not found: $path', 404);
  }
}
