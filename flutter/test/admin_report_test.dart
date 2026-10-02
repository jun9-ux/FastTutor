import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_driver.dart';

/// หน้ารายงานของแอดมิน: แสดงอะไร และอธิบายเหตุผล ("ทำไมต้องดู") ให้แอดมินเห็น
Future<void> openReport(AppDriver d) async {
  await d.login('admin');
  await d.tapText('รายงาน');
}

const sections = [
  'ภาพรวมผู้ใช้',
  'ประสิทธิภาพการจับคู่',
  'อุปสงค์–อุปทาน',
  'วิชายอดนิยม (แมตช์มากที่สุด)',
  'ผู้สอนยอดนิยม (แมตช์สำเร็จมากที่สุด)',
  'การใช้งานแชท',
];

/// เลื่อนรายการรายงานลงจนเห็นข้อความนั้น (เหมือนผู้ใช้เลื่อนดู; ListView สร้างรายการแบบขี้เกียจ
/// จึงเลื่อนทีละช่วงจนข้อความปรากฏ)
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
    appTest('แสดงครบ 6 ส่วน แต่ละส่วนมี "ทำไมต้องดู"', (d) async {
      await openReport(d);
      for (final s in sections) {
        await scrollTo(d, s);
        d.expectText(s);
        // ทุกส่วนต้องมีบรรทัดเหตุผลของตัวเองอยู่ใต้หัวข้อ
        expect(find.textContaining('ทำไมต้องดู'), findsWidgets, reason: s);
      }
    });

    appTest('ตัวเลขถูกต้อง: สำเร็จ 3 (ไม่ใช่ผลรวม 6), อัตราสำเร็จ 75%', (
      d,
    ) async {
      await openReport(d);
      await scrollTo(d, 'จับคู่สำเร็จ');
      d.expectText('คำขอจับคู่ทั้งหมด');
      // การ์ด "จับคู่สำเร็จ" ต้องขึ้นจำนวนที่ยืนยัน ไม่ใช่คำขอทั้งหมด
      final successCard = find.ancestor(
        of: find.text('จับคู่สำเร็จ'),
        matching: find.byType(Container),
      );
      expect(
        find.descendant(of: successCard.first, matching: find.text('3')),
        findsOneWidget,
      );
      d.expectText('75.0%');
      d.expectNoText('88.5%');
      d.expectNoText('คะแนนเข้ากันเฉลี่ย'); // เอาออกตามคำขอ
      d.expectNoText('แมตช์สำเร็จทั้งหมด'); // ป้ายเดิมที่ตั้งชื่อผิด
    });

    appTest('ภาพรวมผู้ใช้: นักเรียน/ติวเตอร์/ออนไลน์ + ป้ายข้อมูลปัจจุบัน', (
      d,
    ) async {
      await openReport(d);
      d.expectText('นักเรียนทั้งหมด');
      d.expectText('12');
      d.expectText('ติวเตอร์ทั้งหมด');
      d.expectText('นักเรียนออนไลน์ตอนนี้');
      d.expectText('ข้อมูลปัจจุบัน');
    });

    appTest('กดⓘ: กางคำแนะนำ "ควรทำอะไรต่อ" และกดซ้ำซ่อน', (d) async {
      await openReport(d);
      d.expectNoText('อ่านผลอย่างไร / ควรทำอะไรต่อ');
      await d.t.tap(find.byIcon(Icons.info_outline).first);
      await d.settle(300);
      d.expectText('อ่านผลอย่างไร / ควรทำอะไรต่อ');
      expect(
        find.textContaining('ไม่ขึ้นกับช่วงวันที่ที่เลือก'),
        findsOneWidget,
      );
      await d.t.tap(find.byIcon(Icons.expand_less).first);
      await d.settle(300);
      d.expectNoText('อ่านผลอย่างไร / ควรทำอะไรต่อ');
    });

    appTest('อุปสงค์–อุปทาน: วิชาที่ขาดผู้สอนแสดงส่วนต่าง', (d) async {
      await openReport(d);
      await scrollTo(d, 'วิชาที่ผู้เรียนต้องการมากกว่าผู้สอน');
      d.expectText('เคมี');
      d.expectText('ต้องการเรียน 4 • ผู้สอน 0');
      d.expectText('ขาดผู้สอน 4');
      d.expectText('ผู้สอนเพียงพอ');
    });

    appTest(
      'การใช้งานแชท: แสดง "ห้องแชทที่ไม่มีการคุยกัน" แทนจำนวนข้อความทั้งหมด',
      (d) async {
        await openReport(d);
        await scrollTo(d, 'ห้องแชทที่ไม่มีการคุยกัน');
        d.expectText('ห้องแชทที่ไม่มีการคุยกัน');
        final card = find.ancestor(
          of: find.text('ห้องแชทที่ไม่มีการคุยกัน'),
          matching: find.byType(Container),
        );
        expect(
          find.descendant(of: card.first, matching: find.text('1')),
          findsOneWidget,
          reason: 'ยืนยัน 3 ห้อง คุยกัน 2 ห้อง ต้องเหลือไม่คุย 1 ห้อง',
        );
        d.expectNoText('ข้อความทั้งหมด');
        d.expectText('66.7%');
      },
    );

    appTest('ไม่มีคำขอที่ตัดสินแล้ว: แสดง "-" พร้อมคำอธิบาย ไม่ใช่ 0%', (
      d,
    ) async {
      d.be.report = {
        ...d.be.report,
        'total_matches': 2,
        'match_status_counts': {'pending': 2, 'confirmed': 0, 'rejected': 0},
        'confirmed_matches': 0,
        'decided_matches': 0,
        'success_rate': null,
        'rejection_rate': null,
        'avg_match_score': null,
        'confirmed_with_chat_rate': null,
      };
      await openReport(d);
      d.expectText('อัตราสำเร็จ');
      d.expectText(
        'ยังไม่มีคำขอที่ตัดสินแล้ว (สำเร็จ/ปฏิเสธ) ในช่วงนี้ จึงยังคำนวณอัตราสำเร็จไม่ได้',
      );
      await scrollTo(d, 'การใช้งานแชท');
      d.expectText('ยังไม่มีแมตช์ที่ยืนยันในช่วงนี้ จึงยังคำนวณสัดส่วนไม่ได้');
      d.expectNoText('0.0%');
    });

    appTest('ข้อมูลว่างทั้งหมด: ทุกส่วนมีข้อความอธิบาย ไม่ล่ม', (d) async {
      d.be.report = {
        ...d.be.report,
        'total_matches': 0,
        'match_status_counts': {'pending': 0, 'confirmed': 0, 'rejected': 0},
        'confirmed_matches': 0,
        'success_rate': null,
        'avg_match_score': null,
        'top_subjects': [],
        'top_tutors': [],
        'subject_gaps': [],
        'active_learn_count': 0,
        'active_teach_count': 0,
        'chat_messages': 0,
        'chat_rooms': 0,
        'chat_rooms_silent': 0,
        'confirmed_with_chat_rate': null,
      };
      await openReport(d);
      await scrollTo(d, 'ตอนนี้ไม่มีความต้องการเรียนที่เปิดอยู่');
      await scrollTo(d, 'ยังไม่มีข้อมูลการแมตช์');
      await scrollTo(d, 'ยังไม่มีข้อมูลผู้สอนที่แมตช์สำเร็จ');
    });

    appTest('เซิร์ฟเวอร์ล่ม: แสดงข้อผิดพลาด + ลองใหม่แล้วโหลดสำเร็จ', (
      d,
    ) async {
      d.be.failures['api_admin.php'] = 'error500';
      await d.login('admin');
      await d.tapText('รายงาน');
      d.expectText('เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ กรุณาลองใหม่');
      d.be.failures.clear();
      await d.tapText('ลองใหม่');
      d.expectText('ภาพรวมผู้ใช้');
    });

    appTest('จอ 320×568: ทุกส่วนไม่ล้น และกางคำแนะนำได้', (d) async {
      await openReport(d);
      for (final s in sections) {
        await scrollTo(d, s);
      }
      await d.t.tap(find.byIcon(Icons.info_outline).last);
      await d.settle(300);
      d.expectText('อ่านผลอย่างไร / ควรทำอะไรต่อ');
    }, size: const Size(320, 568));

    appTest('ตัวอักษรใหญ่ 1.6 เท่า: ไม่ล้น', (d) async {
      await openReport(d);
      for (final s in sections) {
        await scrollTo(d, s);
      }
    }, textScale: 1.6);
  });
}
