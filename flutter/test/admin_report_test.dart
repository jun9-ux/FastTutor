import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_driver.dart';

Future<void> openReport(AppDriver d) async {
  await d.login('admin');
  await d.tapText('รายงาน');
}

const sections = [
  'จำนวนผู้ใช้งาน',
  'วิชาที่ขาดผู้สอน',
  'ผลการจับคู่',
  'วิชาที่มีการจับคู่มากที่สุด',
  'การติดต่อหลังจับคู่',
];

Future<void> scrollTo(AppDriver d, String text) async {
  final f = find.text(text);
  for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
    await d.t.drag(find.byType(ListView).first, const Offset(0, -250));
    await d.settle(100);
  }
  expect(f, findsWidgets, reason: 'เลื่อนหาแล้วไม่พบ "$text"');
  await d.t.ensureVisible(f.first);
  await d.settle(200);
}

void main() {
  group('รายงานแอดมิน', () {
    appTest('แสดงรายงาน 5 ส่วนด้วยคำที่เข้าใจง่าย', (d) async {
      await openReport(d);
      for (final section in sections) {
        await scrollTo(d, section);
        d.expectText(section);
      }
      d.expectNoText('อุปสงค์–อุปทาน');
      d.expectNoText('ผู้สอนยอดนิยม (แมตช์สำเร็จมากที่สุด)');
      d.expectNoText('ทำไมต้องดู:');
    });

    appTest('ผลการจับคู่แสดงจำนวนและอัตราการยืนยันถูกต้อง', (d) async {
      await openReport(d);
      await scrollTo(d, 'ยืนยันจับคู่แล้ว');
      d.expectText('คำขอทั้งหมด');
      final confirmedCard = find.ancestor(
        of: find.text('ยืนยันจับคู่แล้ว'),
        matching: find.byType(Container),
      );
      expect(
        find.descendant(of: confirmedCard.first, matching: find.text('3')),
        findsOneWidget,
      );
      d.expectText('75.0%');
      d.expectText('อัตราการยืนยันคำขอ');
      d.expectNoText('อัตราสำเร็จ');
      d.expectNoText('คะแนนเข้ากันเฉลี่ย');
    });

    appTest('จำนวนผู้ใช้งานแสดงเฉพาะยอดบัญชีปัจจุบัน', (d) async {
      await openReport(d);
      d.expectText('นักเรียนทั้งหมด');
      d.expectText('12');
      d.expectText('ติวเตอร์ทั้งหมด');
      d.expectText('ข้อมูล ณ ตอนนี้');
      d.expectNoText('นักเรียนออนไลน์ตอนนี้');
      d.expectNoText('ติวเตอร์ออนไลน์ตอนนี้');
    });

    appTest('กดข้อมูลเพิ่มเติมแล้วแสดงวิธีอ่านและสิ่งที่ควรทำ', (d) async {
      await openReport(d);
      d.expectNoText('วิธีอ่านและสิ่งที่ควรทำ');
      await d.t.tap(find.byIcon(Icons.info_outline).first);
      await d.settle(300);
      d.expectText('วิธีอ่านและสิ่งที่ควรทำ');
      expect(
        find.textContaining('ไม่เปลี่ยนตามช่วงวันที่ที่เลือก'),
        findsOneWidget,
      );
      await d.t.tap(find.byIcon(Icons.expand_less).first);
      await d.settle(300);
      d.expectNoText('วิธีอ่านและสิ่งที่ควรทำ');
    });

    appTest('วิชาที่ขาดผู้สอนแสดงจำนวนที่อ่านตรงไปตรงมา', (d) async {
      await openReport(d);
      await scrollTo(d, 'จำนวนผู้สอนที่ยังขาดในแต่ละวิชา');
      d.expectText('เคมี');
      d.expectText('ผู้เรียน 4 คน • ผู้สอน 0 คน');
      d.expectText('ยังขาด 4 คน');
      d.expectText('มีผู้สอนเพียงพอ');
    });

    appTest('การติดต่อหลังจับคู่แสดงคู่ที่เริ่มและยังไม่เริ่มสนทนา', (d) async {
      await openReport(d);
      await scrollTo(d, 'คู่ที่ยังไม่เริ่มสนทนา');
      d.expectText('คู่ที่เริ่มสนทนาแล้ว');
      final card = find.ancestor(
        of: find.text('คู่ที่ยังไม่เริ่มสนทนา'),
        matching: find.byType(Container),
      );
      expect(
        find.descendant(of: card.first, matching: find.text('1')),
        findsOneWidget,
      );
      d.expectNoText('ข้อความทั้งหมด');
      d.expectText('66.7%');
    });

    appTest('ไม่มีคำขอที่ตัดสินแล้วแสดงคำอธิบายแทน 0%', (d) async {
      d.be.report = {
        ...d.be.report,
        'total_matches': 2,
        'match_status_counts': {'pending': 2, 'confirmed': 0, 'rejected': 0},
        'confirmed_matches': 0,
        'decided_matches': 0,
        'success_rate': null,
        'rejection_rate': null,
        'confirmed_with_chat_count': 0,
        'chat_rooms_silent': 0,
        'confirmed_with_chat_rate': null,
      };
      await openReport(d);
      await scrollTo(d, 'อัตราการยืนยันคำขอ');
      d.expectText('อัตราการยืนยันคำขอ');
      d.expectText(
        'ยังไม่มีคำขอที่ได้รับการยืนยันหรือปฏิเสธ จึงยังคำนวณอัตราการยืนยันไม่ได้',
      );
      await scrollTo(d, 'การติดต่อหลังจับคู่');
      d.expectText(
        'ยังไม่มีคู่ที่ยืนยันการจับคู่ในช่วงนี้ จึงยังคำนวณอัตราการเริ่มสนทนาไม่ได้',
      );
      d.expectNoText('0.0%');
    });

    appTest('ข้อมูลว่างทุกส่วนแสดงข้อความอธิบายและไม่ล่ม', (d) async {
      d.be.report = {
        ...d.be.report,
        'total_matches': 0,
        'match_status_counts': {'pending': 0, 'confirmed': 0, 'rejected': 0},
        'confirmed_matches': 0,
        'success_rate': null,
        'top_subjects': [],
        'subject_gaps': [],
        'active_learn_count': 0,
        'active_teach_count': 0,
        'chat_rooms': 0,
        'confirmed_with_chat_count': 0,
        'chat_rooms_silent': 0,
        'confirmed_with_chat_rate': null,
      };
      await openReport(d);
      await scrollTo(d, 'ตอนนี้ยังไม่มีผู้เรียนที่กำลังหาผู้สอน');
      await scrollTo(d, 'ยังไม่มีการจับคู่ที่ได้รับการยืนยันในช่วงนี้');
    });

    appTest('เซิร์ฟเวอร์ล่มแสดงข้อผิดพลาดและลองใหม่ได้', (d) async {
      d.be.failures['api_admin.php'] = 'error500';
      await d.login('admin');
      await d.tapText('รายงาน');
      d.expectText('เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ กรุณาลองใหม่');
      d.be.failures.clear();
      await d.tapText('ลองใหม่');
      d.expectText('จำนวนผู้ใช้งาน');
    });

    appTest('จอ 320×568 แสดงทุกส่วนและกางคำแนะนำได้โดยไม่ล้น', (d) async {
      await openReport(d);
      for (final section in sections) {
        await scrollTo(d, section);
      }
      await d.t.tap(find.byIcon(Icons.info_outline).last);
      await d.settle(300);
      d.expectText('วิธีอ่านและสิ่งที่ควรทำ');
    }, size: const Size(320, 568));

    appTest('ตัวอักษรใหญ่ 1.6 เท่าไม่ล้น', (d) async {
      await openReport(d);
      for (final section in sections) {
        await scrollTo(d, section);
      }
    }, textScale: 1.6);
  });
}
