// 코스 경로: 개략도 지도 + 코스 고르기 + 경유지 순서 + 시작 버튼 하나.
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../course_route.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/course_map.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key, required this.state, required this.onStart});
  final AppState state;
  final void Function(Course course) onStart;

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final s = widget.state;
        final recommended = s.data?.course;
        final all = <Course>[
          ?recommended,
          ...s.courses.where((c) => c.id != recommended?.id),
        ];
        if (all.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('코스 정보를 불러오지 못했어요.\n홈에서 추천을 먼저 받아 주세요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: C.muted)),
            ),
          );
        }
        final course = all.firstWhere((c) => c.id == _selectedId, orElse: () => all.first);
        final route = routeOf(course);
        final canPop = Navigator.of(context).canPop();

        return Column(children: [
          Expanded(
            flex: 11,
            child: Stack(fit: StackFit.expand, children: [
              CourseMap(
                course: course,
                badgeAlignment: Alignment.topRight,
                badgePadding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 18, right: 16),
              ),
              if (canPop)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 8,
                  left: 12,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: C.ink, minimumSize: const Size(48, 48)),
                    tooltip: '뒤로',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
            ]),
          ),
          Expanded(
            flex: 10,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Color(0x1F111613), blurRadius: 24, offset: Offset(0, -6))],
              ),
              child: Column(children: [
                Expanded(
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), children: [
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: all.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final c = all[i];
                          final sel = c.id == course.id;
                          return ChoiceChip(
                            selected: sel,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _selectedId = c.id),
                            shape: const StadiumBorder(),
                            side: BorderSide(color: sel ? C.ink : C.chipLine),
                            selectedColor: C.ink,
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: sel ? Colors.white : C.ink),
                            label: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(c.name),
                              if (c.id == recommended?.id) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(color: C.lime, borderRadius: BorderRadius.circular(99)),
                                  child: const Text('추천', style: TextStyle(fontSize: 11, color: C.onLime)),
                                ),
                              ],
                            ]),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(course.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                          Text(distanceDiffText(course.distanceKm, s.goal.km), style: const TextStyle(fontSize: 15, color: C.muted)),
                        ]),
                      ),
                      Text.rich(TextSpan(children: [
                        TextSpan(text: course.distanceKm.toStringAsFixed(2), style: numStyle(46, color: C.brand)),
                        TextSpan(text: 'km', style: numStyle(18, color: C.brand)),
                      ])),
                    ]),
                    const SizedBox(height: 14),
                    Semantics(
                      label: '경유지 순서',
                      child: Wrap(spacing: 6, runSpacing: 6, children: [
                        if (route.waypoints.isEmpty) _StopChip(route.note ?? course.description, first: false),
                        for (var i = 0; i < route.waypoints.length; i++)
                          _StopChip(
                            '${i == 0 ? '출발' : (i == route.waypoints.length - 1 && route.waypoints[i] == route.waypoints.first) ? '도착' : '${i + 1}'} ${route.waypoints[i]}',
                            first: i == 0,
                          ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      const Expanded(child: Text('경유지 순서: KSPO 공식 산책·조깅 코스 안내', style: TextStyle(fontSize: 12, color: C.muted))),
                      if (course.mapUrl != null)
                        TextButton(
                          onPressed: () => launchUrl(Uri.parse(course.mapUrl!), mode: LaunchMode.externalApplication),
                          child: const Text('공식 지도 보기'),
                        ),
                    ]),
                  ]),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: C.ink, minimumSize: const Size.fromHeight(60), shape: const StadiumBorder()),
                    onPressed: () => widget.onStart(course),
                    icon: const Icon(Icons.play_arrow),
                    // 공식 코스 이름은 모두 '~길'(받침 ㄹ)로 끝나 조사는 '로'
                    label: Text('${course.name}로 시작', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ),
        ]);
      },
    );
  }
}

class _StopChip extends StatelessWidget {
  const _StopChip(this.text, {required this.first});
  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: first ? C.lime : C.soft, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(fontSize: 13, fontWeight: first ? FontWeight.w700 : FontWeight.w500, color: C.ink)),
      );
}
