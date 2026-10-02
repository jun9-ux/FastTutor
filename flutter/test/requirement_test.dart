import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_driver.dart';

void main() {
  group('E. ความต้องการเรียน (ผู้เรียน)', () {
    appTest(
      'กรอกวิชา → บันทึก → ส่งข้อมูลถูก และไปหน้าจับคู่ทันที (สแตกสะอาด)',
      (d) async {
        await d.loginStudent();
        await d.tapTab('เพิ่มการเรียน');
        await d.t.enterText(find.byType(TextField).first, 'เคมี');
        await d.tapScrolled('บันทึกความต้องการเรียน');
        final call = d.be.callsTo('api_add_learn.php').single;
        expect(call['body']['subject_learn'], 'เคมี');
        expect(call['body']['student_id'], 'ST900');
        d.expectText('ผู้สอนที่เหมาะสม');
        expect(
          d.pageCount,
          3,
          reason: 'ต้องเป็น ล็อกอิน/แดชบอร์ด/จับคู่ ไม่มีฟอร์มค้าง',
        );
        await d.systemBack();
        expect(d.onDashboard, isTrue);
      },
    );

    appTest(
      'บันทึกไม่สำเร็จ (result=0): อยู่หน้าเดิมพร้อมข้อความ ไม่ไปจับคู่',
      (d) async {
        d.be.rejectSaveMessage = 'ข้อมูลไม่ครบ';
        await d.loginStudent();
        await d.tapTab('เพิ่มการเรียน');
        await d.t.enterText(find.byType(TextField).first, 'เคมี');
        await d.tapScrolled('บันทึกความต้องการเรียน');
        d.expectText('ข้อมูลไม่ครบ');
        d.expectText('เพิ่มความต้องการเรียน');
        d.expectNoText('ผู้สอนที่เหมาะสม');
      },
    );

    appTest('กดบันทึกรัว ๆ ระหว่างรอเซิร์ฟเวอร์: ส่งครั้งเดียว', (d) async {
      d.be.delays['api_add_learn.php'] = const Duration(seconds: 2);
      await d.loginStudent();
      await d.tapTab('เพิ่มการเรียน');
      await d.t.enterText(find.byType(TextField).first, 'เคมี');
      final f = find.text('บันทึกความต้องการเรียน');
      await d.t.ensureVisible(f);
      await d.t.pump();
      await d.t.tap(f);
      await d.t.pump(const Duration(milliseconds: 100));
      // ปุ่มกลายเป็น spinner แล้ว ผู้ใช้ยังพยายามกดปุ่มเดิมซ้ำ
      await d.t.tap(find.byType(ElevatedButton).last, warnIfMissed: false);
      await d.t.tap(find.byType(ElevatedButton).last, warnIfMissed: false);
      await d.settle(3000);
      expect(d.be.count('api_add_learn.php'), 1);
    });

    appTest('วิชาว่าง: ระบบไม่ควรบันทึกความต้องการที่ไม่มีวิชา', (d) async {
      await d.loginStudent();
      await d.tapTab('เพิ่มการเรียน');
      await d.tapScrolled('บันทึกความต้องการเรียน');
      expect(
        d.be.count('api_add_learn.php'),
        0,
        reason: 'ส่งความต้องการเรียนที่ไม่มีชื่อวิชาไปบันทึกได้',
      );
    });

    appTest(
      'ประวัติ → ใช้ข้อมูลเดิม → บันทึก → จับคู่ → "โปรไฟล์" → แดชบอร์ด',
      (d) async {
        await d.loginStudent();
        await d.tapTab('เพิ่มการเรียน');
        await d.tapText('ประวัติ');
        d.expectText('ประวัติความต้องการเรียน');
        await d.tapText('ฟิสิกส์');
        await d.tapScrolled('ใช้ข้อมูลนี้เพิ่มความต้องการเรียนใหม่');
        d.expectText('เพิ่มความต้องการเรียน');
        // ฟอร์มถูกเติมค่าเดิมจากประวัติ
        final subject = d.t.widget<TextField>(find.byType(TextField).first);
        expect(subject.controller?.text, 'ฟิสิกส์');
        await d.tapScrolled('บันทึกความต้องการเรียน');
        d.expectText('ผู้สอนที่เหมาะสม');
        expect(d.pageCount, 3, reason: 'ต้องไม่มีหน้าประวัติค้างใต้จับคู่');
        await d.tapTab('โปรไฟล์');
        expect(d.onDashboard, isTrue);
        expect(d.pageCount, 2);
      },
    );

    appTest('ประวัติว่าง: แสดงข้อความว่าง ไม่ล่ม', (d) async {
      await d.loginStudent();
      d.be.learnHistory = [];
      await d.tapTab('เพิ่มการเรียน');
      await d.tapText('ประวัติ');
      d.expectText('ยังไม่มีประวัติการกรอกข้อมูลความต้องการเรียน');
    });
  });

  group('E. ความต้องการสอน (ผู้สอน)', () {
    appTest('กรอกวิชา → บันทึก → ไปหน้าจับคู่ทันที', (d) async {
      await d.loginTutor();
      await d.tapTab('เพิ่มการสอน');
      await d.t.enterText(find.byType(TextField).first, 'ภาษาอังกฤษ');
      await d.tapScrolled('บันทึกความต้องการสอน');
      final call = d.be.callsTo('api_add_teach.php').single;
      expect(call['body']['subject_teach'], 'ภาษาอังกฤษ');
      expect(call['body']['tutor_id'], 'TU900');
      d.expectText('ผู้เรียนที่เหมาะสม');
      expect(d.pageCount, 3);
    });

    appTest('ประวัติว่าง: แสดงข้อความว่าง ไม่ล่ม', (d) async {
      await d.loginTutor();
      await d.tapTab('เพิ่มการสอน');
      await d.tapText('ประวัติ');
      d.expectText('ประวัติความต้องการสอน');
    });
  });
}
