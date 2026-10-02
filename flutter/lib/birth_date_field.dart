import 'package:flutter/material.dart';

/// ตัวช่วยเรื่องวันเกิด: เก็บวันเกิดแล้วคำนวณอายุสดทุกครั้งที่แสดง อายุจึงเพิ่มเองทุกปี

/// แปลงข้อความ "YYYY-MM-DD" (หรือ "YYYY-MM-DD hh:mm:ss") เป็น DateTime คืน null ถ้าผิดรูปแบบ
DateTime? parseBirthDate(dynamic value) {
  final s = value?.toString();
  if (s == null || s.length < 10) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final date = DateTime(y, mo, d);
  // DateTime ปัดวันที่ไม่มีจริง (เช่น 31 ก.พ.) ไปเดือนถัดไป จึงตรวจว่าค่าไม่เพี้ยน
  if (date.year != y || date.month != mo || date.day != d) return null;
  return date;
}

/// อายุเต็มปี ณ วันนี้ (หรือ [today]) คืน null ถ้าวันเกิดว่าง/ผิดรูปแบบ/อยู่ในอนาคต
int? ageFromBirthDate(dynamic birthDate, {DateTime? today}) {
  final birth = birthDate is DateTime ? birthDate : parseBirthDate(birthDate);
  if (birth == null) return null;
  final now = today ?? DateTime.now();
  final t = DateTime(now.year, now.month, now.day);
  if (birth.isAfter(t)) return null;
  var age = t.year - birth.year;
  if (t.month < birth.month || (t.month == birth.month && t.day < birth.day)) {
    age--;
  }
  return age;
}

/// "YYYY-MM-DD" สำหรับส่งให้เซิร์ฟเวอร์
String birthDateToIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// "dd/MM/yyyy" สำหรับแสดงในช่อง
String birthDateToDisplay(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/'
    '${d.year.toString().padLeft(4, '0')}';

/// เปิดตัวเลือกวันที่ ย้อนหลังได้ถึงปี 1900 ไม่เกินวันนี้ คืน null ถ้ายกเลิก
Future<DateTime?> pickBirthDate(BuildContext context, {DateTime? initial}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var start = initial ?? DateTime(today.year - 18, today.month, today.day);
  if (start.isAfter(today)) start = today;
  return showDatePicker(
    context: context,
    initialDate: start,
    firstDate: DateTime(1900),
    lastDate: today,
    helpText: 'เลือกวันเกิด',
    cancelText: 'ยกเลิก',
    confirmText: 'ตกลง',
  );
}
