import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/widgets/beam_ui.dart';
import '../../../../app/state/app_session_cubit.dart';
import '../../../../core/permissions/setup_permission_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../care/presentation/pages/care_screen.dart';
import '../../../membership/presentation/pages/membership_support_screen.dart';
import '../../../device_pairing/presentation/pages/my_devices_screen.dart';
import '../../../notifications/presentation/pages/notification_screen.dart';
import '../../../health_metrics/presentation/pages/beam_health_page.dart';

enum AccountView { privacy, platforms, security, data, settings }

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key, required this.view});
  final AccountView view;
  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final session = AppSessionCubit.instance;
  String healthStatus = 'Not connected';
  bool busy = false;
  void page(Widget child) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => child));
  void detail(String title, String message) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: beamNavy,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: beamMuted, height: 1.5),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
  String get title => switch (widget.view) {
    AccountView.privacy => 'Privacy & Consent',
    AccountView.platforms => 'Connected Platforms',
    AccountView.security => 'Security Settings',
    AccountView.data => 'Health Data',
    AccountView.settings => 'Settings',
  };
  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc?>();
    if (auth == null) return _screen(context);
    return BlocListener<AuthBloc, AuthState>(
      bloc: auth,
      listener: (context, state) {
        if (state.message != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message!)));
        }
      },
      child: _screen(context),
    );
  }

  Widget _screen(BuildContext context) => Theme(
    data: beamTheme(context),
    child: Scaffold(
      backgroundColor: const Color(0xFF00111C),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                for (final item in content())
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: item,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  List<Widget> content() => switch (widget.view) {
    AccountView.privacy => [
      tile(
        Icons.health_and_safety,
        const Color(0xFFA86CFF),
        'Health Data Permissions',
        () => page(const AccountSettingsScreen(view: AccountView.platforms)),
        subtitle: 'Manage data access',
      ),
      tile(
        Icons.people_alt,
        const Color(0xFF00E3BE),
        'Clinician Sharing',
        () => page(const CareScreen(view: CareView.access)),
        subtitle: 'Manage shared access',
      ),
      tile(
        Icons.nightlight,
        const Color(0xFF8265F8),
        'AI Data Preferences',
        () => detail(
          'AI Data',
          'AI service is not connected. No health data is sent to AI.',
        ),
        subtitle: 'Control data use',
      ),
      tile(
        Icons.extension,
        const Color(0xFF24B4FF),
        'Third-Party Integrations',
        () => page(const AccountSettingsScreen(view: AccountView.platforms)),
        subtitle: 'Connected health services',
      ),
      tile(
        Icons.description,
        const Color(0xFF328FFF),
        'Privacy Policy',
        () => showBeamLegal(context, 'Privacy Policy'),
      ),
      tile(
        Icons.description,
        beamCyan,
        'Terms of Service',
        () => showBeamLegal(context, 'Terms of Service'),
      ),
      const SizedBox(height: 10),
      danger(
        'Withdraw Consent',
        () => page(const CareScreen(view: CareView.access)),
      ),
    ],
    AccountView.platforms => [
      tile(
        Icons.android,
        const Color(0xFF36BB86),
        'Google Health Connect',
        connectHealth,
        subtitle: Theme.of(context).platform == TargetPlatform.android
            ? healthStatus
            : 'Android only',
      ),
      tile(
        Icons.favorite,
        const Color(0xFFFF4F84),
        'Apple Health',
        connectHealth,
        subtitle: Theme.of(context).platform == TargetPlatform.iOS
            ? healthStatus
            : 'iPhone only',
      ),
      const SizedBox(height: 8),
      const Text(
        'Data to Read',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      panel(
        Column(
          children: [
            for (final item in [
              ('Steps', Icons.directions_run, Color(0xFF00E3BE)),
              ('Heart Rate', Icons.favorite, Color(0xFFFF4F84)),
              ('Sleep', Icons.nightlight, Color(0xFFA86CFF)),
              ('Activity', Icons.bar_chart, Color(0xFF8265F8)),
            ])
              Row(
                children: [
                  orb(item.$2, item.$3),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item.$1, style: const TextStyle(fontSize: 13)),
                  ),
                  const Switch(value: false, onChanged: null),
                ],
              ),
          ],
        ),
      ),
      BeamButton(
        busy ? 'Connecting…' : 'Connect Health Platform',
        onPressed: busy ? null : connectHealth,
      ),
      tile(
        Icons.sync,
        beamCyan,
        'Last Sync',
        () => detail(
          'Health Sync',
          'Health platform import is not configured yet.',
        ),
        subtitle: 'Not synced',
      ),
    ],
    AccountView.security => [
      tile(
        Icons.shield,
        const Color(0xFF00D9AE),
        'Account Security',
        () => detail(
          'Account Security',
          'Authentication is managed by your connected account provider.',
        ),
        subtitle: 'Manage account access',
      ),
      tile(Icons.lock, beamCyan, 'Change Password', password),
      tile(
        Icons.phone_iphone,
        beamCyan,
        'Active Sessions',
        () => detail(
          'Active Sessions',
          'Session management is not available yet.',
        ),
      ),
      tile(Icons.email, beamCyan, 'Account Recovery', recovery),
      tile(
        Icons.verified_user,
        beamCyan,
        'Two-Step Verification',
        () => detail(
          'Two-Step Verification',
          'Two-step verification is not configured yet.',
        ),
        subtitle: 'Not configured',
      ),
      const SizedBox(height: 70),
      danger('Sign Out', signOut),
    ],
    AccountView.data => [
      tile(
        Icons.bar_chart,
        const Color(0xFF14BCF6),
        'Your Data',
        () => page(const BeamHealthPage(kind: BeamHealthKind.history)),
        subtitle: 'View recorded health data',
      ),
      tile(
        Icons.ios_share,
        beamCyan,
        'Export Data',
        () => detail('Export Data', 'Data export is not configured yet.'),
        subtitle: 'Download a copy',
      ),
      tile(
        Icons.delete,
        const Color(0xFFFF4F70),
        'Delete Data',
        () => detail(
          'Delete Data',
          'Health data deletion requests are not configured yet.',
        ),
        subtitle: 'Request data removal',
      ),
      tile(
        Icons.schedule,
        const Color(0xFF72A7EB),
        'Data Retention',
        () => detail(
          'Data Retention',
          'Health readings are currently stored for the signed-in session. The published retention policy is not configured.',
        ),
        subtitle: 'How data is stored',
      ),
    ],
    AccountView.settings => [
      panel(
        Column(
          children: [
            row(
              Icons.language,
              beamCyan,
              'Language',
              () => detail('Language', 'English is currently supported.'),
              value: 'English',
            ),
            row(
              Icons.straighten,
              beamCyan,
              'Units',
              () => detail(
                'Units',
                'Profile weight is stored in kilograms. Additional unit conversion is not configured.',
              ),
              value: 'Metric',
            ),
            row(
              Icons.nightlight,
              const Color(0xFF9C80FF),
              'Appearance',
              appearance,
              value: session.themeMode.name,
            ),
            row(
              Icons.accessibility_new,
              beamCyan,
              'Accessibility',
              () => detail(
                'Accessibility',
                'Text size and reduced motion follow your phone settings.',
              ),
            ),
            row(
              Icons.notifications,
              beamCyan,
              'Notifications',
              () => page(
                const BeamNotificationScreen(
                  view: NotificationView.preferences,
                ),
              ),
            ),
            row(
              Icons.watch_outlined,
              beamCyan,
              'Connected Devices',
              () => page(const MyDevicesScreen()),
            ),
          ],
        ),
      ),
      tile(
        Icons.info,
        beamCyan,
        'About',
        () => page(const MembershipSupportScreen(view: MemberView.about)),
        subtitle: 'Version 1.0.0',
      ),
    ],
  };
  Future<void> connectHealth() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await NativeSetupPermissionService().request('health');
      if (mounted) {
        setState(
          () => healthStatus = switch (result) {
            SetupPermissionResult.allowed => 'Read access allowed',
            SetupPermissionResult.requested => 'Access requested',
            SetupPermissionResult.denied => 'Access denied',
            SetupPermissionResult.unavailable => 'Unavailable',
          },
        );
      }
    } catch (_) {
      if (mounted) setState(() => healthStatus = 'Unavailable');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void appearance() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: beamNavy,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in ThemeMode.values)
            ListTile(
              title: Text(
                mode.name,
                style: const TextStyle(color: Colors.white),
              ),
              trailing: session.themeMode == mode
                  ? const Icon(Icons.check, color: beamCyan)
                  : null,
              onTap: () {
                session.theme(mode);
                Navigator.pop(context);
                setState(() {});
              },
            ),
        ],
      ),
    ),
  );
  void recovery() {
    final auth = context.read<AuthBloc?>();
    if (auth == null || session.email.isEmpty) {
      detail('Account Recovery', 'Sign in to manage account recovery.');
      return;
    }
    auth.add(AuthSubmitted(AuthAction.resetPassword, email: session.email));
    detail('Account Recovery', 'Recovery request submitted.');
  }

  Future<void> password() async {
    final auth = context.read<AuthBloc?>();
    if (auth == null) {
      detail('Change Password', 'Sign in to change your password.');
      return;
    }
    var text = '';
    final key = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: key,
          child: TextFormField(
            obscureText: true,
            onChanged: (v) => text = v,
            decoration: const InputDecoration(labelText: 'New password'),
            validator: (v) =>
                (v?.length ?? 0) < 8 ? 'Use at least 8 characters' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(context, text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value != null && mounted) {
      auth.add(AuthSubmitted(AuthAction.updatePassword, password: value));
    }
  }

  Future<void> signOut() async {
    final auth = context.read<AuthBloc?>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      if (auth != null) {
        auth.add(AuthSubmitted(AuthAction.signOut));
      } else {
        detail('Sign Out', 'No active account session.');
      }
    }
  }

  Widget row(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap, {
    String? value,
  }) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          if (value != null)
            Text(value, style: const TextStyle(color: beamMuted, fontSize: 11)),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: beamMuted, size: 20),
        ],
      ),
    ),
  );
  Widget tile(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap, {
    String? subtitle,
  }) => panel(
    InkWell(
      onTap: onTap,
      child: Row(
        children: [
          orb(icon, color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(color: beamMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: beamMuted, size: 21),
        ],
      ),
    ),
  );
  Widget danger(String text, VoidCallback onTap) => OutlinedButton.icon(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFFF4F70),
      side: const BorderSide(color: Color(0xFFFF4F70)),
      padding: const EdgeInsets.all(16),
    ),
    icon: Icon(text == 'Sign Out' ? Icons.logout : Icons.delete_outline),
    label: Text(text),
  );
  Widget panel(Widget child) => Container(
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
  Widget orb(IconData icon, Color color) => Container(
    width: 45,
    height: 45,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: .18),
    ),
    child: Icon(icon, color: color, size: 27),
  );
}
