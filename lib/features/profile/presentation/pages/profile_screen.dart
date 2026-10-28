import 'package:flutter/material.dart';

import 'edit_profile_screen.dart';
import '../../../../shared/widgets/beam_ui.dart';
import '../widgets/profile_avatar.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/components.dart';
import '../../../../app/state/app_session_cubit.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';

class ProfileScreen extends StatelessWidget {
  final ValueChanged<String> open;
  const ProfileScreen({super.key, required this.open});
  @override
  Widget build(BuildContext context) {
    final session = AppSessionCubit.instance;
    return Theme(
      data: beamTheme(context),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BeamTabHeader(
            title: 'My Profile',
            padding: EdgeInsets.zero,
            trailing: BeamHeaderAction(
              icon: Icons.settings_rounded,
              tooltip: 'General settings',
              onPressed: () => open('settings'),
            ),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () => open('edit'),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: beamCyan, width: 2),
                  ),
                  child: ProfileAvatar(url: session.avatarUrl, radius: 40),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.name.isEmpty ? 'Your Profile' : session.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        session.email.isEmpty ? 'E Health ID' : session.email,
                        style: const TextStyle(color: beamMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: beamMuted),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _panel(
            Row(
              children: [
                for (final item in [
                  (Icons.person, session.gender),
                  (
                    Icons.cake,
                    session.birthDate.isEmpty ? 'Age —' : session.birthDate,
                  ),
                  (Icons.monitor_weight, '${session.weight} kg'),
                ])
                  Expanded(
                    child: Column(
                      children: [
                        Icon(item.$1, color: beamCyan, size: 22),
                        const SizedBox(height: 8),
                        Text(
                          item.$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _panel(
            InkWell(
              onTap: () => open('ring'),
              child: const Row(
                children: [
                  BeamImage(
                    asset: BeamAssets.watch,
                    label: 'E Health Pulse Watch',
                    width: 48,
                    height: 65,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Devices',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'E Health Pulse Watch',
                          style: TextStyle(color: beamMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: beamMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _panel(
            _row(
              Icons.workspace_premium,
              'Membership',
              'Subscription',
              subtitle: 'View plans',
              color: const Color(0xFFFFC94B),
            ),
          ),
          const SizedBox(height: 14),
          _panel(
            Column(
              children: [
                for (final item in [
                  (Icons.person, 'Edit Profile', 'edit'),
                  (Icons.shield, 'Privacy & Security', 'privacy'),
                  (Icons.extension, 'Connected Platforms', 'platforms'),
                  (Icons.settings, 'General Settings', 'settings'),
                  (Icons.bar_chart, 'Health Data', 'health-data'),
                  (Icons.lock, 'Security Settings', 'security'),
                  (Icons.help_outline, 'Help & Support', 'Help & Support'),
                  (Icons.info_outline, 'Legal & About', 'About'),
                ])
                  _row(item.$1, item.$2, item.$3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    IconData icon,
    String label,
    String route, {
    String? subtitle,
    Color color = beamCyan,
  }) => InkWell(
    onTap: () => open(route),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(color: beamMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: beamMuted, size: 20),
        ],
      ),
    ),
  );
  Widget _panel(Widget child) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFF07516A), width: .8),
      gradient: const LinearGradient(
        colors: [Color(0xFF002537), Color(0xFF001822)],
      ),
    ),
    child: child,
  );
}

class SettingsScreen extends StatefulWidget {
  final String title;
  const SettingsScreen(this.title, {super.key});
  @override
  State<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
  final toggles = AppSessionCubit.instance.preferences;
  final form = GlobalKey<FormState>();
  late String name = AppSessionCubit.instance.name,
      email = AppSessionCubit.instance.email,
      weight = AppSessionCubit.instance.weight;
  bool saved = false;
  @override
  Widget build(BuildContext context) {
    if (widget.title == 'My Profile') return const EditProfileScreen();
    final auth = context.read<AuthBloc?>();
    if (auth == null) return screen(context);
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.message == 'Profile updated.') {
          setState(() => saved = true);
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Profile saved')));
        }
      },
      builder: (context, state) => screen(context),
    );
  }

  Widget screen(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.large),
        children: [
          if (widget.title == 'Appearance') ...[
            const Text('Choose your theme', style: AppTypography.title),
            const SizedBox(height: 20),
            for (final mode in ThemeMode.values)
              Panel(
                onTap: () =>
                    setState(() => AppSessionCubit.instance.theme(mode)),
                child: Row(
                  children: [
                    Icon(
                      mode == ThemeMode.dark
                          ? Icons.dark_mode_outlined
                          : mode == ThemeMode.light
                          ? Icons.light_mode_outlined
                          : Icons.brightness_auto_outlined,
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text(mode.name)),
                    if (AppSessionCubit.instance.themeMode == mode)
                      const Icon(Icons.check_circle, color: AppColors.green),
                  ],
                ),
              ),
          ] else if (widget.title == 'Privacy & Data') ...[
            const InsightCard((
              'Your data belongs to you',
              'Account details are stored in Supabase. Health cards show only genuine recorded measurements.',
              Icons.verified_user_outlined,
              AppColors.green,
            )),
            const Panel(
              child: Text(
                'Bluetooth access is requested only when you choose to scan. Change device permission access in your phone’s app settings. Health sync awaits the supported wearable protocol.',
              ),
            ),
          ] else if (widget.title == 'Subscription') ...[
            const Center(
              child: BadgeIcon(Icons.workspace_premium_outlined, size: 90),
            ),
            const SizedBox(height: 24),
            const Text(
              'E Health Premium',
              style: AppTypography.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your premium preview is active.',
              style: AppTypography.subtitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            for (final s in [
              'Detailed health trends',
              'Weekly and monthly reports',
              'Personalised wellbeing insights',
            ])
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.green,
                ),
                title: Text(s),
              ),
          ] else if (widget.title == 'Help & Support') ...[
            for (final s in [
              'How do I connect my ring?',
              'How should I wear my ring?',
              'How do health trends work?',
            ])
              Panel(
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(s),
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Keep your ring charged and wear it comfortably on your index finger. Open E Sync Ring from your profile to review the guided setup.',
                        style: AppTypography.subtitle,
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            const Brand(),
            const SizedBox(height: 30),
            const Panel(
              child: Text(
                'E Health helps you understand your daily wellbeing with the E Sync Smart Ring.\n\nVersion 1.0.0\nBluetooth discovery uses your phone’s native permissions. Wearable health sync awaits the verified device protocol; no demo readings are displayed.',
                style: AppTypography.subtitle,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
