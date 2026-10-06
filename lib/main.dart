import 'package:flutter/material.dart';
import 'src/api.dart';
import 'src/admin.dart';
import 'src/assistant.dart';
import 'src/common.dart';
import 'src/config.dart';
import 'src/login.dart';
import 'src/parent.dart';
import 'src/profile.dart';
import 'src/session.dart';
import 'src/student.dart';
import 'src/teacher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient();
  final session = Session(api);
  await session.bootstrap();
  runApp(IntentionApp(session: session));
}

class IntentionApp extends StatelessWidget {
  const IntentionApp({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) => SessionScope(
    session: session,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3157A4),
        inputDecorationTheme: const InputDecorationTheme(filled: false),
      ),
      home: const AppGate(),
    ),
  );
}

class AppGate extends StatelessWidget {
  const AppGate({super.key});
  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.booting) {
          return const Scaffold(
            body: LoadingView(text: 'Тизимга уланмоқда...'),
          );
        }
        if (!session.signedIn) return const LoginScreen();
        return const RoleHome();
      },
    );
  }
}

class RoleHome extends StatefulWidget {
  const RoleHome({super.key});
  @override
  State<RoleHome> createState() => _RoleHomeState();
}

class _RoleHomeState extends State<RoleHome> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final role = session.role;
    late final List<Widget> pages;
    late final List<NavigationDestination> destinations;
    late final String title;

    if (role == 'student') {
      title = 'Ўқувчи';
      pages = const [
        StudentGradesScreen(),
        StudentTestsScreen(),
        StudentResultsScreen(),
        ProfileScreen(),
      ];
      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.grade_outlined),
          selectedIcon: Icon(Icons.grade),
          label: 'Баҳо',
        ),
        NavigationDestination(
          icon: Icon(Icons.quiz_outlined),
          selectedIcon: Icon(Icons.quiz),
          label: 'Тестлар',
        ),
        NavigationDestination(
          icon: Icon(Icons.assessment_outlined),
          selectedIcon: Icon(Icons.assessment),
          label: 'Натижа',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Профиль',
        ),
      ];
    } else if (role == 'parent') {
      title = 'Ота-она';
      pages = const [ParentChildrenScreen(), ProfileScreen()];
      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.family_restroom_outlined),
          selectedIcon: Icon(Icons.family_restroom),
          label: 'Фарзандлар',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Профиль',
        ),
      ];
    } else if (role == 'assistant') {
      title = 'Ассистент';
      pages = const [
        AssistantSummaryScreen(),
        AssistantGradesJournalScreen(),
        ProfileScreen(),
      ];
      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon: Icon(Icons.fact_check),
          label: 'Давомат',
        ),
        NavigationDestination(
          icon: Icon(Icons.grade_outlined),
          selectedIcon: Icon(Icons.grade),
          label: 'Баҳолар',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Профиль',
        ),
      ];
    } else if (role == 'teacher') {
      title = 'Ўқитувчи';
      pages = const [
        TeacherAssignmentsScreen(),
        TeacherMonthlyGradesScreen(),
        TeacherHistoryScreen(),
        ProfileScreen(),
      ];
      destinations = const [
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: 'Журнал',
        ),
        NavigationDestination(
          icon: Icon(Icons.grade_outlined),
          selectedIcon: Icon(Icons.grade),
          label: 'Баҳолар',
        ),
        NavigationDestination(
          icon: Icon(Icons.history),
          selectedIcon: Icon(Icons.history_toggle_off),
          label: 'Тарих',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Профиль',
        ),
      ];
    } else {
      title = roleLabel(role);
      pages = role == 'admin'
          ? const [AdminReportsScreen(), AdminGradingScreen(), ProfileScreen()]
          : const [WebAdminNotice(), ProfileScreen()];
      destinations = role == 'admin'
          ? const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Ҳисобот',
              ),
              NavigationDestination(
                icon: Icon(Icons.rule_outlined),
                selectedIcon: Icon(Icons.rule),
                label: 'Мезон',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Профиль',
              ),
            ]
          : const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Ҳисобот',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Профиль',
              ),
            ];
    }

    final safeIndex = _index.clamp(0, pages.length - 1).toInt();
    return Scaffold(
      appBar: AppBar(
        title: Text('${AppConfig.appName} · $title'),
        actions: [
          IconButton(
            tooltip: 'Профильни янгилаш',
            onPressed: () async {
              try {
                await session.refreshProfile();
                if (context.mounted)
                  showMessage(context, 'Маълумот янгиланди.');
              } catch (e) {
                if (context.mounted) showMessage(context, '$e', error: true);
              }
            },
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: IndexedStack(index: safeIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        destinations: destinations,
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}

class WebAdminNotice extends StatelessWidget {
  const WebAdminNotice({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 54),
              const SizedBox(height: 14),
              Text(
                'Админ ва методист бошқаруви',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Биринчи мобил версияда Админ/Методист учун асосий бошқарув веб-сайтда қолади. Кейинги версияда мобил админ панель ҳам қўшилади.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
