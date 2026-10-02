import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_driver.dart';

/// หน้าแท็บ: ชื่อบนแถบล่าง -> ข้อความที่ยืนยันว่าอยู่หน้านั้น (แยกตามบทบาท)
Map<String, String> pages(bool student) => {
  'แชท': 'แชท',
  'แก้ไขข้อมูล': 'แก้ไขโปรไฟล์',
  'จับคู่': student ? 'ผู้สอนที่เหมาะสม' : 'ผู้เรียนที่เหมาะสม',
  student ? 'เพิ่มการเรียน' : 'เพิ่มการสอน': student
      ? 'เพิ่มความต้องการเรียน'
      : 'เพิ่มความต้องการสอน',
};

void main() {
  for (final student in [true, false]) {
    final who = student ? 'ผู้เรียน' : 'ผู้สอน';

    group('B. แถบล่าง/เมนูหลัก ($who)', () {
      appTest('แต่ละแท็บเปิดหน้าถูก และ back กลับแดชบอร์ด', (d) async {
        student ? await d.loginStudent() : await d.loginTutor();
        for (final e in pages(student).entries) {
          await d.tapTab(e.key);
          d.expectText(e.value);
          expect(d.onDashboard, isFalse, reason: '${e.key} ไม่ควรเป็นแดชบอร์ด');
          await d.systemBack();
          expect(
            d.onDashboard,
            isTrue,
            reason: 'back จาก ${e.key} ต้องกลับแดชบอร์ด',
          );
        }
      });

      appTest('การ์ดเมนูหลัก "โปรไฟล์ของฉัน"/"แชท" เปิดหน้าถูก', (d) async {
        student ? await d.loginStudent() : await d.loginTutor();
        await d.tapText('โปรไฟล์ของฉัน');
        d.expectText('แก้ไขโปรไฟล์');
        await d.systemBack();
        await d.tapText('แชท', index: 0);
        // ในแดชบอร์ดมี "แชท" 2 ที่ (การ์ด + แท็บ) การ์ดอยู่ก่อนแท็บ
        d.expectText('แชท');
        expect(d.onDashboard, isFalse);
      });
    });

    group('C. สแตกการนำทาง ($who)', () {
      appTest('สลับแท็บวนทุกคู่ แล้ว back ถึงแดชบอร์ดโดยไม่มีหน้าค้าง', (
        d,
      ) async {
        student ? await d.loginStudent() : await d.loginTutor();
        final tabs = pages(student).keys.toList();
        await d.tapTab(tabs[0]);
        for (var i = 0; i < 2; i++) {
          for (final a in tabs) {
            for (final b in tabs) {
              if (a == b) continue;
              await d.tapTab(a);
              await d.tapTab(b);
            }
          }
        }
        // สแตกที่ถูกต้อง = ล็อกอิน + แดชบอร์ด + หน้าแท็บ 1 หน้า (ไม่มีหน้าเก่าค้าง)
        final depth = d.pageCount;
        expect(
          depth,
          3,
          reason: 'ต้องมี 3 หน้า (ล็อกอิน/แดชบอร์ด/แท็บ) แต่มี $depth',
        );
        await d.systemBack();
        expect(d.onDashboard, isTrue);
        expect(d.pageCount, 2, reason: 'ต้องเหลือแค่ล็อกอิน + แดชบอร์ด');
      });

      appTest('แท็บ "โปรไฟล์" จากทุกหน้าแท็บ กลับแดชบอร์ด', (d) async {
        student ? await d.loginStudent() : await d.loginTutor();
        for (final e in pages(student).entries) {
          await d.tapTab(e.key);
          await d.tapTab('โปรไฟล์');
          expect(d.onDashboard, isTrue, reason: 'จาก ${e.key}');
        }
      });

      appTest('back ของเครื่องที่แดชบอร์ด: ถามออกจากระบบ ยกเลิกแล้วอยู่ต่อ', (
        d,
      ) async {
        student ? await d.loginStudent() : await d.loginTutor();
        await d.systemBack();
        d.expectText('คุณต้องการออกจากระบบใช่หรือไม่?');
        await d.tapText('ยกเลิก');
        expect(d.onDashboard, isTrue);
        expect(d.be.count('api_admin.php') >= 1, isTrue);
        expect(
          d.be
              .callsTo('api_admin.php')
              .where((r) => r['body']['action'] == 'logout'),
          isEmpty,
          reason: 'ยกเลิกแล้วต้องไม่ส่ง logout',
        );
      });

      appTest(
        'back ของเครื่องที่แดชบอร์ด: ยืนยันแล้วออกจากระบบและกลับหน้าล็อกอิน',
        (d) async {
          student ? await d.loginStudent() : await d.loginTutor();
          await d.systemBack();
          await d.tapText('ออกจากระบบ', last: true);
          expect(d.onDashboard, isFalse);
          d.expectText('เข้าสู่ระบบ');
          expect(
            d.be
                .callsTo('api_admin.php')
                .where((r) => r['body']['action'] == 'logout'),
            isNotEmpty,
            reason: 'ต้องส่ง logout ให้เซิร์ฟเวอร์',
          );
        },
      );

      appTest('ลูกศร back: ไม่มีบนแดชบอร์ด/หน้าแท็บ ทั้งหมด', (d) async {
        student ? await d.loginStudent() : await d.loginTutor();
        expect(d.hasAppBarBack, isFalse, reason: 'แดชบอร์ด');
        for (final e in pages(student).entries) {
          await d.tapTab(e.key);
          expect(d.hasAppBarBack, isFalse, reason: 'หน้า ${e.key}');
          await d.tapTab('โปรไฟล์');
        }
      });

      appTest('ลูกศร back: มีบนหน้าประวัติ และกดแล้วกลับหน้าความต้องการ', (
        d,
      ) async {
        student ? await d.loginStudent() : await d.loginTutor();
        await d.tapTab(student ? 'เพิ่มการเรียน' : 'เพิ่มการสอน');
        await d.tapText('ประวัติ');
        expect(d.hasAppBarBack, isTrue);
        await d.tapAppBarBack();
        d.expectText(student ? 'เพิ่มความต้องการเรียน' : 'เพิ่มความต้องการสอน');
      });
    });
  }
}
