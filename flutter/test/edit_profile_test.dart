import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project/birth_date_field.dart';

import 'helpers/app_driver.dart';

void main() {
  group('D. แก้ไขข้อมูลโปรไฟล์ (ผู้เรียน)', () {
    appTest('ไม่แก้อะไร → ออกได้ทันทีไม่ถาม', (d) async {
      await d.loginStudent();
      await d.tapTab('แก้ไขข้อมูล');
      await d.tapTab('โปรไฟล์');
      d.expectNoText('ยังไม่ได้บันทึกข้อมูล');
      expect(d.onDashboard, isTrue);
    });

    appTest(
      'แก้ชื่อแล้วกดแท็บอื่น: ถามยืนยัน → ยกเลิกอยู่ต่อค่าที่แก้ยังอยู่ → ออก = กลับมาเป็นค่าเดิม',
      (d) async {
        await d.loginStudent();
        await d.tapTab('แก้ไขข้อมูล');
        await d.typeInto('ชื่อ', 'สมชายแก้');
        await d.tapTab('แชท');
        d.expectText('ยังไม่ได้บันทึกข้อมูล');
        await d.tapText('ยกเลิก');
        d.expectText('แก้ไขโปรไฟล์');
        expect(
          d.valueOf('ชื่อ'),
          'สมชายแก้',
          reason: 'ยกเลิกแล้วค่าที่แก้ต้องยังอยู่',
        );

        await d.tapTab('แชท');
        await d.tapText('ออกโดยไม่บันทึก');
        d.expectText('แชท');
        expect(d.be.count('api_update_profile.php'), 0);

        await d.tapTab('แก้ไขข้อมูล');
        expect(
          d.valueOf('ชื่อ'),
          'สมชาย',
          reason: 'กลับมาต้องเป็นค่าเดิมที่ยังไม่แก้',
        );
      },
    );

    appTest('แก้แล้วกด back ของเครื่อง: ถามยืนยัน → ออกแล้วกลับแดชบอร์ด', (
      d,
    ) async {
      await d.loginStudent();
      await d.tapTab('แก้ไขข้อมูล');
      await d.typeInto('นามสกุล', 'ใหม่');
      await d.systemBack();
      d.expectText('ยังไม่ได้บันทึกข้อมูล');
      await d.tapText('ออกโดยไม่บันทึก');
      expect(d.onDashboard, isTrue);
    });

    appTest('บันทึก: ถามยืนยัน → ยกเลิก = ไม่ยิง API', (d) async {
      await d.loginStudent();
      await d.tapTab('แก้ไขข้อมูล');
      await d.typeInto('ชื่อ', 'สมชายแก้');
      await d.tapScrolled('บันทึกการเปลี่ยนแปลง');
      d.expectText('ยืนยันการแก้ไขข้อมูล');
      await d.tapText('ยกเลิก');
      expect(d.be.count('api_update_profile.php'), 0);
      d.expectText('แก้ไขโปรไฟล์');
    });

    appTest('บันทึก: ยืนยัน → ส่งค่าถูก และการ์ดบนแดชบอร์ดเปลี่ยนทันที', (
      d,
    ) async {
      await d.loginStudent();
      d.expectText('สมชาย ทดสอบ');
      await d.tapTab('แก้ไขข้อมูล');
      await d.typeInto('ชื่อ', 'สมชายแก้');
      await d.tapScrolled('บันทึกการเปลี่ยนแปลง');
      await d.tapText('บันทึก', last: true);
      final calls = d.be.callsTo('api_update_profile.php');
      expect(calls.length, 1);
      expect(calls.first['body']['first_name'], 'สมชายแก้');
      expect(calls.first['body']['student_id'], 'ST900');
      expect(d.onDashboard, isTrue);
      d.expectText('สมชายแก้ ทดสอบ');
    });

    appTest(
      'แก้จากหน้าจับคู่ (ผ่านแท็บ) → บันทึก → แดชบอร์ดเห็นชื่อใหม่ทันที',
      (d) async {
        await d.loginStudent();
        await d.tapTab('จับคู่');
        await d.tapTab('แก้ไขข้อมูล');
        expect(
          d.valueOf('ชื่อ'),
          'สมชาย',
          reason: 'ต้องได้ข้อมูลผู้ใช้จริง ไม่ใช่ค่าว่าง',
        );
        await d.typeInto('ชื่อ', 'จากจับคู่');
        await d.tapScrolled('บันทึกการเปลี่ยนแปลง');
        await d.tapText('บันทึก', last: true);
        expect(d.onDashboard, isTrue);
        d.expectText('จากจับคู่ ทดสอบ');
      },
    );

    appTest('แก้จากหน้าแชท (ผ่านแท็บ) เปิดได้และมีข้อมูลผู้ใช้', (d) async {
      await d.loginStudent();
      await d.tapTab('แชท');
      await d.tapTab('แก้ไขข้อมูล');
      expect(d.valueOf('ชื่อ'), 'สมชาย');
    });

    appTest('แก้จากหน้าความต้องการเรียน (ผ่านแท็บ) เปิดได้และมีข้อมูลผู้ใช้', (
      d,
    ) async {
      await d.loginStudent();
      await d.tapTab('เพิ่มการเรียน');
      await d.tapTab('แก้ไขข้อมูล');
      expect(d.valueOf('ชื่อ'), 'สมชาย');
    });

    appTest('ชื่อว่าง → บันทึกไม่ได้ ขึ้นข้อความเตือน ไม่ยิง API', (d) async {
      await d.loginStudent();
      await d.tapTab('แก้ไขข้อมูล');
      await d.typeInto('ชื่อ', '');
      await d.tapScrolled('บันทึกการเปลี่ยนแปลง');
      d.expectText('กรุณากรอกชื่อ');
      d.expectNoText('ยืนยันการแก้ไขข้อมูล');
      expect(d.be.count('api_update_profile.php'), 0);
    });

    appTest('วันเกิด: แสดงวันเกิดของผู้ใช้และอายุที่คำนวณสด ("อายุ 16 ปี")', (
      d,
    ) async {
      await d.loginStudent();
      await d.tapTab('แก้ไขข้อมูล');
      final born = d.be.student['birth_date'] as String;
      final y = born.substring(0, 4),
          m = born.substring(5, 7),
          day = born.substring(8, 10);
      expect(d.valueOf('วันเกิด'), '$day/$m/$y');
      d.expectText('อายุ 16 ปี');
      d.expectNoText('อายุ'); // ไม่มีช่องกรอกอายุด้วยมืออีกแล้ว
    });

    appTest(
      'เลือกวันเกิดใหม่: ส่ง birth_date ถูก อายุที่แสดงและบนแดชบอร์ดเปลี่ยนตาม',
      (d) async {
        await d.loginStudent();
        await d.tapTab('แก้ไขข้อมูล');
        await d.t.ensureVisible(d.field('วันเกิด'));
        await d.t.tap(d.field('วันเกิด'));
        await d.settle();
        d.expectText('เลือกวันเกิด');
        // เลือกวันที่ 10 ของเดือนเดียวกัน (ถ้าตรงกับวันที่เดิมอยู่แล้ว ใช้วันที่ 11)
        final born = d.be.student['birth_date'] as String;
        final pick = born.endsWith('-10') ? '11' : '10';
        await d.t.tap(find.text(pick).last);
        await d.settle(300);
        await d.tapText('ตกลง');
        final expectedIso = '${born.substring(0, 8)}$pick';
        final expectedAge = ageFromBirthDate(expectedIso);
        d.expectText('อายุ $expectedAge ปี');
        await d.tapScrolled('บันทึกการเปลี่ยนแปลง');
        await d.tapText('บันทึก', last: true);
        final call = d.be.callsTo('api_update_profile.php').single;
        expect(call['body']['birth_date'], expectedIso);
        expect(
          call['body'].containsKey('age'),
          isFalse,
          reason: 'ไม่ส่งอายุที่พิมพ์เองอีกแล้ว',
        );
        expect(d.onDashboard, isTrue);
        d.expectText('$expectedAge ปี');
      },
    );

    appTest('แก้วันเกิดแล้วกดแท็บอื่น: ถามยืนยันว่ายังไม่ได้บันทึก', (d) async {
      await d.loginStudent();
      await d.tapTab('แก้ไขข้อมูล');
      await d.t.ensureVisible(d.field('วันเกิด'));
      await d.t.tap(d.field('วันเกิด'));
      await d.settle();
      final born = d.be.student['birth_date'] as String;
      await d.t.tap(find.text(born.endsWith('-10') ? '11' : '10').last);
      await d.settle(300);
      await d.tapText('ตกลง');
      await d.tapTab('แชท');
      d.expectText('ยังไม่ได้บันทึกข้อมูล');
    });

    appTest('ผู้ใช้ที่ยังไม่มีวันเกิด: ต้องเลือกก่อนบันทึก ไม่ส่ง API', (
      d,
    ) async {
      d.be.student['birth_date'] = null;
      await d.loginStudent();
      await d.tapTab('แก้ไขข้อมูล');
      await d.tapScrolled('บันทึกการเปลี่ยนแปลง');
      d.expectText('กรุณากรอกวันเกิด');
      expect(d.be.count('api_update_profile.php'), 0);
    });

    appTest(
      'แดชบอร์ด: อายุคำนวณจากวันเกิดเสมอ แม้ค่าอายุเก่าที่เก็บไว้จะล้าสมัย',
      (d) async {
        d.be.student['age_student'] = 5; // ค่าเก่าค้างในฐานข้อมูล
        await d.loginStudent();
        d.expectText('16 ปี');
        d.expectNoText('5 ปี');
      },
    );

    appTest('แดชบอร์ดผู้สอน: อายุคำนวณจากวันเกิด', (d) async {
      d.be.tutor['age_tutor'] = 5;
      await d.loginTutor();
      d.expectText('30 ปี');
    });

    appTest('อีเมลผิดรูปแบบ: ไม่ควรถูกส่งไปบันทึก', (d) async {
      await d.loginStudent();
      await d.tapTab('แก้ไขข้อมูล');
      await d.typeInto('อีเมล', 'not-an-email');
      await d.tapScrolled('บันทึกการเปลี่ยนแปลง');
      if (find.text('ยืนยันการแก้ไขข้อมูล').evaluate().isNotEmpty) {
        await d.tapText('บันทึก', last: true);
      }
      expect(
        d.be.count('api_update_profile.php'),
        0,
        reason: 'อีเมล "not-an-email" ถูกส่งไปบันทึกโดยไม่ตรวจรูปแบบ',
      );
    });

    appTest('ลบบัญชี: รหัสผ่านผิด → แจ้งข้อผิดพลาด ยังอยู่หน้าเดิม', (d) async {
      await d.loginStudent();
      await d.tapTab('แก้ไขข้อมูล');
      await d.tapScrolled('ลบบัญชีของฉัน');
      await d.tapText('ดำเนินการต่อ');
      await d.t.enterText(find.byType(TextField).last, 'wrong');
      await d.tapText('ลบบัญชี', last: true);
      d.expectText('รหัสผ่านไม่ถูกต้อง');
      d.expectText('แก้ไขโปรไฟล์');
    });

    appTest('ลบบัญชี: รหัสผ่านถูก → กลับหน้าล็อกอิน', (d) async {
      await d.loginStudent();
      await d.tapTab('แก้ไขข้อมูล');
      await d.tapScrolled('ลบบัญชีของฉัน');
      await d.tapText('ดำเนินการต่อ');
      await d.t.enterText(find.byType(TextField).last, d.be.goodPassword);
      await d.tapText('ลบบัญชี', last: true);
      d.expectText('เข้าสู่ระบบ');
      expect(d.onDashboard, isFalse);
    });
  });

  group('D. แก้ไขข้อมูลโปรไฟล์ (ผู้สอน)', () {
    appTest('แก้ชื่อ → ยืนยัน → ส่งค่าถูกและแดชบอร์ดอัปเดต', (d) async {
      await d.loginTutor();
      await d.tapTab('แก้ไขข้อมูล');
      await d.typeInto('ชื่อ', 'ครูแก้');
      await d.tapScrolled('บันทึกการเปลี่ยนแปลง');
      await d.tapText('บันทึก', last: true);
      final call = d.be.callsTo('api_update_profile.php').single;
      expect(call['body']['first_name'], 'ครูแก้');
      expect(call['body']['tutor_id'], 'TU900');
      expect(d.onDashboard, isTrue);
      d.expectText('ครูแก้ สอนดี');
    });

    appTest('แก้แล้วกดแท็บ "โปรไฟล์": ถามยืนยันก่อน', (d) async {
      await d.loginTutor();
      await d.tapTab('แก้ไขข้อมูล');
      await d.typeInto('นามสกุล', 'ใหม่');
      await d.tapTab('โปรไฟล์');
      d.expectText('ยังไม่ได้บันทึกข้อมูล');
      await d.tapText('ออกโดยไม่บันทึก');
      expect(d.onDashboard, isTrue);
    });
  });
}
