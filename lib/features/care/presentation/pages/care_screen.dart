import 'package:flutter/material.dart';

import '../../../../shared/widgets/beam_ui.dart';
import '../../../health_metrics/domain/health_reading.dart';

enum CareView { home, connect, consent, summary, goals, access }

/// Care UI is ready for a verified clinician service. No health data is sent
/// until server-side identity and consent enforcement are configured.
class CareScreen extends StatefulWidget {
  const CareScreen({super.key, this.view = CareView.home, this.clinician});
  final CareView view;
  final String? clinician;
  @override
  State<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends State<CareScreen> {
  bool code = false;
  final input = TextEditingController();
  final form = GlobalKey<FormState>();
  final selected = <String>{'Steps', 'Heart Rate', 'Sleep', 'Activity'};
  String duration = '3 Months';
  String filter = 'Pending';
  final cyan = const Color(0xFF00DDEB);
  static const metrics = [
    ('activity', 'Steps', Color(0xFF00E891), HealthMetricType.steps),
    ('heart', 'Heart Rate', Color(0xFFFF426B), HealthMetricType.heartRate),
    ('moon', 'Sleep', Color(0xFFA44FFF), HealthMetricType.sleep),
    ('chart', 'Activity', Color(0xFF0BAAF3), null),
  ];
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void open(CareView view) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CareScreen(view: view, clinician: widget.clinician),
    ),
  );
  void unavailable() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Clinician service is not connected yet.')),
  );
  String get title => switch (widget.view) {
    CareView.home => 'My Care',
    CareView.connect => 'Connect Clinician',
    CareView.consent => 'Share Health Data',
    CareView.summary => 'Shared Summary',
    CareView.goals => 'Goals from Clinician',
    CareView.access => 'Manage Access',
  };
  @override
  Widget build(BuildContext context) => Theme(
    data: beamTheme(context),
    child: Scaffold(
      backgroundColor: const Color(0xFF00111C),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                BeamTabHeader(
                  title: title,
                  padding: EdgeInsets.zero,
                  trailing: widget.view == CareView.home
                      ? BeamHeaderAction(
                          icon: Icons.add_rounded,
                          tooltip: 'Connect clinician',
                          onPressed: () => open(CareView.connect),
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                for (final item in content())
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
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
    CareView.home => [
      clinicianCard(onTap: () => open(CareView.summary)),
      panel(
        Row(
          children: [
            orb('footprints', const Color(0xFF00E891)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sharing Inactive',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Connect a clinician first.',
                    style: TextStyle(color: beamMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Switch(value: false, onChanged: null),
          ],
        ),
      ),
      heading('Shared Goals', () => open(CareView.goals)),
      Row(
        children: [
          for (final item in [metrics[0], metrics[2], metrics[3]])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () => open(CareView.goals),
                  child: panel(
                    Column(
                      children: [
                        orb(item.$1, item.$3),
                        const SizedBox(height: 10),
                        Text(item.$2, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    color: item.$3,
                  ),
                ),
              ),
            ),
        ],
      ),
      tile('gear', 'Manage Access', () => open(CareView.access)),
      primary(
        'Connect Clinician',
        () => open(CareView.connect),
        icon: Icons.person_add_alt_1,
      ),
    ],
    CareView.connect => [
      SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: false, label: Text('Invite')),
          ButtonSegment(value: true, label: Text('Code')),
        ],
        selected: {code},
        onSelectionChanged: (value) => setState(() {
          code = value.first;
          input.clear();
        }),
      ),
      Form(
        key: form,
        child: TextFormField(
          controller: input,
          keyboardType: code ? TextInputType.text : TextInputType.emailAddress,
          autocorrect: false,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.person_outline, color: beamMuted),
            hintText: code ? 'Connection code' : 'Clinician email',
            hintStyle: const TextStyle(color: beamMuted),
            filled: true,
            fillColor: const Color(0xFF002232),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: beamBorder),
            ),
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            return code
                ? (text.length < 4 ? 'Enter a valid code' : null)
                : (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)
                      ? 'Enter a valid email'
                      : null);
          },
        ),
      ),
      clinicianCard(),
      const Text(
        'Review their identity before sharing.',
        style: TextStyle(color: beamMuted, fontSize: 13),
      ),
      primary(code ? 'Verify Code' : 'Send Request', () {
        if (form.currentState!.validate()) unavailable();
      }),
      heading('Request Status', null),
      panel(
        Column(
          children: [
            for (final item in [
              ('clock', 'Pending', Color(0xFFFFBE33)),
              ('check', 'Accepted', Color(0xFF00E891)),
              ('back', 'Rejected', Color(0xFFFF426B)),
            ])
              InkWell(
                onTap: () => setState(() => filter = item.$2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      BeamIcon(item.$1, color: item.$3, size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.$2,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Icon(
                        filter == item.$2
                            ? Icons.expand_more
                            : Icons.chevron_right,
                        color: beamMuted,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      Text(
        'No ${filter.toLowerCase()} requests.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: beamMuted, fontSize: 13),
      ),
      TextButton(
        onPressed: () => open(CareView.consent),
        child: const Text('Preview Sharing Options'),
      ),
    ],
    CareView.consent => [
      clinicianCard(),
      heading('Select Data to Share', null),
      panel(
        Column(
          children: [
            for (final item in metrics)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: orb(item.$1, item.$3),
                title: Text(item.$2, style: const TextStyle(fontSize: 14)),
                value: selected.contains(item.$2),
                activeThumbColor: Colors.white,
                activeTrackColor: cyan,
                onChanged: (value) => setState(() {
                  if (value) {
                    selected.add(item.$2);
                  } else {
                    selected.remove(item.$2);
                  }
                }),
              ),
          ],
        ),
      ),
      heading('Access Duration', null),
      panel(
        Row(
          children: [
            BeamIcon('calendar', color: const Color(0xFF0BAAF3)),
            const SizedBox(width: 15),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: duration,
                  dropdownColor: beamNavy,
                  items: [
                    for (final value in ['1 Month', '3 Months', '6 Months'])
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => duration = value!),
                ),
              ),
            ),
          ],
        ),
      ),
      primary(
        'Confirm Sharing',
        selected.isEmpty
            ? null
            : () {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sharing Unavailable'),
                    content: const Text(
                      'Verify and connect a clinician before sharing data.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got It'),
                      ),
                    ],
                  ),
                );
              },
      ),
      panel(
        const Row(
          children: [
            Icon(Icons.info, color: Color(0xFF6A8DFF)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Read-only access. Stop sharing anytime.',
                style: TextStyle(color: beamMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    ],
    CareView.summary => [
      clinicianCard(onTap: () => open(CareView.access)),
      heading('Data Shared', null),
      LayoutBuilder(
        builder: (context, box) => Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in metrics)
              SizedBox(
                width: (box.maxWidth - 10) / 2,
                child: panel(
                  Row(
                    children: [
                      orb(item.$1, item.$3, size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.$2, style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 8),
                            const Text(
                              'Not shared',
                              style: TextStyle(color: beamMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      tile('calendar', 'Sharing Period', null, subtitle: 'No active consent'),
      primary('Update Access', () => open(CareView.consent)),
      const Text(
        'No data is currently shared.',
        textAlign: TextAlign.center,
        style: TextStyle(color: beamMuted, fontSize: 12),
      ),
    ],
    CareView.goals => [
      clinicianCard(),
      for (final item in [
        ('activity', 'Steps', Color(0xFF00E891)),
        ('moon', 'Sleep', Color(0xFFA44FFF)),
        ('flame', 'Activity', Color(0xFFFFBE33)),
      ])
        panel(
          Row(
            children: [
              orb(item.$1, item.$3),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$2,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'No assigned goal',
                      style: TextStyle(color: beamMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: 0,
                      color: item.$3,
                      backgroundColor: const Color(0xFF073A4B),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      tile(
        'clock',
        'Goal History',
        () => ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No goal history yet.'))),
      ),
      primary('Connect Clinician', () => open(CareView.connect)),
    ],
    CareView.access => [
      clinicianCard(),
      panel(
        const Column(
          children: [
            Icon(Icons.people_outline, size: 60, color: beamMuted),
            SizedBox(height: 14),
            Text(
              'No authorized clinicians',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'You control who sees your data.',
              style: TextStyle(color: beamMuted, fontSize: 13),
            ),
          ],
        ),
      ),
      primary(
        'Connect Another Clinician',
        () => open(CareView.connect),
        icon: Icons.add,
      ),
      tile('shield', 'Sharing Options', () => open(CareView.consent)),
    ],
  };
  Widget clinicianCard({VoidCallback? onTap}) => panel(
    InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF043449),
              border: Border.all(color: cyan.withValues(alpha: .25)),
            ),
            child: const Center(
              child: BeamIcon('doctor', size: 39, color: Color(0xFFB6EBFF)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.clinician ?? 'Your Clinician',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Not connected',
                  style: TextStyle(color: beamMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          if (onTap != null) const Icon(Icons.chevron_right, color: beamMuted),
        ],
      ),
    ),
  );
  Widget heading(String text, VoidCallback? onTap) => InkWell(
    onTap: onTap,
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        if (onTap != null) const Icon(Icons.chevron_right, color: beamMuted),
      ],
    ),
  );
  Widget tile(
    String icon,
    String title,
    VoidCallback? onTap, {
    String? subtitle,
  }) => panel(
    InkWell(
      onTap: onTap,
      child: Row(
        children: [
          orb(icon, const Color(0xFF0BAAF3)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
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
          if (onTap != null) const Icon(Icons.chevron_right, color: beamMuted),
        ],
      ),
    ),
  );
  Widget primary(String label, VoidCallback? onTap, {IconData? icon}) =>
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF00C8ED), Color(0xFF00F0E6)],
          ),
        ),
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: beamNavy,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 24),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  Widget panel(Widget child, {Color color = beamCyan}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: color.withValues(alpha: .30), width: 1),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(
            color.withValues(alpha: .06),
            const Color(0xFF001A29),
          ),
          const Color(0xFF00131F),
        ],
      ),
    ),
    child: child,
  );
  Widget orb(String icon, Color color, {double size = 44}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: .16),
    ),
    child: Center(
      child: BeamIcon(icon, color: color, size: size * .6),
    ),
  );
}
