import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_driver.dart';

void main() {
  group('A. เข้าสู่ระบบ', () {
    appTest('ผู้เรียนล็อกอินแล้วเข้าแดชบอร์ดผู้เรียน', (d) async {
      d.expectText('เข้าสู่ระบบ');
      await d.loginStudent();
      d.expectText('แดชบอร์ดผู้เรียน');
      expect(d.onDashboard, isTrue);
    });

    appTest('ติวเตอร์ล็อกอินแล้วเข้าแดชบอร์ดผู้สอน', (d) async {
      await d.loginTutor();
      d.expectText('แดชบอร์ดผู้สอน');
    });

    appTest('รหัสผ่านผิด: ไม่เข้าระบบ และยังอยู่หน้าล็อกอิน', (d) async {
      await d.login('somchai', password: 'wrong');
      expect(d.onDashboard, isFalse);
      d.expectText('เข้าสู่ระบบ');
    });
  });
}
