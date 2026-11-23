import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'models.dart';
import 'screens/goal_screen.dart';
import 'screens/home_screen.dart';
import 'screens/route_screen.dart';
import 'screens/run_screen.dart';
import 'theme.dart';

void main() => runApp(OlparkRunApp(state: AppState()..load()));

class OlparkRunApp extends StatelessWidget {
  const OlparkRunApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'OLPARK RUN',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: AppShell(state: state),
      );
}

/// 하단 탭: 러닝 / 코스 / 기록
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.state});
  final AppState state;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  Future<void> _openGoal() async {
    final next = await Navigator.of(context).push<Goal>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => GoalScreen(initial: widget.state.goal)),
    );
    if (next != null) await widget.state.setGoal(next);
  }

  void _start(Course course) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RunScreen(course: course, location: widget.state.location)));

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _tab, children: [
          HomeScreen(
            state: widget.state,
            onOpenGoal: _openGoal,
            onStart: _start,
          ),
          RouteScreen(state: widget.state, onStart: _start),
          const _HistoryPlaceholder(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.directions_run_outlined), selectedIcon: Icon(Icons.directions_run), label: '러닝'),
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: '코스'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: '기록'),
          ],
        ),
      );
}

class _HistoryPlaceholder extends StatelessWidget {
  const _HistoryPlaceholder();

  @override
  Widget build(BuildContext context) => const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bar_chart, size: 48, color: C.muted),
              SizedBox(height: 12),
              Text('기록은 준비 중이에요', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              Text('러닝을 끝내면 거리·시간·페이스 요약을 보여드려요. 기록을 모아 보는 기능은 다음 단계예요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: C.muted)),
            ]),
          ),
        ),
      );
}
