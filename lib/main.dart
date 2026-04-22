import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

import 'screens/chat_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';

@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  final SendPort? send = IsolateNameServer.lookupPortByName(
    'lilly_downloader_send_port',
  );
  send?.send([id, status, progress]);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterDownloader.initialize(debug: false, ignoreSsl: false);
  FlutterDownloader.registerCallback(downloadCallback);

  runApp(const LillyApp());
}

class LillyApp extends StatelessWidget {
  const LillyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const blush = Color(0xFFF2C8D5);
    const rose = Color(0xFFC88298);
    const cream = Color(0xFFFFFBF7);
    const olive = Color(0xFF99A35B);
    const ink = Color(0xFF473241);
    const muted = Color(0xFF776470);
    const stroke = Color(0xFFEAC7D2);

    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: rose,
      onPrimary: Colors.white,
      secondary: olive,
      onSecondary: Colors.white,
      tertiary: blush,
      onTertiary: ink,
      error: Color(0xFFB42318),
      onError: Colors.white,
      surface: cream,
      onSurface: ink,
      surfaceContainerHighest: Color(0xFFF7E7ED),
      onSurfaceVariant: muted,
      outline: stroke,
      outlineVariant: Color(0xFFF0D8E0),
      shadow: Color(0x22000000),
      scrim: Color(0x66000000),
      inverseSurface: ink,
      onInverseSurface: cream,
      inversePrimary: Color(0xFFF5D6E0),
    );

    return MaterialApp(
      title: 'Lilly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: cream,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: ink,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: ink,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withValues(alpha: 0.92),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: const BorderSide(color: stroke),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: rose,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: ink,
            side: const BorderSide(color: stroke),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.9),
          hintStyle: const TextStyle(color: muted),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: stroke),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: stroke),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: rose, width: 1.5),
          ),
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFFFFFBF8),
          surfaceTintColor: Colors.transparent,
        ),
        dividerColor: const Color(0xFFF0D8E0),
      ),
      initialRoute: SplashScreen.routeName,
      routes: {
        SplashScreen.routeName: (_) => const SplashScreen(),
        ChatScreen.routeName: (_) => const ChatScreen(),
        SettingsScreen.routeName: (_) => const SettingsScreen(),
      },
    );
  }
}
