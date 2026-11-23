import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/course_map.dart';
import '../widgets/info_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state, required this.onOpenGoal, required this.onStart});

  final AppState state;
  final VoidCallback onOpenGoal;
  final void Function(Course course) onStart;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _pager = PageController();
  int _card = 0;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final data = s.data;
        final course = data?.course;
        final top = data?.top;
        final safety = top != null && top.unsafe;
        return Stack(
          children: [
            if (course != null && !safety)
              Positioned.fill(
                top: 330,
                child: Opacity(
                  opacity: 0.55,
                  child: ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment(0, -0.4),
                      colors: [Colors.transparent, Colors.black],
                    ).createShader(r),
                    blendMode: BlendMode.dstIn,
                    child: CourseMap(course: course, tone: MapTone.faint, labels: false, badge: false),
                  ),
                ),
              ),
            SafeArea(
              bottom: false,
              child: RefreshIndicator(
                onRefresh: s.load,
                // 화면이 길면 시작 버튼이 아래로 붙고, 짧거나 글자가 크면 스크롤된다
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _Header(state: s)),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _body(context, s, data, safety),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _body(BuildContext context, AppState s, RecommendationResponse? data, bool safety) {
    if (data == null && s.loading) {
      return const _StatusCard(icon: Icons.hourglass_top, title: '오늘 날씨와 공원 상황을 보고 있어요', child: LinearProgressIndicator());
    }
    if (data == null) {
      return _StatusCard(
        icon: Icons.wifi_off,
        title: '추천을 불러오지 못했어요',
        body: s.error?.hint,
        child: FilledButton(onPressed: s.load, child: const Text('다시 시도')),
      );
    }
    if (data.unavailable || data.top == null) {
      return Column(children: [
        _StatusCard(
          icon: Icons.cloud_off,
          title: data.unavailable ? '실시간 데이터를 가져오지 못했어요' : '추천할 시간대가 없어요',
          body: '데이터가 없을 때는 추천을 지어내지 않아요. 시연 모드로 샘플 데이터를 볼 수 있어요.',
          child: s.demoMode ? null : FilledButton(onPressed: () => s.setDemoMode(true), child: const Text('시연 모드로 보기')),
        ),
        _SourcesLine(data: data),
      ]);
    }
    if (safety) return _SafetyView(state: s, data: data, onOpenGoal: widget.onOpenGoal);

    final cards = <Widget>[
      _RecommendationCard(rec: data.top!, activity: s.goal.activity),
      _EventsCard(events: data.events),
      const _HowCard(),
    ];
    const labels = ['오늘의 추천', '공원 소식', '추천 기준'];
    final course = data.course;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          // 카드 내용이 대부분 글자라, 휴대폰 글자 크기 설정만큼 카드도 키운다
          height: MediaQuery.textScalerOf(context).scale(184),
          child: PageView(
            controller: _pager,
            onPageChanged: (i) => setState(() => _card = i),
            children: [for (final c in cards) Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: c)],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < cards.length; i++)
              Semantics(
                button: true,
                selected: _card == i,
                label: labels[i],
                child: InkWell(
                  onTap: () => _pager.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                  child: SizedBox(
                    width: 44,
                    height: 32,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _card == i ? 28 : 14,
                        height: 4,
                        decoration: BoxDecoration(color: _card == i ? C.ink : const Color(0xFFB9C1BC), borderRadius: BorderRadius.circular(99)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        _SourcesLine(data: data),
        const Spacer(),
        const SizedBox(height: 24),
        // 시작 버튼이 어떤 코스로 출발하는지 (바꾸려면 아래 '코스' 탭)
        Text(
          course == null ? '추천 코스 정보 없음' : '${course.name} ${course.distanceKm.toStringAsFixed(2)}km',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.body),
        ),
        const SizedBox(height: 14),
        _StartControls(
          goalKm: s.goal.km,
          onSettings: () => showInfoSheet(context, s),
          onGoal: widget.onOpenGoal,
          onStart: course == null ? null : () => widget.onStart(course),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
        child: Row(children: [
          Expanded(child: Text('러닝', style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, fontSize: 34))),
          if (state.demoMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: C.demo, borderRadius: BorderRadius.circular(99)),
              child: const Text('DEMO', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          IconButton(
            tooltip: '데이터 출처와 설정',
            onPressed: () => showInfoSheet(context, state),
            icon: const Icon(Icons.info_outline),
          ),
        ]),
      );
}

BoxDecoration _cardDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [BoxShadow(color: Color(0x14111613), blurRadius: 12, offset: Offset(0, 2))],
    );

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.rec, required this.activity});
  final TimeRecommendation rec;
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final verb = activity == Activity.run ? '달리기' : '걷기';
    final sentence = switch (rec.rating) {
      '좋음' => '${rec.timeLabel}에 $verb 좋아요',
      '보통' => '${rec.timeLabel}, 괜찮아요',
      _ => '${rec.timeLabel}, 조심해서 다녀오세요',
    };
    final rc = ratingColors(rec.rating);
    final c = rec.conditions;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('오늘의 추천', style: TextStyle(fontSize: 14, color: C.muted)),
          Text(sentence, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, height: 1.3, fontWeight: FontWeight.w900)),
          Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: rc.bg, borderRadius: BorderRadius.circular(99)),
              child: Text('${rec.rating} · ${rec.score}점', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: rc.fg)),
            ),
            _Cond(Icons.wb_sunny_outlined, c.weather ?? '날씨 정보 없음'),
            _Cond(Icons.air, c.airQuality == null ? '대기 정보 없음' : '대기 ${c.airQuality}'),
            _Cond(Icons.groups_outlined, c.parkCrowding == null ? '혼잡 정보 없음' : '공원 전체 ${c.parkCrowding}'),
          ]),
        ],
      ),
    );
  }
}

class _Cond extends StatelessWidget {
  const _Cond(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 14)),
      ]);
}

class _EventsCard extends StatelessWidget {
  const _EventsCard({required this.events});
  final List<ParkEvent> events;

  @override
  Widget build(BuildContext context) {
    final e = events.isEmpty ? null : events.first;
    final when = e == null ? '' : [e.startTime, if (e.endTime != null) '~${e.endTime}'].whereType<String>().join();
    return _IconCard(
      icon: Icons.event,
      bg: C.warnBg,
      fg: C.warnFg,
      label: e == null ? '오늘 공원 소식' : '오늘 공원 소식${e.isSample ? ' (샘플)' : ''}${events.length > 1 ? ' · ${events.length}건' : ''}',
      title: e == null ? '등록된 행사·공지가 없어요' : '${when.isEmpty ? '' : '$when '}${e.title}',
      body: e == null ? null : '행사는 주의 정보예요. 코스가 붐빈다는 뜻은 아니에요.',
    );
  }
}

class _HowCard extends StatelessWidget {
  const _HowCard();

  @override
  Widget build(BuildContext context) => const _IconCard(
        icon: Icons.info_outline,
        bg: C.infoBg,
        fg: C.infoFg,
        label: '추천은 이렇게 정해요',
        title: '날씨 · 대기질 · 공원 전체 혼잡도',
        body: '비·미세먼지 매우 나쁨이면 점수와 상관없이 쉬어가라고 알려드려요. 혼잡도는 코스별이 아닌 공원 전체 기준이에요.',
      );
}

class _IconCard extends StatelessWidget {
  const _IconCard({required this.icon, required this.bg, required this.fg, required this.label, required this.title, this.body});
  final IconData icon;
  final Color bg;
  final Color fg;
  final String label;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: fg, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 13, color: C.muted)),
              const SizedBox(height: 2),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, height: 1.35, fontWeight: FontWeight.w900)),
              if (body != null) ...[
                const SizedBox(height: 4),
                Text(body!, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.4, color: C.body)),
              ],
            ]),
          ),
        ]),
      );
}

class _SourcesLine extends StatelessWidget {
  const _SourcesLine({required this.data});
  final RecommendationResponse data;

  @override
  Widget build(BuildContext context) {
    final src = data.sources.isEmpty ? '출처 없음' : data.sources.first.name;
    final t = DateTime.tryParse(data.generatedAt)?.toLocal();
    final time = t == null ? '' : ' · ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} 기준';
    final status = switch (data.dataStatus) {
      'sample' => '샘플 데이터',
      'partial' => '일부 데이터만',
      'unavailable' => '데이터 없음',
      _ => '실시간',
    };
    return Center(
      child: TextButton.icon(
        onPressed: () => showInfoSheet(context, null, data: data),
        icon: const Icon(Icons.info_outline, size: 16, color: C.muted),
        // 샘플 모드는 출처 이름이 이미 '샘플 데이터'라 상태를 다시 붙이지 않는다
        label: Text('${data.dataStatus == 'sample' ? '' : '$status · '}$src$time', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.muted)),
      ),
    );
  }
}

class _StartControls extends StatelessWidget {
  const _StartControls({required this.goalKm, required this.onSettings, required this.onGoal, required this.onStart});
  final int goalKm;
  final VoidCallback onSettings;
  final VoidCallback onGoal;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SmallCircle(label: '설정', onTap: onSettings, child: const Icon(Icons.settings_outlined)),
          const SizedBox(width: 28),
          Semantics(
            button: true,
            label: '러닝 시작',
            child: Material(
              color: onStart == null ? C.line : C.lime,
              shape: const CircleBorder(),
              elevation: 6,
              shadowColor: const Color(0x400F3D2A),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onStart,
                child: SizedBox(
                  width: 128,
                  height: 128,
                  child: Center(child: Text('시작', style: numStyle(30, color: C.onLime))),
                ),
              ),
            ),
          ),
          const SizedBox(width: 28),
          _SmallCircle(label: '목표', onTap: onGoal, child: Text('${goalKm}km', style: numStyle(17, color: C.ink))),
        ],
      );
}

class _SmallCircle extends StatelessWidget {
  const _SmallCircle({required this.label, required this.onTap, required this.child});
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 3,
          shadowColor: const Color(0x33111613),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 60, height: 60, child: Center(child: child)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: C.body)),
      ]);
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.icon, required this.title, this.body, this.child});
  final IconData icon;
  final String title;
  final String? body;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: C.muted, size: 32),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          if (body != null) ...[const SizedBox(height: 6), Text(body!, style: const TextStyle(fontSize: 15, height: 1.5, color: C.body))],
          if (child != null) ...[const SizedBox(height: 16), child!],
        ]),
      );
}

/// 맨 앞 추천이 '야외운동 비권장'일 때: 점수보다 안전 안내가 먼저.
class _SafetyView extends StatelessWidget {
  const _SafetyView({required this.state, required this.data, required this.onOpenGoal});
  final AppState state;
  final RecommendationResponse data;
  final VoidCallback onOpenGoal;

  @override
  Widget build(BuildContext context) {
    final top = data.top!;
    final alt = data.safeAlternative;
    final reason = top.reasons.isEmpty ? '안전 기준에 해당하는 조건이 있어요.' : top.reasons.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(color: C.dangerBg, borderRadius: BorderRadius.circular(24)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.umbrella, color: C.dangerIcon, size: 30),
            ),
            const SizedBox(height: 14),
            Text('${top.timeLabel}에는 쉬어가요', style: const TextStyle(fontSize: 26, height: 1.3, fontWeight: FontWeight.w900, color: C.dangerFg)),
            const SizedBox(height: 6),
            Text('$reason 점수와 상관없이 안전을 먼저 봐요.', style: const TextStyle(fontSize: 16, height: 1.5, color: C.dangerFg)),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      if (alt != null)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('대신 이때는 어때요?', style: TextStyle(fontSize: 14, color: C.muted)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text(alt.timeLabel, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: ratingColors(alt.rating).bg, borderRadius: BorderRadius.circular(99)),
                child: Text('${alt.rating} · ${alt.score}점', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ratingColors(alt.rating).fg)),
              ),
            ]),
            if (alt.reasons.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(alt.reasons.take(2).join(' · '), style: const TextStyle(fontSize: 15, color: C.body)),
            ],
          ]),
        )
      else
        const _StatusCard(icon: Icons.home_outlined, title: '확인한 모든 시간대가 비권장이에요', body: '오늘은 실내 운동을 고려해 주세요.'),
      const SizedBox(height: 24),
      FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: C.ink, minimumSize: const Size.fromHeight(60), shape: const StadiumBorder()),
        onPressed: onOpenGoal,
        icon: const Icon(Icons.schedule),
        label: const Text('다른 시간 고르기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      _SourcesLine(data: data),
      const SizedBox(height: 24),
    ]);
  }
}
