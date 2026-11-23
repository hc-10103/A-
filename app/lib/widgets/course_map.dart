// 코스 개략도. 실제 지도·좌표가 아니므로 항상 '개략도' 배지를 함께 보여준다.
// 공식 좌표가 생기면 이 위젯을 flutter_map / google_maps_flutter 로 바꾸고 같은 경로 스타일을 얹는다.
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../course_route.dart';
import '../models.dart';
import '../theme.dart';

enum MapTone { light, dark, faint }

class CourseMap extends StatelessWidget {
  const CourseMap({
    super.key,
    required this.course,
    this.tone = MapTone.light,
    this.labels = true,
    this.fit = BoxFit.cover,
    this.badge = true,
    this.badgeAlignment = Alignment.topRight,
    this.badgePadding = const EdgeInsets.all(12),
  });

  final Course course;
  final MapTone tone;
  final bool labels;
  final BoxFit fit;
  final bool badge;
  final Alignment badgeAlignment;
  final EdgeInsets badgePadding;

  @override
  Widget build(BuildContext context) {
    final route = routeOf(course);
    final summary = route.waypoints.isNotEmpty
        ? '${course.name} 개략도: ${route.waypoints.join(', ')} 순서로 도는 경로'
        : '${course.name} 개략도: ${route.note ?? '경로 정보 없음'}';
    return Semantics(
      label: summary,
      image: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: FittedBox(
              fit: fit,
              child: SizedBox.fromSize(
                size: schematicSize,
                child: CustomPaint(painter: _MapPainter(route, tone, labels)),
              ),
            ),
          ),
          if (badge)
            Align(
              alignment: badgeAlignment,
              child: Padding(
                padding: badgePadding,
                child: _Badge(dark: tone == MapTone.dark),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: dark ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '개략도 · 위치·축척은 실제와 달라요',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: dark ? Colors.white : const Color(0xFF3D4842)),
        ),
      );
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.route, this.tone, this.labels);

  final CourseRoute route;
  final MapTone tone;
  final bool labels;

  bool get dark => tone == MapTone.dark;

  @override
  void paint(Canvas canvas, Size size) {
    final park = dark ? const Color(0xFF16492F) : const Color(0xFFD3E3CA);
    final fort = dark ? const Color(0xFF1B5537) : const Color(0xFFC2D9B6);
    final water = dark ? const Color(0xFF1A4A52) : const Color(0xFFC7DDEA);
    final routeColor = dark ? C.lime : C.route;
    final routeOpacity = tone == MapTone.faint ? 0.6 : 1.0;

    canvas.drawRect(Offset.zero & size, Paint()..color = dark ? C.brand : const Color(0xFFE4ECDF));
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(18, 72, 354, 392), const Radius.circular(72)),
      Paint()..color = park,
    );
    _fortress(canvas, Paint()..color = fort);
    canvas.drawOval(Rect.fromCenter(center: const Offset(342, 300), width: 48, height: 68), Paint()..color = water);
    canvas.drawPath(
      Path()
        ..moveTo(30, 102)
        ..quadraticBezierTo(100, 84, 176, 108),
      Paint()
        ..color = water
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );
    if (labels) _text(canvas, '몽촌토성', const Offset(195, 226), 12, dark ? Colors.white70 : const Color(0xFF5E7A52));

    final stroke = Paint()
      ..color = routeColor.withValues(alpha: routeOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    switch (route.ring) {
      case RingShape.fortress:
        _fortress(canvas, stroke);
      case RingShape.outer:
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(34, 88, 322, 360), const Radius.circular(62)), stroke);
      case null:
        break;
    }

    if (route.stops.length >= 2) {
      final path = Path()..moveTo(route.stops.first.position.dx, route.stops.first.position.dy);
      for (final s in route.stops.skip(1)) {
        path.lineTo(s.position.dx, s.position.dy);
      }
      if (tone != MapTone.faint) {
        canvas.drawPath(path, Paint()
          ..color = dark ? C.brand : Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round);
      }
      canvas.drawPath(path, stroke);
    }

    if (tone == MapTone.faint) return;
    _markers(canvas);

    if (!route.drawable) {
      _text(canvas, '이 코스는 개략 경로 정보가 없어요', const Offset(195, 250), 14, dark ? Colors.white : C.muted);
    }
  }

  void _fortress(Canvas canvas, Paint paint) {
    canvas.save();
    canvas.translate(195, 255);
    canvas.rotate(-14 * math.pi / 180);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 204, height: 160), paint);
    canvas.restore();
  }

  void _markers(Canvas canvas) {
    final stops = route.stops;
    if (stops.isEmpty) return;
    // 같은 장소를 두 번 지나면 번호를 합친다(2·6). 출발지로 돌아오는 마지막 지점은 출발 표시에 합친다.
    final byName = <String, List<int>>{};
    final pos = <String, Offset>{};
    for (var i = 0; i < stops.length; i++) {
      final s = stops[i];
      final isReturn = i == stops.length - 1 && stops.length > 1 && s.name == stops.first.name;
      if (isReturn) continue;
      byName.putIfAbsent(s.name, () => []).add(s.order);
      pos[s.name] = s.position;
    }
    for (final entry in byName.entries) {
      final p = pos[entry.key]!;
      final start = entry.key == stops.first.name;
      final r = start ? 15.0 : 12.0;
      if (start) {
        canvas.drawCircle(p, r, Paint()..color = C.lime);
        canvas.drawCircle(p, r, Paint()
          ..color = C.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
      } else {
        canvas.drawCircle(p, r, Paint()..color = dark ? Colors.white : C.ink);
      }
      _text(canvas, start ? 'S' : entry.value.join('·'), p, 11, start ? C.onLime : (dark ? C.ink : Colors.white), bold: true);
      if (labels) {
        _text(canvas, entry.key, p + Offset(0, p.dy > 300 ? 26 : -24), 11, dark ? Colors.white : const Color(0xFF24302A),
            bold: true, halo: dark ? C.brand : const Color(0xFFE9F1E4));
      }
    }
  }

  void _text(Canvas canvas, String text, Offset center, double size, Color color, {bool bold = false, Color? halo}) {
    final style = TextStyle(fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: color);
    if (halo != null) {
      final h = TextPainter(
        text: TextSpan(text: text, style: style.copyWith(foreground: Paint()
          ..color = halo
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4)),
        textDirection: TextDirection.ltr,
      )..layout();
      h.paint(canvas, center - Offset(h.width / 2, h.height / 2));
    }
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.route != route || old.tone != tone || old.labels != labels;
}
