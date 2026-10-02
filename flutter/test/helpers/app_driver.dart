import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:project/app_nav_bar.dart';
import 'package:project/StudentDashboard.dart';
import 'package:project/TutorDashboard.dart';
import 'package:project/main.dart';

import 'fake_backend.dart';

bool _fontsLoaded = false;

/// flutter_test วาดตัวอักษรทุกตัวด้วยฟอนต์ Ahem (กว้างเป็นสี่เหลี่ยม) ทำให้เกิด overflow ปลอม
/// จึงโหลดฟอนต์ไทยจริงของ Windows มาใช้แทน เพื่อให้ขนาดข้อความใกล้เคียงแอปจริง
Future<void> _loadRealFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final file = File('C:/Windows/Fonts/LeelawUI.ttf');
  if (!file.existsSync()) return;
  final bytes = file.readAsBytesSync();
  for (final family in ['Roboto', 'Segoe UI', '.SF UI Text']) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

/// เทสต์แบบผู้ใช้จริง: รันแอปทั้งแอป (MyApp) โดยปลอม HTTP ด้วย FakeBackend
void appTest(
  String description,
  Future<void> Function(AppDriver d) body, {
  Size size = const Size(412, 915),
  double textScale = 1.0,
  Set<String> knownOverflows = const {},
}) {
  testWidgets(description, (tester) async {
    await _loadRealFonts();
    final be = FakeBackend();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final d = AppDriver(tester, be);
    // เก็บ RenderFlex overflow ไว้ตรวจตอนจบ (ไม่ให้ overflow ของหน้าหนึ่งบังผลของหน้าอื่น)
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.toString();
      if (text.contains('overflowed by')) {
        final at = text.indexOf('error-causing');
        final m = RegExp(
          r'([A-Za-z_]+\.dart:\d+)',
        ).firstMatch(at >= 0 ? text.substring(at) : text);
        d.overflows.add(m?.group(1) ?? 'unknown');
      } else {
        original?.call(details);
      }
    };
    addTearDown(() => FlutterError.onError = original);
    await http.runWithClient(() async {
      await d.launch();
      await body(d);
      final unexpected = d.overflows
          .where((o) => !knownOverflows.any(o.contains))
          .toSet();
      expect(
        unexpected,
        isEmpty,
        reason: 'มี RenderFlex overflow (เนื้อหาล้นจอ) ที่: $unexpected',
      );
      // ปิดแอป เพื่อให้ timer/animation ที่ค้างถูกเก็บก่อนจบเทสต์
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
    }, () => be.client);
  });
}

class AppDriver {
  final WidgetTester t;
  final FakeBackend be;
  final List<String> overflows = [];
  AppDriver(this.t, this.be);

  Future<void> launch() async {
    await t.pumpWidget(const MyApp());
    await settle();
  }

  /// เดินเวลาไปข้างหน้า (ไม่ใช้ pumpAndSettle เพราะมี animation/spinner วนไม่จบ)
  Future<void> settle([int ms = 1500]) async {
    for (var i = 0; i < ms ~/ 50; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  // ── การกระทำแบบผู้ใช้ ──────────────────────────────────────────────
  Future<void> tapText(String text, {int index = 0, bool last = false}) async {
    final f = find.text(text);
    expect(f, findsWidgets, reason: 'ไม่พบข้อความ "$text" บนจอ');
    await t.tap(last ? f.last : f.at(index));
    await settle();
  }

  /// เลื่อนหน้าให้เห็นข้อความนั้นก่อนแล้วค่อยแตะ (สำหรับปุ่มที่อยู่ท้ายฟอร์มยาว ๆ)
  Future<void> tapScrolled(String text) async {
    final f = find.text(text);
    expect(f, findsWidgets, reason: 'ไม่พบข้อความ "$text"');
    FocusManager.instance.primaryFocus
        ?.unfocus(); // ผู้ใช้จริงพิมพ์เสร็จแล้วปิดคีย์บอร์ด
    await settle(300);
    await t.ensureVisible(f.first);
    await settle(600); // รอให้เลย์เอาต์นิ่งหลังเลื่อน
    await t.tap(f.first);
    await settle();
  }

  Future<void> tapIcon(IconData icon, {int index = 0}) async {
    final f = find.byIcon(icon);
    expect(f, findsWidgets, reason: 'ไม่พบไอคอน $icon บนจอ');
    await t.tap(f.at(index));
    await settle();
  }

  Future<void> login(String username, {String? password}) async {
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), username);
    await t.enterText(fields.at(1), password ?? be.goodPassword);
    // จอเล็ก: ปุ่มอาจอยู่ใต้จอ ผู้ใช้จริงต้องเลื่อนลงไปกด
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(300);
    await t.ensureVisible(find.text('เข้าสู่ระบบ').last);
    await settle(300);
    await t.tap(find.text('เข้าสู่ระบบ').last);
    await settle();
  }

  Future<void> loginStudent() => login('somchai');
  Future<void> loginTutor() => login('anucha');

  /// แตะแท็บบนแถบล่าง (ค้นเฉพาะใน AppNavBar เพื่อไม่ชนข้อความอื่น เช่น การ์ดเมนูหลัก)
  Future<void> tapTab(String label) async {
    final f = find.descendant(
      of: find.byType(AppNavBar),
      matching: find.text(label),
    );
    expect(f, findsOneWidget, reason: 'ไม่พบแท็บ "$label"');
    await t.tap(f);
    await settle();
  }

  /// กดปุ่ม back ของเครื่อง (เหมือน Android back / ท่าทางถอย)
  Future<void> systemBack() async {
    await t.binding.handlePopRoute();
    await settle();
  }

  /// กดลูกศร back บน AppBar (ถ้าไม่มีจะให้เทสต์ล้ม)
  Future<void> tapAppBarBack() async {
    final f = find.byType(BackButton).evaluate().isNotEmpty
        ? find.byType(BackButton)
        : find.byIcon(Icons.arrow_back_ios_new);
    expect(f, findsOneWidget, reason: 'ไม่มีลูกศร back บน AppBar');
    await t.tap(f);
    await settle();
  }

  // ── การตรวจสอบ ─────────────────────────────────────────────────────
  void expectText(String text, {Matcher? matcher}) =>
      expect(find.text(text), matcher ?? findsWidgets, reason: '"$text"');

  void expectNoText(String text) =>
      expect(find.text(text), findsNothing, reason: 'ไม่ควรมี "$text"');

  /// มีลูกศร back บน AppBar ของหน้าปัจจุบันหรือไม่
  bool get hasAppBarBack =>
      find.byType(BackButton).evaluate().isNotEmpty ||
      find
          .descendant(
            of: find.byType(AppBar),
            matching: find.byIcon(Icons.arrow_back_ios_new),
          )
          .evaluate()
          .isNotEmpty;

  /// จำนวนหน้า (Scaffold) ที่ซ้อนอยู่ในสแตก รวมหน้าที่ถูกบังอยู่ (ไว้ตรวจว่าไม่มีหน้าเก่าค้าง)
  int get pageCount =>
      find.byType(Scaffold, skipOffstage: false).evaluate().length;

  /// แดชบอร์ดอยู่บนสุดของสแตก (มองเห็นได้ ไม่ถูกหน้าอื่นบัง) หรือไม่
  bool get onDashboard =>
      find.byType(StudentDashboard).evaluate().isNotEmpty ||
      find.byType(TutorDashboard).evaluate().isNotEmpty;
}

extension EditProfileSteps on AppDriver {
  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> typeInto(String label, String value) async {
    final f = field(label);
    expect(f, findsOneWidget, reason: 'ไม่พบช่อง "$label"');
    await t.ensureVisible(f);
    await t.enterText(f, value);
    await t.pump();
  }

  String valueOf(String label) =>
      t.widget<TextFormField>(field(label)).controller?.text ?? '';
}
