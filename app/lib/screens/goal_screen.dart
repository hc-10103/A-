// 오늘 목표: 큰 버튼 세 번 탭으로 끝나는 입력 화면. 고른 Goal 을 돌려준다.
import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../theme.dart';

/// 목표 거리 → 가장 가까운 공식 코스 (백엔드 pick_course 와 같은 결과, 안내 문구용)
const _courseHint = {2: '토성의 길', 3: '젊음의 길', 5: '연인의 길'};

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key, required this.initial});
  final Goal initial;

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  late Goal goal = widget.initial;

  @override
  Widget build(BuildContext context) {
    final summary = '${goal.time.label}에 ${goal.km}km ${goal.activity.label} → ${_courseHint[goal.km] ?? '가까운 코스'} 추천';
    return Scaffold(
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(children: [
              const Expanded(child: Text('오늘 목표', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
              IconButton(tooltip: '닫기', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text('세 가지만 고르면 시간과 코스를 골라 드려요.', style: TextStyle(fontSize: 15, color: C.muted)),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 16), children: [
              _Question(
                title: '1. 무엇을 할까요?',
                columns: 2,
                children: [
                  for (final a in Activity.values)
                    _Option(
                      selected: goal.activity == a,
                      height: 88,
                      onTap: () => setState(() => goal = goal.copyWith(activity: a)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(a == Activity.run ? Icons.directions_run : Icons.directions_walk, size: 32),
                        const SizedBox(height: 6),
                        Text(a.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                ],
              ),
              _Question(
                title: '2. 얼마나 갈까요?',
                columns: 3,
                children: [
                  for (final km in const [2, 3, 5])
                    _Option(
                      selected: goal.km == km,
                      height: 92,
                      semantics: '$km킬로미터, ${_courseHint[km]}',
                      onTap: () => setState(() => goal = goal.copyWith(km: km)),
                      child: Builder(builder: (context) {
                        final fg = DefaultTextStyle.of(context).style.color;
                        return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text.rich(TextSpan(children: [
                            TextSpan(text: '$km', style: numStyle(28, color: fg)),
                            TextSpan(text: 'km', style: numStyle(14, color: fg)),
                          ])),
                          const SizedBox(height: 6),
                          Text(_courseHint[km]!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        ]);
                      }),
                    ),
                ],
              ),
              _Question(
                title: '3. 언제 갈 수 있어요?',
                columns: 2,
                children: [
                  for (final t in TimePreference.values)
                    _Option(
                      selected: goal.time == t,
                      height: 56,
                      onTap: () => setState(() => goal = goal.copyWith(time: t)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(const {
                          TimePreference.morning: Icons.wb_twilight,
                          TimePreference.afternoon: Icons.light_mode_outlined,
                          TimePreference.evening: Icons.nights_stay_outlined,
                          TimePreference.any: Icons.schedule,
                        }[t], size: 22),
                        const SizedBox(width: 8),
                        Text(t.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                ],
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
            child: Column(children: [
              Text(summary, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: C.body)),
              const SizedBox(height: 10),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: C.ink, minimumSize: const Size.fromHeight(60), shape: const StadiumBorder()),
                onPressed: () => Navigator.pop(context, goal),
                child: const Text('이 목표로 추천 받기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.title, required this.columns, required this.children});
  final String title;
  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(header: true, child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, box) {
            final w = (box.maxWidth - 10 * (columns - 1)) / columns;
            return Wrap(spacing: 10, runSpacing: 10, children: [for (final c in children) SizedBox(width: w, child: c)]);
          }),
        ]),
      );
}

class _Option extends StatelessWidget {
  const _Option({required this.selected, required this.height, required this.onTap, required this.child, this.semantics});
  final bool selected;
  final double height;
  final VoidCallback onTap;
  final Widget child;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : C.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: semantics,
      child: Material(
        color: selected ? C.brand : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: selected ? C.brand : C.line, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: IconTheme(
              data: IconThemeData(color: fg),
              child: DefaultTextStyle.merge(style: TextStyle(color: fg), child: Center(child: child)),
            ),
          ),
        ),
      ),
    );
  }
}
