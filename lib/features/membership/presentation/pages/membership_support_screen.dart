import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/widgets/beam_ui.dart';
import '../../../device_pairing/presentation/pages/device_flow_screen.dart';
import '../../../device_pairing/presentation/pages/discover_devices_screen.dart';
import '../../../ai_coach/presentation/pages/ai_coach_screen.dart';

enum MemberView {
  membership,
  details,
  subscription,
  support,
  request,
  legal,
  plans,
  checkout,
  billing,
  articles,
  requestStatus,
  about,
}

class MembershipSupportScreen extends StatefulWidget {
  const MembershipSupportScreen({super.key, this.view = MemberView.membership});
  final MemberView view;
  @override
  State<MembershipSupportScreen> createState() =>
      _MembershipSupportScreenState();
}

class _MembershipSupportScreenState extends State<MembershipSupportScreen> {
  bool yearly = false, picking = false;
  String payment = 'Card', category = 'Watch Connection', search = '';
  final subject = TextEditingController(),
      description = TextEditingController();
  final form = GlobalKey<FormState>();
  Uint8List? screenshot;
  static const purple = Color(0xFF9C57FF), gold = Color(0xFFFFCA55);
  static const benefits = [
    'Advanced AI Coach',
    'Personalized Goals',
    'Clinician Sharing',
    'Detailed Insights',
    'Priority Support',
  ];
  static const articles = [
    ('Connect your watch', Icons.watch_outlined, Color(0xFF19BEF5)),
    ('Sync problems', Icons.sync, Color(0xFF00E3AD)),
    ('Fix Bluetooth issues', Icons.bluetooth, beamCyan),
    ('Update firmware', Icons.settings, Color(0xFFB6DDFF)),
    ('Manage subscription', Icons.credit_card, purple),
    ('Use AI Coach', Icons.smart_toy, purple),
  ];
  @override
  void dispose() {
    subject.dispose();
    description.dispose();
    super.dispose();
  }

  void open(MemberView view) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MembershipSupportScreen(view: view),
    ),
  );
  void page(Widget widget) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => widget));
  void note(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  String get title => switch (widget.view) {
    MemberView.membership => 'E Health+',
    MemberView.details => 'E Health+ Premium',
    MemberView.subscription => 'Subscription',
    MemberView.support => 'Help & Support',
    MemberView.request => 'Support Request',
    MemberView.legal => 'Legal & About',
    MemberView.plans => 'Choose Your Plan',
    MemberView.checkout => 'Checkout',
    MemberView.billing => 'Billing History',
    MemberView.articles => 'Help Articles',
    MemberView.requestStatus => 'Request Status',
    MemberView.about => 'About',
  };
  @override
  Widget build(BuildContext context) => Theme(
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
    MemberView.membership => [
      hero(),
      const Text(
        'More insights. Better care.',
        textAlign: TextAlign.center,
        style: TextStyle(color: beamMuted, fontSize: 14),
      ),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Free Plan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Basic features included',
                        style: TextStyle(color: beamMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const BeamImage(
                  asset: BeamAssets.watch,
                  label: 'E Health Pulse Watch',
                  width: 86,
                  height: 112,
                ),
              ],
            ),
            for (final text in [
              'Watch Connection',
              'Health Tracking',
              'Standard Support',
            ])
              check(text),
          ],
        ),
      ),
      panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.workspace_premium, color: gold, size: 44),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Go Premium',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Explore E Health+ benefits.',
                        style: TextStyle(color: beamMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            for (final text in benefits)
              check(text, color: const Color(0xFF75CCFF)),
            const SizedBox(height: 18),
            button(
              'Upgrade to E Health+',
              () => open(MemberView.details),
              premium: true,
            ),
          ],
        ),
        premium: true,
      ),
      tile(
        Icons.credit_card,
        purple,
        'Manage Subscription',
        () => open(MemberView.subscription),
      ),
    ],
    MemberView.details => [
      hero(),
      const Text(
        'More personalized insights.',
        textAlign: TextAlign.center,
        style: TextStyle(color: beamMuted),
      ),
      panel(
        Column(
          children: [
            for (final item in benefits.indexed)
              tileBody(
                [
                  Icons.settings,
                  Icons.spa,
                  Icons.people,
                  Icons.bar_chart,
                  Icons.shield,
                ][item.$1],
                purple,
                item.$2,
              ),
          ],
        ),
      ),
      planCycle(),
      const Text(
        'Reference pricing · checkout not available',
        textAlign: TextAlign.center,
        style: TextStyle(color: beamMuted, fontSize: 11),
      ),
      button('Continue', () => open(MemberView.checkout)),
      TextButton(
        onPressed: () => open(MemberView.plans),
        child: const Text('Compare Plans'),
      ),
    ],
    MemberView.plans => [
      planCycle(),
      LayoutBuilder(
        builder: (context, box) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final premium in [false, true])
              SizedBox(
                width: (box.maxWidth - 12) / 2,
                child: panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        premium ? 'E Health+' : 'Free',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        premium ? (yearly ? '\$49.99' : '\$5.99') : '\$0',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        premium
                            ? (yearly ? 'per year' : 'per month')
                            : 'Basic plan',
                        style: const TextStyle(color: beamMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 22),
                      for (final text
                          in premium
                              ? [
                                  'AI insights',
                                  'Goals',
                                  'Care sharing',
                                  'Priority support',
                                ]
                              : [
                                  'Basic tracking',
                                  'Watch connection',
                                  'Support',
                                ])
                        check(text),
                      const SizedBox(height: 22),
                      button(
                        premium ? 'Select Plan' : 'Free Plan',
                        () => premium
                            ? open(MemberView.details)
                            : note('No paid subscription is configured.'),
                      ),
                    ],
                  ),
                  premium: premium,
                ),
              ),
          ],
        ),
      ),
      const Text(
        'Reference pricing. Availability is not configured.',
        style: TextStyle(color: beamMuted, fontSize: 11),
      ),
    ],
    MemberView.checkout => [
      premiumCard('Preview'),
      panel(
        Column(
          children: [
            for (final item in ['Card', 'Google Pay', 'Apple Pay'])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item, style: const TextStyle(fontSize: 14)),
                trailing: Icon(
                  payment == item
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: beamCyan,
                ),
                onTap: () => setState(() => payment = item),
              ),
          ],
        ),
      ),
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, color: beamMuted, size: 15),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              'Payments not connected',
              style: TextStyle(color: beamMuted, fontSize: 12),
            ),
          ),
        ],
      ),
      button(
        'Subscribe',
        () => note('Checkout is not configured. No payment was taken.'),
      ),
      const Text(
        'Pricing and terms require confirmation.',
        textAlign: TextAlign.center,
        style: TextStyle(color: beamMuted, fontSize: 11),
      ),
    ],
    MemberView.subscription => [
      premiumCard('Not subscribed'),
      tile(
        Icons.calendar_month,
        const Color(0xFFB6DDFF),
        'Renewal Date',
        () => note('No active subscription.'),
        subtitle: 'Not scheduled',
      ),
      tile(
        Icons.credit_card,
        const Color(0xFFB6DDFF),
        'Payment Method',
        () => note('No payment method saved.'),
        subtitle: 'Not configured',
      ),
      tile(
        Icons.swap_horiz,
        beamCyan,
        'Change Plan',
        () => open(MemberView.plans),
      ),
      tile(
        Icons.payments,
        beamCyan,
        'Manage Payment',
        () => open(MemberView.checkout),
      ),
      tile(
        Icons.receipt_long,
        beamCyan,
        'Billing History',
        () => open(MemberView.billing),
      ),
      OutlinedButton.icon(
        onPressed: () => note('No active subscription to cancel.'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF4F73),
          side: const BorderSide(color: Color(0xFFFF4F73)),
          padding: const EdgeInsets.all(16),
        ),
        icon: const Icon(Icons.cancel_outlined),
        label: const Text('Cancel Subscription'),
      ),
    ],
    MemberView.billing => [
      panel(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.receipt_long, color: beamMuted, size: 65),
              SizedBox(height: 18),
              Text(
                'No billing history',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Payments will appear here.',
                style: TextStyle(color: beamMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    ],
    MemberView.support => [
      searchField(),
      LayoutBuilder(
        builder: (context, box) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in [
              ('Watch & Connection', Icons.watch_outlined, purple),
              ('Sync & Data', Icons.sync, Color(0xFF00E3AD)),
              ('Account & Subscription', Icons.person, Color(0xFF18BCFA)),
              ('AI Coach', Icons.smart_toy, purple),
              ('Troubleshooting', Icons.build, gold),
              ('General', Icons.chat, Color(0xFF18BCFA)),
            ])
              if (search.isEmpty ||
                  item.$1.toLowerCase().contains(search.toLowerCase()))
                SizedBox(
                  width: (box.maxWidth - 12) / 2,
                  child: InkWell(
                    onTap: () => open(MemberView.articles),
                    child: panel(
                      Column(
                        children: [
                          Icon(item.$2, color: item.$3, size: 38),
                          const SizedBox(height: 18),
                          Text(
                            item.$1,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      color: item.$3,
                    ),
                  ),
                ),
          ],
        ),
      ),
      button(
        'Contact Support',
        () => open(MemberView.request),
        icon: Icons.chat_bubble,
      ),
    ],
    MemberView.articles => [
      searchField(),
      for (final item in articles)
        if (search.isEmpty ||
            item.$1.toLowerCase().contains(search.toLowerCase()))
          tile(item.$2, item.$3, item.$1, () => article(item.$1)),
      button('Contact Support', () => open(MemberView.request)),
    ],
    MemberView.request => [
      Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading('Issue Category'),
            const SizedBox(height: 10),
            panel(
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: category,
                  dropdownColor: beamNavy,
                  items: [
                    for (final value in [
                      'Watch Connection',
                      'Sync & Data',
                      'Account',
                      'Subscription',
                      'AI Coach',
                      'Other',
                    ])
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
                  onChanged: (v) => setState(() => category = v!),
                ),
              ),
            ),
            const SizedBox(height: 20),
            heading('Subject'),
            const SizedBox(height: 10),
            field(subject, 'Briefly describe the issue'),
            const SizedBox(height: 20),
            heading('Description'),
            const SizedBox(height: 10),
            field(description, 'What happened?', lines: 4),
            const SizedBox(height: 20),
            heading('Add Screenshot (optional)'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                if (screenshot != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          screenshot!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: IconButton(
                          tooltip: 'Remove screenshot',
                          onPressed: () => setState(() => screenshot = null),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                OutlinedButton(
                  onPressed: picking ? null : pick,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(25),
                  ),
                  child: const Column(children: [Icon(Icons.add), Text('Add')]),
                ),
              ],
            ),
            const SizedBox(height: 24),
            button('Submit Request', () {
              if (form.currentState!.validate()) {
                open(MemberView.requestStatus);
              }
            }),
          ],
        ),
      ),
    ],
    MemberView.requestStatus => [
      const SizedBox(height: 60),
      const Center(child: Icon(Icons.error_outline, color: gold, size: 70)),
      const SizedBox(height: 20),
      const Text(
        'Request Not Sent',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      ),
      const Text(
        'Support service is not connected yet.',
        textAlign: TextAlign.center,
        style: TextStyle(color: beamMuted, fontSize: 14),
      ),
      const SizedBox(height: 50),
      button('Back to Request', () => Navigator.pop(context)),
      TextButton(
        onPressed: () => open(MemberView.support),
        child: const Text('Help & Support'),
      ),
    ],
    MemberView.legal => [
      for (final item in [
        ('Terms of Service', Icons.description),
        ('Privacy Policy', Icons.shield),
        ('Data Protection', Icons.verified_user),
        ('Wellness Disclaimer', Icons.health_and_safety),
      ])
        tile(item.$2, beamCyan, item.$1, () => legal(item.$1)),
      tile(
        Icons.code,
        beamCyan,
        'Open Source Licenses',
        () => showLicensePage(
          context: context,
          applicationName: 'E Health',
          applicationVersion: '1.0.0',
        ),
      ),
      tile(
        Icons.smart_toy,
        purple,
        'E Health',
        () => open(MemberView.about),
        subtitle: 'Version 1.0.0',
      ),
    ],
    MemberView.about => [
      panel(
        const Row(
          children: [
            Icon(Icons.smart_toy, color: beamCyan, size: 52),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'E Health',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 7),
                  Text('Version 1.0.0', style: TextStyle(color: beamMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
      const Text(
        'Your wellness companion.\nTrack. Improve. Stay healthy.',
        textAlign: TextAlign.center,
        style: TextStyle(color: beamMuted, height: 1.6),
      ),
      for (final item in [
        ('Terms of Service', Icons.description),
        ('Privacy Policy', Icons.shield),
        ('Data Protection', Icons.verified_user),
        ('Wellness Disclaimer', Icons.health_and_safety),
      ])
        tile(item.$2, beamCyan, item.$1, () => legal(item.$1)),
    ],
  };
  void article(String title) {
    if (title == 'Connect your watch' || title == 'Fix Bluetooth issues') {
      page(const DiscoverDevicesScreen());
    } else if (title == 'Update firmware') {
      page(const DeviceFlowScreen(view: DeviceView.firmware));
    } else if (title == 'Sync problems') {
      page(const DeviceFlowScreen(view: DeviceView.troubleshooting));
    } else if (title == 'Manage subscription') {
      open(MemberView.subscription);
    } else {
      page(const AiCoachScreen());
    }
  }

  void legal(String title) {
    if (title == 'Wellness Disclaimer') {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: beamNavy,
        showDragHandle: true,
        builder: (_) => const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'E Health provides general wellness information. It is not a medical diagnosis or treatment service.',
              style: TextStyle(color: beamMuted, height: 1.5),
            ),
          ),
        ),
      );
    } else {
      showBeamLegal(context, title);
    }
  }

  Future<void> pick() async {
    setState(() => picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (mounted && bytes.length <= 5 * 1024 * 1024) {
          setState(() => screenshot = bytes);
        } else if (mounted) {
          note('Choose an image under 5 MB.');
        }
      }
    } catch (_) {
      if (mounted) note('Could not open photo library.');
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Widget hero() => SizedBox(
    height: 130,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: .45,
            child: Image.asset(
              'assets/beam/images/beam-wellness-mountains.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const Icon(Icons.workspace_premium, color: gold, size: 70),
      ],
    ),
  );
  Widget premiumCard(String status) => panel(
    Row(
      children: [
        const Icon(Icons.workspace_premium, color: gold, size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'E Health+ Premium',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                status,
                style: const TextStyle(color: beamCyan, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                'Reference: \$5.99 / month',
                style: TextStyle(color: beamMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
    premium: true,
  );
  Widget planCycle() => Column(
    children: [
      SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: false, label: Text('Monthly')),
          ButtonSegment(value: true, label: Text('Yearly')),
        ],
        selected: {yearly},
        onSelectionChanged: (v) => setState(() => yearly = v.first),
      ),
      const SizedBox(height: 12),
      Text(
        yearly ? '\$49.99 / year' : '\$5.99 / month',
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
    ],
  );
  Widget searchField() => TextField(
    onChanged: (v) => setState(() => search = v),
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: 'Search help articles…',
      hintStyle: const TextStyle(color: beamMuted),
      prefixIcon: const Icon(Icons.search, color: beamMuted),
      filled: true,
      fillColor: const Color(0xFF002333),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: beamBorder),
      ),
    ),
  );
  Widget field(
    TextEditingController controller,
    String hint, {
    int lines = 1,
  }) => TextFormField(
    controller: controller,
    maxLines: lines,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: beamMuted),
      filled: true,
      fillColor: const Color(0xFF002333),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: beamBorder),
      ),
    ),
  );
  Widget heading(String text) => Text(
    text,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );
  Widget check(String text, {Color color = const Color(0xFF00E3AD)}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(Icons.check_circle, color: color, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFFD7E3F0)),
          ),
        ),
      ],
    ),
  );
  Widget tileBody(
    IconData icon,
    Color color,
    String title, {
    String? subtitle,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: .18),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
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
        const Icon(Icons.chevron_right, color: beamMuted, size: 20),
      ],
    ),
  );
  Widget tile(
    IconData icon,
    Color color,
    String title,
    VoidCallback tap, {
    String? subtitle,
  }) => panel(
    InkWell(
      onTap: tap,
      child: tileBody(icon, color, title, subtitle: subtitle),
    ),
  );
  Widget panel(Widget child, {bool premium = false, Color color = beamCyan}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: premium
                ? purple.withValues(alpha: .6)
                : color.withValues(alpha: .3),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: premium
                ? const [Color(0xFF482294), Color(0xFF12233F)]
                : [
                    Color.alphaBlend(
                      color.withValues(alpha: .07),
                      const Color(0xFF001A29),
                    ),
                    const Color(0xFF00131F),
                  ],
          ),
        ),
        child: child,
      );
  Widget button(
    String text,
    VoidCallback tap, {
    bool premium = false,
    IconData? icon,
  }) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      gradient: LinearGradient(
        colors: premium
            ? const [Color(0xFF00D8EC), Color(0xFF9C75FF)]
            : const [Color(0xFF00C8ED), Color(0xFF00F0E6)],
      ),
    ),
    child: TextButton(
      onPressed: tap,
      style: TextButton.styleFrom(
        foregroundColor: beamNavy,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 23),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
}
