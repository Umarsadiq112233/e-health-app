import 'package:flutter/material.dart';

import 'app_page_route.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/app_session_cubit.dart';
import '../../shared/widgets/beam_ui.dart';
import '../../features/dashboard/presentation/pages/dashboard.dart';
import '../../features/dashboard/presentation/pages/feature_screens.dart';
import '../../features/profile/presentation/pages/profile_screen.dart';
import '../../features/profile/presentation/pages/edit_profile_screen.dart';
import '../../features/profile/presentation/pages/account_settings_screen.dart';
import '../../features/health_metrics/presentation/pages/beam_health_page.dart';
import '../../features/health_metrics/presentation/pages/metric_screen.dart';
import '../../features/ai_coach/presentation/pages/ai_coach_screen.dart';
import '../../features/nutrition/presentation/pages/food_scan_screen.dart';
import '../../features/care/presentation/pages/care_screen.dart';
import '../../features/device_pairing/presentation/pages/my_devices_screen.dart';
import '../../features/device_pairing/presentation/pages/discover_devices_screen.dart';
import '../../features/notifications/presentation/pages/notification_screen.dart';
import '../../features/membership/presentation/pages/membership_support_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int tab = 0;
  final visited = <int>{0};
  final navigators = List.generate(6, (_) => GlobalKey<NavigatorState>());
  void select(int index) {
    if (index == tab) {
      navigators[index].currentState?.popUntil((route) => route.isFirst);
    }
    setState(() {
      tab = index;
      visited.add(index);
    });
  }

  void open(String route) {
    if (route == 'coach') {
      _openCoach();
      return;
    }
    final target = switch (route) {
      'insights' => 1,
      'scan-food' => 2,
      'ring' => 3,
      'care-team' => 4,
      'profile' => 5,
      _ => null,
    };
    if (target != null) {
      select(target);
      return;
    }
    final screen = switch (route) {
      'goals' => const BeamHealthPage(kind: BeamHealthKind.goals),
      'trends' ||
      'history' => const BeamHealthPage(kind: BeamHealthKind.history),
      'activity' => const BeamHealthPage(kind: BeamHealthKind.activity),
      'steps' => const BeamHealthPage(kind: BeamHealthKind.steps),
      'edit-goals' => const BeamHealthPage(kind: BeamHealthKind.editGoals),
      'edit' => const EditProfileScreen(),
      'privacy' => const AccountSettingsScreen(view: AccountView.privacy),
      'platforms' => const AccountSettingsScreen(view: AccountView.platforms),
      'security' => const AccountSettingsScreen(view: AccountView.security),
      'health-data' => const AccountSettingsScreen(view: AccountView.data),
      'settings' => const AccountSettingsScreen(view: AccountView.settings),
      'Subscription' => const MembershipSupportScreen(),
      'Help & Support' => const MembershipSupportScreen(
        view: MemberView.support,
      ),
      'About' => const MembershipSupportScreen(view: MemberView.legal),
      'notifications' => const BeamNotificationScreen(),
      'reminders' => const BeamNotificationScreen(
        view: NotificationView.reminders,
      ),
      'notification-preferences' => const BeamNotificationScreen(
        view: NotificationView.preferences,
      ),
      'pair-device' => const DiscoverDevicesScreen(),
      'report' => const Scaffold(body: SafeArea(child: ReportScreen())),
      _ =>
        route.startsWith('metric:')
            ? MetricScreen(
                index: int.parse(route.split(':').last),
                beamStyle: true,
              )
            : SettingsScreen(route),
    };
    navigators[tab].currentState?.push(
      AppPageRoute<void>(
        reducedMotion: MediaQuery.disableAnimationsOf(context),
        builder: (_) => screen,
      ),
    );
  }

  void _openCoach() {
    Navigator.of(context, rootNavigator: true).push(
      AppPageRoute<void>(
        reducedMotion: MediaQuery.disableAnimationsOf(context),
        builder: (_) => AiCoachScreen.resume(),
      ),
    );
  }

  Widget root(int index) => switch (index) {
    0 => Scaffold(
      backgroundColor: beamNavy,
      body: SafeArea(child: Dashboard(open: open)),
    ),
    1 => const BeamHealthPage(kind: BeamHealthKind.insights),
    2 => const FoodScanScreen(),
    3 => MyDevicesScreen(
      onData: () => open('history'),
      onBack: () => select(0),
    ),
    4 => const CareScreen(),
    _ => Scaffold(
      backgroundColor: beamNavy,
      body: SafeArea(
        child: BlocBuilder<AppSessionCubit, AppSessionState>(
          bloc: AppSessionCubit.instance,
          builder: (context, _) => ProfileScreen(open: open),
        ),
      ),
    ),
  };
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: tab == 0 && !(navigators[tab].currentState?.canPop() ?? false),
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      final navigator = navigators[tab].currentState;
      if (navigator != null && await navigator.maybePop()) return;
      if (tab != 0) select(0);
    },
    child: Scaffold(
      backgroundColor: beamNavy,
      body: IndexedStack(
        index: tab,
        children: [
          for (var index = 0; index < 6; index++)
            visited.contains(index)
                ? TickerMode(
                    enabled: tab == index,
                    child: Navigator(
                      key: navigators[index],
                      observers: [
                        _TabObserver(() {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() {});
                          });
                        }),
                      ],
                      onGenerateRoute: (_) =>
                          MaterialPageRoute<void>(builder: (_) => root(index)),
                    ),
                  )
                : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        selected: tab,
        onChanged: select,
        onOpen: open,
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'global-ai-coach',
        onPressed: _openCoach,
        elevation: 8,
        highlightElevation: 12,
        tooltip: 'Open AI Coach',
        backgroundColor: const Color(0xFF032235),
        foregroundColor: beamCyan,
        child: Image.asset(
          'assets/icons/connect/chatbot.png',
          width: 32,
          height: 32,
          semanticLabel: 'AI Coach',
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    ),
  );
}

/// Selection is owned by the shell, never inferred from a pushed route.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selected,
    required this.onChanged,
    this.onOpen,
  });
  final int selected;
  final ValueChanged<int> onChanged;
  final ValueChanged<String>? onOpen;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF002337), beamNavy]),
        border: Border.all(color: beamBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          for (final item in const [
            _BottomNavItem.beam('home', 'Home'),
            _BottomNavItem.beam('insights', 'Insights'),
            _BottomNavItem.material(Icons.camera_alt_rounded, 'Scan Food'),
            _BottomNavItem.beam('watch', 'Device'),
            _BottomNavItem.beam('users', 'Care'),
            _BottomNavItem.beam('person', 'Profile'),
          ].indexed)
            Expanded(
              child: Semantics(
                button: true,
                selected: selected == item.$1,
                label: '${item.$2.label} tab',
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onChanged(item.$1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        item.$2.beamIcon == null
                            ? Icon(
                                item.$2.materialIcon,
                                size: 22,
                                color: selected == item.$1
                                    ? beamCyan
                                    : beamMuted,
                              )
                            : BeamIcon(
                                item.$2.beamIcon!,
                                size: 22,
                                color: selected == item.$1
                                    ? beamCyan
                                    : beamMuted,
                              ),
                        const SizedBox(height: 5),
                        Text(
                          item.$2.label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10,
                            color: selected == item.$1 ? beamCyan : beamMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _BottomNavItem {
  const _BottomNavItem.beam(this.beamIcon, this.label) : materialIcon = null;
  const _BottomNavItem.material(this.materialIcon, this.label)
    : beamIcon = null;

  final String? beamIcon;
  final IconData? materialIcon;
  final String label;
}

class _TabObserver extends NavigatorObserver {
  _TabObserver(this.changed);
  final VoidCallback changed;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      changed();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => changed();
}
