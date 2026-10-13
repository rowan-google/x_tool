import 'package:flutter/material.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const XToolApp());
}

class XToolApp extends StatelessWidget {
  const XToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'x_tool - 个人私密文本加解密',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: currentMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
