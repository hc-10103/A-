// 데이터 출처·갱신 시각·면책 문구와 시연 모드 스위치를 보여주는 하단 시트.
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

// 백엔드 data_sources.STALE_AFTER(90분)와 같은 값. 바꿀 때 둘 다 바꿀 것.
const _staleMinutes = 90;

String _fmt(String? iso) {
  final t = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '갱신 시각 정보 없음';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.month}/${t.day} ${two(t.hour)}:${two(t.minute)}';
}

Future<void> showInfoSheet(BuildContext context, AppState? state, {RecommendationResponse? data}) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (context) => state == null
        ? _Body(state: null, data: data)
        : ListenableBuilder(listenable: state, builder: (context, _) => _Body(state: state, data: state.data)),
  );
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.data});
  final AppState? state;
  final RecommendationResponse? data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final ref = DateTime.tryParse(d?.generatedAt ?? '') ?? DateTime.now();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('데이터와 설정', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (state != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('시연 모드', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('샘플 데이터를 써요. 실제 관측값이 아니에요.'),
              value: state!.demoMode,
              onChanged: state!.loading ? null : state!.setDemoMode,
            ),
          if (d != null) ...[
            const Divider(),
            const Text('출처', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: C.muted)),
            const SizedBox(height: 6),
            if (d.sources.isEmpty) const Text('사용 가능한 데이터 출처가 없어요.'),
            for (final s in d.sources)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.circle, size: 6, color: C.muted)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${s.name} · ${_fmt(s.updatedAt)}', style: const TextStyle(fontSize: 14))),
                  if (_isStale(s.updatedAt, ref))
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: C.warnBg, borderRadius: BorderRadius.circular(99)),
                      child: const Text('갱신 지연', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: C.warnFg)),
                    ),
                ]),
              ),
            const SizedBox(height: 8),
            Text('추천 생성: ${_fmt(d.generatedAt)}', style: const TextStyle(fontSize: 13, color: C.muted)),
            if (d.disclaimer.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(d.disclaimer, style: const TextStyle(fontSize: 13, height: 1.5, color: C.body)),
            ],
          ],
        ]),
      ),
    );
  }

  bool _isStale(String? iso, DateTime ref) {
    final t = iso == null ? null : DateTime.tryParse(iso);
    return t != null && ref.difference(t).inMinutes > _staleMinutes;
  }
}
