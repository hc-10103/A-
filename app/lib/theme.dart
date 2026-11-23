// 디자인 캔버스(OLPARK RUN Flutter 앱)의 색·글꼴을 그대로 옮긴 테마.
import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class C {
  static const ground = Color(0xFFF7F7F4);
  static const ink = Color(0xFF111613);
  static const muted = Color(0xFF5D6862); // ground 위 대비 5.6:1
  static const body = Color(0xFF3F4A44);
  static const line = Color(0xFFE2E6E3);
  static const chipLine = Color(0xFFD5DCD7);
  static const soft = Color(0xFFF0F3F1);
  static const brand = Color(0xFF0F3D2A); // 짙은 공원 초록
  static const brandSub = Color(0xFFB9CFC2);
  static const lime = Color(0xFFC8F24A);
  static const onLime = Color(0xFF0B1A10);
  static const route = Color(0xFF0F6B42);
  static const demo = Color(0xFF5B3FB0);
  static const dangerBg = Color(0xFFFBE2DE);
  static const dangerFg = Color(0xFF5C1A12);
  static const dangerIcon = Color(0xFFB3261E);
  static const infoBg = Color(0xFFE3ECF7);
  static const infoFg = Color(0xFF24507E);
  static const warnBg = Color(0xFFFBEFD6);
  static const warnFg = Color(0xFF74490A);
  static const goodBg = Color(0xFFE2F2E9);
  static const goodFg = Color(0xFF145534);
}

/// 테스트에서는 글꼴을 내려받지 않도록 false 로 둔다.
bool useGoogleFonts = true;

/// 큰 숫자용 굵은 기울임 글꼴 (거리·시간·점수)
TextStyle numStyle(double size, {Color? color}) => (useGoogleFonts ? GoogleFonts.archivo : TextStyle.new)(
      fontSize: size,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      height: 1,
      letterSpacing: -0.02 * size,
      color: color,
    );

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: C.brand, primary: C.brand, surface: C.ground),
    scaffoldBackgroundColor: C.ground,
  );
  final text = (useGoogleFonts ? GoogleFonts.notoSansKrTextTheme(base.textTheme) : base.textTheme).apply(bodyColor: C.ink, displayColor: C.ink);
  return base.copyWith(
    textTheme: text,
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: C.goodBg,
      height: 72,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// 등급별 배지 색
({Color bg, Color fg}) ratingColors(String rating) => switch (rating) {
      '좋음' => (bg: C.lime, fg: C.onLime),
      '보통' => (bg: C.infoBg, fg: C.infoFg),
      '주의' => (bg: C.warnBg, fg: C.warnFg),
      _ => (bg: C.dangerBg, fg: C.dangerFg),
    };
