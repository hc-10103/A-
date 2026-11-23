// 러닝 중: 큰 숫자 하나 + 옆으로 밀면 지도.
// 위치 추적(GPS)은 아직 연결하지 않았다. 거리·페이스는 지어내지 않고 '—'로 보여주고,
// 큰 숫자는 실제로 흐르는 시간을 쓴다. (TODO: geolocator 연동 후 거리로 교체)
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/course_map.dart';

class RunScreen extends StatefulWidget {
  const RunScreen({super.key, required this.course});
  final Course course;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  final _watch = Stopwatch()..start();
  final _pages = PageController();
  Timer? _tick;
  int _page = 0;
  bool _hint = true;

  bool get _paused => !_watch.isRunning;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pages.dispose();
    super.dispose();
  }

  void _toggle() => setState(() => _paused ? _watch.start() : _watch.stop());

  Future<void> _finish() async {
    _watch.stop();
    if (mounted) Navigator.pop(context);
  }

  Future<bool> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('러닝을 끝낼까요?'),
        content: const Text('지금까지의 시간은 저장되지 않아요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('계속 달리기')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('끝내기')),
        ],
      ),
    );
    return ok ?? false;
  }

  String get _time {
    final s = _watch.elapsed.inSeconds;
    String two(int n) => n.toString().padLeft(2, '0');
    final h = s ~/ 3600;
    return h > 0 ? '$h:${two(s % 3600 ~/ 60)}:${two(s % 60)}' : '${two(s ~/ 60)}:${two(s % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave()) _finish();
      },
      child: Scaffold(
        backgroundColor: C.brand,
        body: Stack(children: [
          PageView(
            controller: _pages,
            onPageChanged: (i) => setState(() {
              _page = i;
              _hint = false;
            }),
            children: [_statsPage(course), _mapPage(course)],
          ),
          if (_hint)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Material(
                  color: Colors.white,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                    child: Row(children: [
                      const Icon(Icons.swipe, size: 28, color: C.ink),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('옆으로 밀면 지도와 경유지를 볼 수 있어요', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: C.ink))),
                      IconButton(tooltip: '안내 닫기', onPressed: () => setState(() => _hint = false), icon: const Icon(Icons.close, color: C.muted)),
                    ]),
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.only(bottom: 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (_paused) ...[
                    _RoundButton(size: 84, bg: Colors.white, fg: C.ink, icon: Icons.stop, label: '끝내기', onTap: _finish),
                    const SizedBox(width: 32),
                  ],
                  _RoundButton(
                    size: 104,
                    bg: C.lime,
                    fg: C.onLime,
                    icon: _paused ? Icons.play_arrow : Icons.pause,
                    semantics: _paused ? '다시 달리기' : '일시정지',
                    onTap: _toggle,
                  ),
                ]),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (final (i, label) in const [(0, '기록'), (1, '지도')])
                    TextButton.icon(
                      onPressed: () => _pages.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                      style: TextButton.styleFrom(foregroundColor: _page == i ? Colors.white : const Color(0xFF7FA390), minimumSize: const Size(64, 44)),
                      icon: Icon(Icons.circle, size: 8, color: _page == i ? Colors.white : const Color(0xFF7FA390)),
                      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _statsPage(Course course) => SafeArea(
        child: Column(children: [
          const SizedBox(height: 96),
          Row(children: [
            _Stat(value: course.distanceKm.toStringAsFixed(2), label: '코스 km'),
            const _Stat(value: '—', label: '달린 거리', dim: true),
            const _Stat(value: '—', label: '페이스', dim: true),
          ]),
          const Spacer(),
          if (_paused) const Text('일시정지됨', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.lime)),
          Semantics(
            label: '달린 시간 $_time',
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_time, style: numStyle(120, color: _paused ? C.brandSub : C.lime)),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text('달린 시간', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.brandSub)),
          const SizedBox(height: 16),
          Text('${course.name} · 거리·페이스는 위치 연동 후 표시돼요', style: const TextStyle(fontSize: 13, color: C.brandSub)),
          const Spacer(flex: 2),
          const SizedBox(height: 190),
        ]),
      );

  Widget _mapPage(Course course) => Column(children: [
        Expanded(
          child: CourseMap(
            course: course,
            tone: MapTone.dark,
            badgePadding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 72, right: 16),
          ),
        ),
        Container(
          color: C.brand,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            _Tile(value: _time, label: '시간'),
            const SizedBox(width: 8),
            _Tile(value: course.distanceKm.toStringAsFixed(2), label: '코스 km'),
            const SizedBox(width: 8),
            const _Tile(value: '—', label: '달린 거리'),
          ]),
        ),
        const SizedBox(height: 200),
      ]);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.dim = false});
  final String value;
  final String label;
  final bool dim;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: numStyle(26, color: dim ? const Color(0xFF7FA390) : Colors.white)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: C.brandSub)),
        ]),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(child: Text(value, style: numStyle(24, color: Colors.white))),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: C.brandSub)),
          ]),
        ),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.size, required this.bg, required this.fg, required this.icon, required this.onTap, this.label, this.semantics});
  final double size;
  final Color bg;
  final Color fg;
  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final String? semantics;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semantics ?? label,
        child: Material(
          color: bg,
          shape: const CircleBorder(),
          elevation: 8,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: fg, size: label == null ? size * 0.46 : 30),
                if (label != null) Text(label!, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      );
}
