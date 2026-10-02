import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_driver.dart';

void main() {
  group('F. จับคู่', () {
    appTest('แสดงการ์ดคู่ที่เหมาะสม พร้อมชื่อและคะแนน', (d) async {
      await d.loginStudent();
      await d.tapTab('จับคู่');
      d.expectText('อนุชา สอนดี');
      expect(d.be.count('api_matching.php'), 1);
      expect(d.be.callsTo('api_matching.php').single['body']['id'], 'ST900');
    });

    appTest('ไม่มีคู่: แสดงข้อความว่าง', (d) async {
      d.be.matches = [];
      await d.loginStudent();
      await d.tapTab('จับคู่');
      d.expectText('ยังไม่พบคู่ที่เหมาะสม');
    });

    appTest('เซิร์ฟเวอร์ล่ม (500): แสดงข้อผิดพลาด + ลองใหม่ได้', (d) async {
      d.be.failures['api_matching.php'] = 'error500';
      await d.loginStudent();
      await d.tapTab('จับคู่');
      d.expectText('ลองใหม่');
      d.be.failures.clear();
      await d.tapText('ลองใหม่');
      d.expectText('อนุชา สอนดี');
      expect(d.be.count('api_matching.php'), 2);
    });

    appTest('ส่งคำขอ: ยกเลิกใน dialog = ไม่ส่ง', (d) async {
      await d.loginStudent();
      await d.tapTab('จับคู่');
      await d.tapScrolled('ส่งคำขอ');
      d.expectText('ส่งคำขอจับคู่');
      await d.tapText('ยกเลิก');
      expect(d.be.count('api_send_request.php'), 0);
    });

    appTest('ส่งคำขอ: ยืนยัน → เรียก API และการ์ดเปลี่ยนสถานะรอยืนยัน', (
      d,
    ) async {
      await d.loginStudent();
      await d.tapTab('จับคู่');
      await d.tapScrolled('ส่งคำขอ');
      // dialog: ปุ่ม "ส่งคำขอ" อันสุดท้ายคือปุ่มยืนยัน
      await d.tapText('ส่งคำขอ', last: true);
      expect(d.be.count('api_send_request.php'), 1);
      d.expectText('ส่งคำขอแล้ว รอการยืนยัน');
    });

    appTest('ผู้สอนเห็นการ์ดผู้เรียน', (d) async {
      await d.loginTutor();
      await d.tapTab('จับคู่');
      d.expectText('สมชาย ทดสอบ');
    });

    Map<String, dynamic> pendingRequest() => {
      'notification_id': 1,
      'type': 'request_received',
      'title': 'มีคำขอจับคู่ใหม่',
      'message': 'สมชายส่งคำขอถึงคุณ',
      'match_id': 'M001',
      'request_status': 'pending',
      'is_read': 0,
    };

    appTest(
      'แจ้งเตือน: มีป้ายตัวเลข → กดกลางกระดิ่งแล้วต้องเปิดหน้าแจ้งเตือน',
      (d) async {
        d.be.notifications = [pendingRequest()];
        await d.loginTutor();
        await d.tapTab('จับคู่');
        d.expectText('1'); // ป้ายจำนวนที่ยังไม่อ่านบนกระดิ่ง
        // ผู้ใช้จริงกดกลางไอคอนกระดิ่ง
        await d.t.tap(find.byIcon(Icons.notifications_outlined));
        await d.settle();
        d.expectText('มีคำขอจับคู่ใหม่');
      },
    );

    appTest('แจ้งเตือน: เปิด → ยืนยันคำขอ → เรียก API และไปห้องแชท', (d) async {
      d.be.notifications = [pendingRequest()];
      await d.loginTutor();
      await d.tapTab('จับคู่');
      // กดฝั่งซ้ายของกระดิ่ง (เลี่ยงป้ายตัวเลขที่บังอยู่) เพื่อทดสอบขั้นตอนถัดไป
      final bell = d.t.getCenter(find.byIcon(Icons.notifications_outlined));
      await d.t.tapAt(bell - const Offset(12, 0));
      await d.settle();
      d.expectText('มีคำขอจับคู่ใหม่');
      await d.tapText('ยืนยัน');
      expect(d.be.count('api_respond_request.php'), 1);
      expect(
        find.byIcon(Icons.send),
        findsOneWidget,
        reason: 'ยืนยันแล้วต้องเปิดห้องแชท',
      );
    });

    appTest('แจ้งเตือน: ไม่มีรายการ → ข้อความว่าง', (d) async {
      await d.loginStudent();
      await d.tapTab('จับคู่');
      await d.tapIcon(Icons.notifications_outlined);
      d.expectText('ยังไม่มีการแจ้งเตือน');
    });
  });

  group('G. แชท', () {
    appTest('รายการห้อง: ชื่อ/ข้อความล่าสุด/จำนวนยังไม่อ่าน', (d) async {
      await d.loginStudent();
      await d.tapTab('แชท');
      d.expectText('อนุชา สอนดี');
      d.expectText('สวัสดีครับ');
      d.expectText('2');
    });

    appTest('ไม่มีห้อง: ข้อความว่าง', (d) async {
      d.be.conversations = [];
      await d.loginStudent();
      await d.tapTab('แชท');
      d.expectText('ยังไม่มีคู่สนทนา\nแชทจะเปิดใช้งานได้เมื่อแมตช์สำเร็จ');
    });

    appTest('เซิร์ฟเวอร์ล่ม: แสดงข้อผิดพลาด + ลองใหม่', (d) async {
      d.be.failures['api_get_conversations.php'] = 'error500';
      await d.loginStudent();
      await d.tapTab('แชท');
      d.expectText('เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ กรุณาลองใหม่');
      d.be.failures.clear();
      await d.tapText('ลองใหม่');
      d.expectText('อนุชา สอนดี');
    });

    appTest('เปิดห้อง → พิมพ์ส่งข้อความ → ส่งถูก → กลับแล้วรายการรีเฟรช', (
      d,
    ) async {
      await d.loginStudent();
      await d.tapTab('แชท');
      await d.tapText('อนุชา สอนดี');
      expect(d.hasAppBarBack, isTrue, reason: 'ห้องแชทต้องมีลูกศร back');
      await d.t.enterText(find.byType(TextField).last, 'สวัสดีครับครู');
      await d.tapIcon(Icons.send);
      final sent = d.be.callsTo('api_send_message.php');
      expect(sent.length, 1);
      expect(sent.first['body'].toString(), contains('สวัสดีครับครู'));
      final before = d.be.count('api_get_conversations.php');
      await d.tapAppBarBack();
      d.expectText('แชท');
      expect(
        d.be.count('api_get_conversations.php'),
        greaterThan(before),
        reason: 'กลับจากห้องแชทต้องรีเฟรชรายการห้อง',
      );
    });

    appTest('ส่งข้อความว่าง: ไม่ส่ง', (d) async {
      await d.loginStudent();
      await d.tapTab('แชท');
      await d.tapText('อนุชา สอนดี');
      await d.tapIcon(Icons.send);
      expect(d.be.count('api_send_message.php'), 0);
    });
  });
}
