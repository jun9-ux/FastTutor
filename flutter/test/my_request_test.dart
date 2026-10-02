import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_driver.dart';

/// ปุ่ม "ความต้องการของฉัน" บนแถบสรุปของหน้าจับคู่ กดแล้วขึ้น popup รายละเอียดความต้องการปัจจุบัน
void main() {
  for (final student in [true, false]) {
    final who = student ? 'ผู้เรียน' : 'ผู้สอน';
    final subject = student ? 'ฟิสิกส์' : 'ภาษาอังกฤษ';
    final title = student ? 'ความต้องการเรียนของฉัน' : 'ความต้องการสอนของฉัน';
    final firstSection = student ? 'เนื้อหาที่ต้องการ' : 'เนื้อหาที่ต้องการสอน';
    final sampleLabel = student
        ? 'งบประมาณต่อชั่วโมง'
        : 'ช่วงเวลาที่ต้องการสอน';

    group('F2. ความต้องการปัจจุบันในหน้าจับคู่ ($who)', () {
      Future<void> openMatch(AppDriver d) async {
        student ? await d.loginStudent() : await d.loginTutor();
        await d.tapTab('จับคู่');
      }

      appTest('แถบสรุปมีปุ่ม "ความต้องการของฉัน"', (d) async {
        await openMatch(d);
        d.expectText('ความต้องการของฉัน');
        expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);
      });

      appTest('กดปุ่ม → popup แสดงวิชาและรายละเอียดปัจจุบัน ไม่มี API เพิ่ม', (
        d,
      ) async {
        await openMatch(d);
        final before = d.be.requests.length;
        await d.tapText('ความต้องการของฉัน');
        d.expectText(title);
        d.expectText('$subject  (${student ? 'LR001' : 'TR001'})');
        d.expectText('กำลังรอจับคู่');
        d.expectText(firstSection);
        d.expectText('เวลา-สถานที่');
        d.expectText(sampleLabel);
        d.expectText('แก้ไขความต้องการ');
        expect(
          d.be.requests
              .skip(before)
              .where((r) => r['path'] != 'api_get_notifications.php'),
          isEmpty,
          reason: 'popup ใช้ข้อมูลที่โหลดมาแล้ว ไม่ต้องเรียก API เพิ่ม',
        );
      });

      appTest('ปิด popup → อยู่หน้าจับคู่เดิม สแตกไม่เปลี่ยน', (d) async {
        await openMatch(d);
        final depth = d.pageCount;
        await d.tapText('ความต้องการของฉัน');
        await d.tapScrolled('ปิด');
        d.expectNoText(title);
        d.expectText(student ? 'ผู้สอนที่เหมาะสม' : 'ผู้เรียนที่เหมาะสม');
        expect(d.pageCount, depth);
      });

      appTest('ไม่พบคู่: ยังเห็นปุ่มและกดดูได้', (d) async {
        d.be.matches = [];
        await openMatch(d);
        d.expectText('ยังไม่พบคู่ที่เหมาะสม');
        await d.tapText('ความต้องการของฉัน');
        d.expectText(title);
        d.expectText('$subject  (${student ? 'LR001' : 'TR001'})');
      });

      appTest('"แก้ไขความต้องการ" → ฟอร์มถูกเติมค่าเดิม และสแตกสะอาด', (
        d,
      ) async {
        await openMatch(d);
        await d.tapText('ความต้องการของฉัน');
        await d.tapScrolled('แก้ไขความต้องการ');
        d.expectText(student ? 'เพิ่มความต้องการเรียน' : 'เพิ่มความต้องการสอน');
        final field = d.t.widget<TextField>(find.byType(TextField).first);
        expect(field.controller?.text, subject);
        expect(
          d.pageCount,
          3,
          reason: 'ล็อกอิน/แดชบอร์ด/ฟอร์ม ไม่มีหน้าจับคู่ค้าง',
        );
      });

      appTest('เซิร์ฟเวอร์รุ่นเก่า (ไม่ส่ง my_request): ไม่มีปุ่ม และไม่ล่ม', (
        d,
      ) async {
        d.be.includeMyRequest = false;
        await openMatch(d);
        d.expectText(
          'อนุชา สอนดี'.isNotEmpty && student ? 'อนุชา สอนดี' : 'สมชาย ทดสอบ',
        );
        d.expectNoText('ความต้องการของฉัน');
      });

      appTest('จอ 320×568: แถบสรุปและ popup ไม่ล้น', (d) async {
        await openMatch(d);
        await d.tapText('ความต้องการของฉัน');
        d.expectText(title);
      }, size: const Size(320, 568));

      appTest('ตัวอักษรใหญ่ 1.6 เท่า: แถบสรุปและ popup ไม่ล้น', (d) async {
        await openMatch(d);
        await d.tapText('ความต้องการของฉัน');
        d.expectText(title);
      }, textScale: 1.6);
    });
  }
}
