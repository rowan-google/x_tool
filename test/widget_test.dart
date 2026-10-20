import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:x_tool/crypto/crypto_service.dart';
import 'package:x_tool/ui/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen smoke test and Encrypt/Decrypt UI flow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Provide fast parameter service for widget testing
    final testCryptoService = const CryptoService(
      useIsolate: false,
      defaultParameters: CryptoParameters(
        memoryKiB: 64,
        iterations: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(cryptoService: testCryptoService),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial branding and components
    expect(find.text('x_tool'), findsOneWidget);
    expect(find.text('纯本地 · 零泄露'), findsOneWidget);
    expect(find.textContaining('文本加密'), findsOneWidget);
    expect(find.textContaining('文本解密'), findsOneWidget);

    // Test Empty password validation
    final encryptBtn = find.text('立即加密并生成密文');
    await tester.ensureVisible(encryptBtn);
    await tester.tap(encryptBtn);
    await tester.pump();
    expect(find.textContaining('请输入'), findsOneWidget);

    // Test Load Sample Note
    final sampleBtn = find.text('示例文本');
    expect(sampleBtn, findsOneWidget);
    await tester.tap(sampleBtn);
    await tester.pump();
    expect(find.textContaining('个人机密财务备忘录'), findsOneWidget);

    // Trigger encrypt with sample note
    await tester.ensureVisible(encryptBtn);
    await tester.tap(encryptBtn);
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    // Verify output has been generated
    expect(find.textContaining('加密完成！密文已生成'), findsOneWidget);
    final outputField = find.byType(TextField).last;
    final encryptedText = tester.widget<TextField>(outputField).controller!.text;
    expect(encryptedText.contains('-----BEGIN XTOOL ENCRYPTED MESSAGE-----'), isTrue);

    // Switch to decrypt mode
    final decryptTab = find.textContaining('文本解密');
    await tester.ensureVisible(decryptTab);
    await tester.tap(decryptTab);
    await tester.pump();

    // Input encrypted text and correct password
    final inputField = find.byType(TextField).first;
    final passwordField = find.byType(TextField).at(1);
    await tester.enterText(inputField, encryptedText);
    await tester.enterText(passwordField, 'DemoSafePass2026!');
    await tester.pump();

    // Trigger decrypt
    final decryptBtn = find.text('立即解密还原明文');
    await tester.ensureVisible(decryptBtn);
    await tester.tap(decryptBtn);
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    // Verify output matches original plaintext
    expect(find.textContaining('解密成功！原文已安全还原'), findsOneWidget);
    final decryptedText = tester.widget<TextField>(outputField).controller!.text;
    expect(decryptedText.contains('个人机密财务备忘录'), isTrue);

    // Test Clear All
    final clearAllBtn = find.byIcon(Icons.delete_sweep_outlined);
    await tester.tap(clearAllBtn);
    await tester.pump();

    expect(tester.widget<TextField>(inputField).controller!.text, '');
    expect(tester.widget<TextField>(passwordField).controller!.text, '');
    expect(tester.widget<TextField>(outputField).controller!.text, '');
  });

  testWidgets('Password generator dialog test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final genBtn = find.text('随机强口令');
    expect(genBtn, findsOneWidget);
    await tester.tap(genBtn);
    await tester.pumpAndSettle();

    expect(find.text('安全强口令生成器'), findsOneWidget);
    expect(find.text('高熵复杂密码'), findsOneWidget);
    expect(find.text('易记短语 (Diceware)'), findsOneWidget);

    final fillBtn = find.text('填入密码输入框');
    expect(fillBtn, findsOneWidget);
    await tester.tap(fillBtn);
    await tester.pumpAndSettle();

    // Password field should now have text
    final passwordField = find.byType(TextField).at(1);
    final text = tester.widget<TextField>(passwordField).controller!.text;
    expect(text.isNotEmpty, isTrue);
  });

  testWidgets('Mobile viewport layout test (no overlap on small screen)', (WidgetTester tester) async {
    // Set standard mobile screen size (360 x 640)
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and badge exist cleanly
    expect(find.text('x_tool'), findsOneWidget);
    expect(find.text('纯本地 · 零泄露'), findsOneWidget);
    expect(find.text('文本加密'), findsOneWidget);
    expect(find.text('文本解密'), findsOneWidget);

    // Verify action buttons in AppBar are hit-testable and don't collide
    final infoBtn = find.byIcon(Icons.info_outline_rounded);
    expect(infoBtn, findsOneWidget);
    await tester.tap(infoBtn);
    await tester.pumpAndSettle();
    expect(find.text('安全规范与边界说明'), findsOneWidget);

    // Close dialog
    await tester.tap(find.text('我知道了'));
    await tester.pumpAndSettle();
  });
}
