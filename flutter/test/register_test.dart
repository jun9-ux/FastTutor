import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_driver.dart';

Finder hintField(String hint) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == hint,
);

Future<void> openRegister(AppDriver d) async {
  await d.t.ensureVisible(find.text('สมัครสมาชิก').last);
  await d.settle(300);
  await d.tapText('สมัครสมาชิก', last: true);
}

Future<void> fillBasics(AppDriver d) async {
  await d.t.enterText(hintField('ชื่อ'), 'ทดสอบ');
  await d.t.enterText(hintField('นามสกุล'), 'สมัคร');
  await d.t.ensureVisible(hintField('ชื่อผู้ใช้'));
  await d.t.enterText(hintField('ชื่อผู้ใช้'), 'newuser');
  await d.t.ensureVisible(hintField('รหัสผ่าน'));
  await d.t.enterText(hintField('รหัสผ่าน'), 'Passw0rd!');
  FocusManager.instance.primaryFocus?.unfocus();
  await d.settle(300);
}

void main() {
  group('A. สมัครสมาชิก: วันเกิดแทนอายุ', () {
    appTest('ฟอร์มมีช่อง "วันเกิด" และไม่มีช่องอายุที่พิมพ์เอง', (d) async {
      await openRegister(d);
      expect(hintField('วันเกิด'), findsOneWidget);
      expect(hintField('อายุ'), findsNothing);
    });

    appTest('ยังไม่เลือกวันเกิด: ขึ้นข้อความเตือน ไม่ส่งสมัคร', (d) async {
      await openRegister(d);
      await fillBasics(d);
      await d.tapScrolled('สมัครสมาชิก');
      d.expectText('กรุณาเลือกวันเกิด');
      expect(d.be.count('register.php'), 0);
    });

    appTest('เลือกวันเกิด: ช่องแสดงวันที่+อายุ และส่ง birth_date ตอนสมัคร', (
      d,
    ) async {
      await openRegister(d);
      await fillBasics(d);
      await d.t.ensureVisible(hintField('วันเกิด'));
      await d.t.tap(hintField('วันเกิด'));
      await d.settle();
      d.expectText('เลือกวันเกิด');
      await d.t.tap(find.text('10').last);
      await d.settle(300);
      await d.tapText('ตกลง');
      final shown = d.t
          .widget<TextField>(hintField('วันเกิด'))
          .controller!
          .text;
      expect(shown, startsWith('10/')); // dd/MM/yyyy → วันที่ 10
      expect(shown, contains('อายุ'));
      await d.tapScrolled('สมัครสมาชิก');
      final call = d.be.callsTo('register.php').single;
      final birth = call['body']['birth_date'] as String;
      expect(RegExp(r'^\d{4}-\d{2}-10$').hasMatch(birth), isTrue);
      expect(call['body'].containsKey('age'), isFalse);
    });
  });
}
