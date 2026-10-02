import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_driver.dart';

/// หน้าหลักที่ผู้ใช้ต้องเข้าถึงได้ในทุกสภาพจอ (ชื่อแท็บ → ข้อความยืนยันว่าถึงหน้านั้น)
Map<String, String> mainPages(bool student) => {
  student ? 'เพิ่มการเรียน' : 'เพิ่มการสอน': student
      ? 'เพิ่มความต้องการเรียน'
      : 'เพิ่มความต้องการสอน',
  'จับคู่': student ? 'ผู้สอนที่เหมาะสม' : 'ผู้เรียนที่เหมาะสม',
  'แชท': 'แชท',
  'แก้ไขข้อมูล': 'แก้ไขโปรไฟล์',
};

/// บั๊กที่รู้แล้ว: การ์ดเมนูหลักบนแดชบอร์ดล้นเมื่อจอแคบ/ตัวอักษรใหญ่ (ทดสอบแยกเป็นเคสเฉพาะ)
const dashCardOverflow = <String>{}; // แก้แล้ว: การ์ดเมนูหลักไม่ล้นอีก

void main() {
  group('H1. เซิร์ฟเวอร์ผิดปกติ: แอปต้องไม่ล่มและบอกผู้ใช้', () {
    for (final mode in ['error500', 'badjson']) {
      appTest('ล็อกอิน ($mode): แจ้งข้อผิดพลาด ไม่ล่ม', (d) async {
        d.be.failures['login.php'] = mode;
        await d.loginStudent();
        d.expectText('เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ กรุณาลองใหม่');
        expect(d.onDashboard, isFalse);
      });

      appTest('แดชบอร์ดดึงคะแนนไม่ได้ ($mode): ยังใช้งานได้', (d) async {
        d.be.failures['api_get_current_match.php'] = mode;
        await d.loginStudent();
        expect(d.onDashboard, isTrue);
        d.expectText('แดชบอร์ดผู้เรียน');
      });

      appTest('ประวัติความต้องการเรียน ($mode): แจ้งข้อผิดพลาด', (d) async {
        d.be.failures['api_get_learn_history.php'] = mode;
        await d.loginStudent();
        await d.tapTab('เพิ่มการเรียน');
        await d.tapText('ประวัติ');
        d.expectText('เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ กรุณาลองใหม่');
      });

      appTest('บันทึกความต้องการเรียน ($mode): แจ้งผู้ใช้ ไม่ล่ม ไม่ไปจับคู่', (
        d,
      ) async {
        d.be.failures['api_add_learn.php'] = mode;
        await d.loginStudent();
        await d.tapTab('เพิ่มการเรียน');
        await d.t.enterText(find.byType(TextField).first, 'เคมี');
        await d.tapScrolled('บันทึกความต้องการเรียน');
        d.expectNoText('ผู้สอนที่เหมาะสม');
        // ปุ่มต้องกลับมากดได้อีก (ไม่ค้างเป็น spinner) และผู้ใช้ต้องเห็นข้อความ
        d.expectText('บันทึกความต้องการเรียน');
        expect(
          find.byType(SnackBar),
          findsWidgets,
          reason: 'บันทึกล้มเหลวแต่ไม่มีข้อความแจ้งผู้ใช้',
        );
      });

      appTest('บันทึกโปรไฟล์ ($mode): แจ้งข้อผิดพลาด ยังอยู่หน้าเดิม', (
        d,
      ) async {
        d.be.failures['api_update_profile.php'] = mode;
        await d.loginStudent();
        await d.tapTab('แก้ไขข้อมูล');
        await d.typeInto('ชื่อ', 'แก้');
        await d.tapScrolled('บันทึกการเปลี่ยนแปลง');
        await d.tapText('บันทึก', last: true);
        d.expectText('แก้ไขโปรไฟล์');
        expect(d.onDashboard, isFalse);
      });

      appTest('ส่งข้อความแชท ($mode): ไม่ล่ม', (d) async {
        d.be.failures['api_send_message.php'] = mode;
        await d.loginStudent();
        await d.tapTab('แชท');
        await d.tapText('อนุชา สอนดี');
        await d.t.enterText(find.byType(TextField).last, 'ทดสอบ');
        await d.tapIcon(Icons.send);
        expect(find.byIcon(Icons.send), findsOneWidget);
      });
    }

    appTest(
      'ล็อกอินไม่ตอบ (timeout): หมุนรอแล้วแจ้งข้อผิดพลาด ปุ่มกลับมากดได้',
      (d) async {
        d.be.failures['login.php'] = 'timeout';
        await d.loginStudent();
        await d.settle(16000);
        d.expectText('เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ กรุณาลองใหม่');
        expect(
          d.t
              .widget<ElevatedButton>(find.byType(ElevatedButton).first)
              .onPressed,
          isNotNull,
          reason: 'ปุ่มเข้าสู่ระบบต้องกลับมากดได้',
        );
      },
    );

    appTest('กดปุ่มเข้าสู่ระบบ ช่องว่างทั้งคู่: ไม่ควรเปิดแดชบอร์ด', (d) async {
      await d.t.tap(find.text('เข้าสู่ระบบ').last);
      await d.settle();
      expect(d.onDashboard, isFalse);
    });

    appTest('ล็อกอินดับเบิลแท็ป: เปิดแดชบอร์ดครั้งเดียว', (d) async {
      d.be.delays['login.php'] = const Duration(milliseconds: 500);
      final fields = find.byType(TextField);
      await d.t.enterText(fields.at(0), 'somchai');
      await d.t.enterText(fields.at(1), d.be.goodPassword);
      final btn = find.text('เข้าสู่ระบบ').last;
      await d.t.tap(btn);
      await d.t.pump(const Duration(milliseconds: 50));
      await d.t.tap(find.byType(ElevatedButton).first, warnIfMissed: false);
      await d.settle(3000);
      expect(d.be.count('login.php'), 1);
      expect(d.pageCount, 2, reason: 'ต้องมีแค่ ล็อกอิน + แดชบอร์ด');
    });

    appTest('แท็บกดรัว ๆ (เร็วมาก): สแตกไม่เพี้ยน', (d) async {
      await d.loginStudent();
      for (var i = 0; i < 6; i++) {
        for (final tab in ['จับคู่', 'แชท', 'แก้ไขข้อมูล', 'เพิ่มการเรียน']) {
          final f = find.descendant(
            of: find.byType(Scaffold).last,
            matching: find.text(tab),
          );
          if (f.evaluate().isNotEmpty) {
            await d.t.tap(f.first, warnIfMissed: false);
            await d.t.pump(const Duration(milliseconds: 30));
          }
        }
      }
      await d.settle(2000);
      expect(
        d.pageCount,
        lessThanOrEqualTo(3),
        reason:
            'กดแท็บรัวแล้วหน้าซ้อนค้างเกิน (ล็อกอิน/แดชบอร์ด/แท็บ) = ${d.pageCount}',
      );
    });
  });

  group('H2. จอเล็ก 320×568 (ไม่เกิด RenderFlex overflow)', () {
    for (final student in [true, false]) {
      final who = student ? 'ผู้เรียน' : 'ผู้สอน';
      appTest(
        'หน้าล็อกอิน+แดชบอร์ด ($who)',
        (d) async {
          student ? await d.loginStudent() : await d.loginTutor();
          expect(d.onDashboard, isTrue);
        },
        size: const Size(320, 568),
      ); // ไม่ข้าม overflow: เก็บบั๊กการ์ดเมนูหลักไว้เป็นเคสที่ล้ม

      for (final e in mainPages(student).entries) {
        appTest(
          'หน้า ${e.key} ($who)',
          (d) async {
            student ? await d.loginStudent() : await d.loginTutor();
            await d.tapTab(e.key);
            d.expectText(e.value);
          },
          size: const Size(320, 568),
          knownOverflows: dashCardOverflow,
        );
      }
    }
    appTest('หน้าล็อกอิน', (d) async {
      d.expectText('เข้าสู่ระบบ');
    }, size: const Size(320, 568));
  });

  group('H3. ตัวอักษรใหญ่ (textScale 1.6) ไม่ล้นจอ', () {
    for (final student in [true, false]) {
      final who = student ? 'ผู้เรียน' : 'ผู้สอน';
      appTest('แดชบอร์ด ($who)', (d) async {
        student ? await d.loginStudent() : await d.loginTutor();
      }, textScale: 1.6);
      for (final e in mainPages(student).entries) {
        appTest(
          'หน้า ${e.key} ($who)',
          (d) async {
            student ? await d.loginStudent() : await d.loginTutor();
            await d.tapTab(e.key);
            d.expectText(e.value);
          },
          textScale: 1.6,
          knownOverflows: dashCardOverflow,
        );
      }
    }
  });
}
