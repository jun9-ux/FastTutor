import 'package:flutter_test/flutter_test.dart';
import 'package:project/birth_date_field.dart';

void main() {
  group('ageFromBirthDate (อายุเพิ่มเองตามวันเกิด)', () {
    final today = DateTime(2026, 9, 24);

    test('วันเกิดตรงกับวันนี้ = ครบปีพอดี', () {
      expect(ageFromBirthDate('2010-09-24', today: today), 16);
    });

    test('ก่อนวันเกิด 1 วัน ยังไม่ครบปี', () {
      expect(ageFromBirthDate('2010-09-25', today: today), 15);
      expect(ageFromBirthDate('2010-10-01', today: today), 15);
    });

    test('หลังวันเกิด 1 วัน ครบปีแล้ว', () {
      expect(ageFromBirthDate('2010-09-23', today: today), 16);
      expect(ageFromBirthDate('2010-01-01', today: today), 16);
    });

    test('อายุเพิ่มขึ้น 1 เมื่อข้ามวันเกิดของปีถัดไป', () {
      expect(ageFromBirthDate('2010-09-24', today: DateTime(2027, 9, 23)), 16);
      expect(ageFromBirthDate('2010-09-24', today: DateTime(2027, 9, 24)), 17);
    });

    test('เกิด 29 ก.พ.: ปีที่ไม่มี 29 ก.พ. ครบปีในวันที่ 1 มี.ค.', () {
      expect(ageFromBirthDate('2004-02-29', today: DateTime(2025, 2, 28)), 20);
      expect(ageFromBirthDate('2004-02-29', today: DateTime(2025, 3, 1)), 21);
      expect(ageFromBirthDate('2004-02-29', today: DateTime(2028, 2, 29)), 24);
    });

    test('วันเกิดในอนาคต/ว่าง/ผิดรูปแบบ/วันที่ไม่มีจริง = null', () {
      expect(ageFromBirthDate('2026-09-25', today: today), isNull);
      expect(ageFromBirthDate(null, today: today), isNull);
      expect(ageFromBirthDate('', today: today), isNull);
      expect(ageFromBirthDate('24/09/2010', today: today), isNull);
      expect(ageFromBirthDate('2023-02-29', today: today), isNull);
      expect(ageFromBirthDate('2010-13-01', today: today), isNull);
    });

    test('รับรูปแบบที่มีเวลาต่อท้ายจาก DB ได้', () {
      expect(ageFromBirthDate('2010-09-24 00:00:00', today: today), 16);
    });

    test('รับ DateTime ตรง ๆ ได้', () {
      expect(ageFromBirthDate(DateTime(2000, 1, 1), today: today), 26);
    });
  });

  group('แปลงรูปแบบวันที่', () {
    test('ISO และรูปแบบแสดงผล', () {
      final d = DateTime(2010, 3, 7);
      expect(birthDateToIso(d), '2010-03-07');
      expect(birthDateToDisplay(d), '07/03/2010');
      expect(parseBirthDate('2010-03-07'), d);
    });
  });
}
