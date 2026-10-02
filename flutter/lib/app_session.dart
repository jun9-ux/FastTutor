import 'package:flutter/foundation.dart';

/// เก็บข้อมูลผู้ใช้ที่ล็อกอินอยู่ ให้ทุกหน้าใช้เปิดหน้าแก้ไขข้อมูลได้
/// (ตั้งค่าตอนล็อกอิน และอัปเดตทุกครั้งที่บันทึกโปรไฟล์)
/// Dashboard ฟัง [user] เพื่ออัปเดตการ์ดโปรไฟล์ทันทีเมื่อข้อมูลเปลี่ยน
class AppSession {
  static final ValueNotifier<Map<String, dynamic>> user = ValueNotifier({});

  static Map<String, dynamic> get userData => user.value;
  static set userData(Map<String, dynamic> v) => user.value = v;
}
