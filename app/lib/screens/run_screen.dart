// 러닝 중: 큰 숫자 하나 + 옆으로 밀면 지도.
// GPS가 켜져 있으면 큰 숫자는 달린 거리(km), 위치 권한이 없으면 시간으로 바꾸고 거리는 지어내지 않는다.
// 개략도에는 현재 위치를 찍지 않는다 (코스 좌표가 없어 위치를 맞춰 그릴 수 없음). 대신 진행률 막대로 보여준다.
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../location.dart';
import '../models.dart';
import '../run_tracker.dart';
import '../theme.dart';
import '../widgets/course_map.dart';

class RunScreen extends StatefulWidget {
  const RunScreen({super.key, required this.course, required this.location});
  final Course course;
  final LocationSource location;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> with WidgetsBindingObserver {
  late final RunTracker _t = RunTracker(widget.location);
  final _pages = PageController();
  Timer? _tick;
  int _page = 0;
  bool _hint = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _t.addListener(_refresh);
    _t.start();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) => _refresh());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 설정에서 위치를 허용하고 돌아왔을 때 다시 확인
    if (state == AppLifecycleState.resumed && _t.access != null && _t.access != LocationAccess.granted) {
      _t.retryAccess();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _t.removeListener(_refresh);
    _t.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _toggle() => _t.paused ? _t.resume() : _t.pause();

  Future<void> _finish() async {
    _t.finish();
    final gps = _t.gpsOn && _t.meters > 0;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('수고했어요!'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SummaryRow('거리', gps ? '${_t.km.toStringAsFixed(2)} km' : '위치 기록 없음'),
          _SummaryRow('시간', formatDuration(_t.elapsed)),
          _SummaryRow('평균 페이스', gps ? '${formatPace(_t.pacePerKm)} /km' : '—'),
          _SummaryRow('코스', '${widget.course.name} ${widget.course.distanceKm.toStringAsFixed(2)}km'),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('확인'))],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<bool> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('러닝을 끝낼까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('계속 달리기')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('끝내기')),
        ],
      ),
    );
    return ok ?? false;
  }

  double get _remainingKm => (widget.course.distanceKm - _t.km).clamp(0, double.infinity).toDouble();

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
                  if (_t.paused) ...[
                    _RoundButton(size: 84, bg: Colors.white, fg: C.ink, icon: Icons.stop, label: '끝내기', onTap: _finish),
                    const SizedBox(width: 32),
                  ],
                  _RoundButton(
                    size: 104,
                    bg: C.lime,
                    fg: C.onLime,
                    icon: _t.paused ? Icons.play_arrow : Icons.pause,
                    semantics: _t.paused ? '다시 달리기' : '일시정지',
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

  Widget _statsPage(Course course) {
    final gps = _t.gpsOn;
    final big = gps ? _t.km.toStringAsFixed(2) : formatDuration(_t.elapsed);
    final bigLabel = gps ? '킬로미터' : '달린 시간';
    return SafeArea(
      child: Column(children: [
        const SizedBox(height: 84), // 위쪽 '옆으로 밀면…' 안내 자리
        Row(children: gps
            ? [
                _Stat(value: formatDuration(_t.elapsed), label: '시간'),
                _Stat(value: formatPace(_t.pacePerKm), label: '페이스', dim: _t.pacePerKm == null),
                _Stat(value: _remainingKm.toStringAsFixed(2), label: '남은 km'),
              ]
            : [
                _Stat(value: course.distanceKm.toStringAsFixed(2), label: '코스 km'),
                const _Stat(value: '—', label: '달린 거리', dim: true),
                const _Stat(value: '—', label: '페이스', dim: true),
              ]),
        const SizedBox(height: 16),
        _GpsStatus(tracker: _t, onOpenSettings: () => widget.location.openSettings(_t.access!)),
        const SizedBox(height: 8),
        if (_t.paused) const Text('일시정지됨', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.lime)),
        // 큰 숫자는 남는 높이를 다 쓰고, 화면이 짧으면(작은 폰·큰 글씨) 그만큼 줄어든다
        Expanded(
          child: Semantics(
            label: '$bigLabel $big',
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(big, style: numStyle(gps ? 136 : 120, color: _t.paused ? C.brandSub : C.lime)),
              ),
            ),
          ),
        ),
        Text(bigLabel, maxLines: 1, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: C.brandSub)),
        const SizedBox(height: 12),
        Text('${course.name} ${course.distanceKm.toStringAsFixed(2)}km', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: C.brandSub)),
        const SizedBox(height: 16),
        // 아래 버튼(일시정지·기록/지도) 자리
        const SizedBox(height: 180),
      ]),
    );
  }

  Widget _mapPage(Course course) {
    final gps = _t.gpsOn;
    final progress = (course.distanceKm <= 0 ? 0.0 : _t.km / course.distanceKm).clamp(0.0, 1.0);
    return Column(children: [
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
        child: Column(children: [
          if (gps)
            Semantics(
              label: '코스 진행률 ${(progress * 100).round()}퍼센트',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: progress, minHeight: 6, color: C.lime, backgroundColor: Colors.white24),
              ),
            ),
          const SizedBox(height: 12),
          Row(children: [
            _Tile(value: formatDuration(_t.elapsed), label: '시간'),
            const SizedBox(width: 8),
            _Tile(value: gps ? _t.km.toStringAsFixed(2) : '—', label: '달린 km'),
            const SizedBox(width: 8),
            _Tile(value: gps ? _remainingKm.toStringAsFixed(2) : course.distanceKm.toStringAsFixed(2), label: gps ? '남은 km' : '코스 km'),
          ]),
        ]),
      ),
      const SizedBox(height: 200),
    ]);
  }
}

/// 위치 상태를 한 줄로: 찾는 중 / 신호 약함 / 권한 없음(설정 버튼)
class _GpsStatus extends StatelessWidget {
  const _GpsStatus({required this.tracker, required this.onOpenSettings});
  final RunTracker tracker;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final a = tracker.access;
    if (a == null) return const _Chip(icon: Icons.gps_not_fixed, text: '위치를 찾는 중…');
    if (a != LocationAccess.granted || tracker.gpsError) {
      final text = switch (a) {
        LocationAccess.serviceOff => '휴대폰 위치가 꺼져 있어 시간만 기록해요',
        _ when tracker.gpsError => '위치를 받지 못해 시간만 기록해요',
        _ => '위치 권한이 없어 시간만 기록해요',
      };
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Material(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            child: Row(children: [
              const Icon(Icons.location_off, color: C.lime),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14))),
              TextButton(
                onPressed: onOpenSettings,
                style: TextButton.styleFrom(foregroundColor: C.lime, minimumSize: const Size(64, 44)),
                child: const Text('위치 켜기', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      );
    }
    if (tracker.weakSignal) return const _Chip(icon: Icons.gps_not_fixed, text: 'GPS 신호가 약해요 · 거리가 덜 잡힐 수 있어요');
    return const _Chip(icon: Icons.gps_fixed, text: 'GPS로 기록 중');
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: C.brandSub),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 13, color: C.brandSub)),
        ]),
      );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 88, child: Text(label, style: const TextStyle(color: C.muted))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.dim = false});
  final String value;
  final String label;
  final bool dim;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          FittedBox(child: Text(value, style: numStyle(26, color: dim ? const Color(0xFF7FA390) : Colors.white))),
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
