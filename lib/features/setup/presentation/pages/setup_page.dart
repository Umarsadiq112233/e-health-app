import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/navigation/app_page_route.dart';
import '../../../../app/state/app_session_cubit.dart';
import '../../../../core/permissions/setup_permission_service.dart';
import '../../../../shared/widgets/beam_ui.dart';
import '../../../onboarding/presentation/cubit/app_flow_cubit.dart';

class SetupPage extends StatefulWidget {
  final bool consent, editing;
  final SetupPermissionService? permissions;
  const SetupPage({
    super.key,
    this.consent = false,
    this.editing = false,
    this.permissions,
  });
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final form = GlobalKey<FormState>();
  late String name, weight;
  late Map<String, dynamic> wellness;
  late Map<String, bool> permissions;
  late final permissionService =
      widget.permissions ?? NativeSetupPermissionService();
  final results = <String, SetupPermissionResult>{};
  bool accepted = false, saving = false;
  String? error, requesting;
  DateTime? birthday;
  String gender = 'Not specified', units = 'metric';
  double height = 175;
  int steps = 8000, active = 60;
  double sleep = 7.5;
  final preferences = <String>{};
  @override
  void initState() {
    super.initState();
    final setup = context.read<AppFlowCubit>().state.setup;
    name = setup.profileComplete ? setup.name : AppSessionCubit.instance.name;
    weight = setup.weight;
    wellness = Map.from(setup.wellness);
    permissions = Map.from(setup.permissions);
    accepted = setup.consentComplete;
    birthday = DateTime.tryParse(wellness['birthday']?.toString() ?? '');
    gender = wellness['gender']?.toString() ?? gender;
    units = wellness['units']?.toString() ?? units;
    height = (wellness['heightCm'] as num?)?.toDouble() ?? height;
    steps = (wellness['steps'] as num?)?.toInt() ?? steps;
    sleep = (wellness['sleepHours'] as num?)?.toDouble() ?? sleep;
    active = (wellness['activeMinutes'] as num?)?.toInt() ?? active;
    preferences.addAll(
      (wellness['preferences'] as List?)?.whereType<String>() ?? [],
    );
  }

  Future<void> submit() async {
    if (saving || requesting != null || (widget.consent && !accepted)) return;
    if (!widget.consent && !(form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final flow = context.read<AppFlowCubit>();
      if (widget.consent) {
        await flow.finishConsent(permissions);
      } else {
        await flow.finishProfile(
          name.trim(),
          weight.trim(),
          wellness: {
            ...wellness,
            'birthday': birthday?.toIso8601String(),
            'gender': gender,
            'heightCm': height,
            'units': units,
            'steps': steps,
            'sleepHours': sleep,
            'activeMinutes': active,
            'preferences': preferences.toList(),
          },
        );
      }
      if (mounted && widget.editing) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void back() {
    if (saving || requesting != null) return;
    if (widget.editing) {
      Navigator.pop(context);
    } else if (widget.consent) {
      Navigator.push(
        context,
        AppPageRoute<void>(
          reducedMotion: MediaQuery.disableAnimationsOf(context),
          builder: (_) => const SetupPage(editing: true),
        ),
      );
    }
  }

  Future<void> request(String key) async {
    if (requesting != null || saving) return;
    setState(() {
      requesting = key;
      error = null;
    });
    try {
      final result = await permissionService.request(key);
      if (!mounted) return;
      setState(() {
        results[key] = result;
        permissions[key] = result == SetupPermissionResult.allowed;
        if (key == 'health') {
          permissions['healthRequested'] =
              result == SetupPermissionResult.requested;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not request permission. Try Settings.');
      }
    } finally {
      if (mounted) setState(() => requesting = null);
    }
  }

  Widget panel(String icon, String title, Widget child, {String? subtitle}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00283B), Color(0xFF001827)],
          ),
          border: Border.all(color: beamBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFF004459),
                    shape: BoxShape.circle,
                  ),
                  child: BeamIcon(icon, size: 16),
                ),
                const SizedBox(width: 9),
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
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: beamMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
  InputDecoration decoration(String label, String icon) => InputDecoration(
    isDense: true,
    prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 36),
    suffixIconConstraints: const BoxConstraints(minWidth: 22, minHeight: 36),
    labelText: label,
    labelStyle: const TextStyle(fontSize: 11, color: beamMuted),
    prefixIcon: Padding(
      padding: const EdgeInsets.all(8),
      child: BeamIcon(icon, size: 15, color: beamMuted),
    ),
    filled: true,
    fillColor: const Color(0xFF001D2D),
    contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: beamBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: beamBorder),
    ),
  );
  Widget pair(Widget left, Widget right) => LayoutBuilder(
    builder: (context, box) =>
        box.maxWidth < 275 || MediaQuery.textScalerOf(context).scale(12) > 17
        ? Column(children: [left, const SizedBox(height: 10), right])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 8),
              Expanded(child: right),
            ],
          ),
  );
  Widget choice(String title, String value, String icon, VoidCallback action) =>
      InkWell(
        onTap: saving ? null : action,
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          decoration: decoration(title, icon).copyWith(
            suffixIcon: const Icon(
              Icons.keyboard_arrow_down,
              size: 17,
              color: beamMuted,
            ),
          ),
          child: Text(value, style: const TextStyle(fontSize: 12)),
        ),
      );
  Future<void> chooseGender() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final choice in ['Not specified', 'Male', 'Female', 'Other'])
              ListTile(
                title: Text(choice),
                trailing: choice == gender
                    ? const BeamIcon('check', size: 18)
                    : null,
                onTap: () => Navigator.pop(context, choice),
              ),
          ],
        ),
      ),
    );
    if (value != null && mounted) setState(() => gender = value);
  }

  Future<void> chooseBirthday() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: birthday ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (result != null && mounted) setState(() => birthday = result);
  }

  Future<void> chooseHeight() async {
    final controller = TextEditingController(
      text: (units == 'metric' ? height : height / 2.54).toStringAsFixed(1),
    );
    final key = GlobalKey<FormState>();
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(units == 'metric' ? 'Height (cm)' : 'Height (in)'),
        content: Form(
          key: key,
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              final number = double.tryParse(v ?? '');
              final cm = number == null
                  ? 0
                  : units == 'metric'
                  ? number
                  : number * 2.54;
              return cm >= 50 && cm <= 250 ? null : 'Enter a valid height';
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(context, double.parse(controller.text));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && mounted) {
      setState(() => height = units == 'metric' ? value : value * 2.54);
    }
  }

  Widget profile() => Form(
    key: form,
    child: Column(
      children: [
        panel(
          'users',
          'Personal Information',
          Column(
            children: [
              pair(
                TextFormField(
                  initialValue: name,
                  enabled: !saving,
                  decoration: decoration('Full Name', 'person'),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (v) => name = v,
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Enter your name' : null,
                ),
                choice(
                  'Date of Birth',
                  birthday == null
                      ? 'Choose date'
                      : '${birthday!.day}/${birthday!.month}/${birthday!.year}',
                  'calendar',
                  chooseBirthday,
                ),
              ),
              const SizedBox(height: 10),
              pair(
                choice('Gender', gender, 'gender', chooseGender),
                choice(
                  'Height',
                  '${(units == 'metric' ? height : height / 2.54).toStringAsFixed(0)} ${units == 'metric' ? 'cm' : 'in'}',
                  'ruler',
                  chooseHeight,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: ValueKey(units),
                initialValue: units == 'metric'
                    ? weight
                    : ((double.tryParse(weight) ?? 70) * 2.2046226)
                          .toStringAsFixed(1),
                enabled: !saving,
                decoration: decoration(
                  units == 'metric' ? 'Weight (kg)' : 'Weight (lb)',
                  'lock',
                ),
                style: const TextStyle(fontSize: 12),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (v) => weight = units == 'metric'
                    ? v
                    : ((double.tryParse(v) ?? 0) / 2.2046226).toStringAsFixed(
                        2,
                      ),
                validator: (v) {
                  final number = double.tryParse(v ?? '');
                  final kg = number == null
                      ? 0
                      : units == 'metric'
                      ? number
                      : number / 2.2046226;
                  return kg >= 20 && kg <= 400 ? null : 'Enter a valid weight';
                },
              ),
            ],
          ),
        ),
        panel(
          'gear',
          'Measurement Units',
          Row(
            children: [
              for (final unit in [
                ('metric', 'Metric (kg, cm)'),
                ('imperial', 'Imperial (lb, ft)'),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      backgroundColor: const Color(0xFF001D2D),
                      selectedColor: beamCyan,
                      side: const BorderSide(color: beamBorder),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      label: Text(
                        unit.$2,
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: units == unit.$1,
                      showCheckmark: false,
                      onSelected: saving
                          ? null
                          : (_) => setState(() => units = unit.$1),
                    ),
                  ),
                ),
            ],
          ),
        ),
        panel(
          'target',
          'Daily Goals',
          LayoutBuilder(
            builder: (context, box) {
              final cards = [
                goal(
                  'steps',
                  'Steps',
                  steps.toString(),
                  'steps per day',
                  () =>
                      setState(() => steps = (steps - 500).clamp(1000, 50000)),
                  () =>
                      setState(() => steps = (steps + 500).clamp(1000, 50000)),
                ),
                goal(
                  'moon',
                  'Sleep',
                  sleep.toStringAsFixed(1),
                  'hours per day',
                  () => setState(() => sleep = (sleep - .5).clamp(4, 12)),
                  () => setState(() => sleep = (sleep + .5).clamp(4, 12)),
                ),
                goal(
                  'flame',
                  'Active',
                  active.toString(),
                  'minutes per day',
                  () => setState(() => active = (active - 5).clamp(5, 180)),
                  () => setState(() => active = (active + 5).clamp(5, 180)),
                ),
              ];
              return box.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(12) > 17
                  ? Column(
                      children: [
                        for (final card in cards)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: card,
                          ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final card in cards)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: card,
                            ),
                          ),
                      ],
                    );
            },
          ),
        ),
        panel(
          'heart',
          'Wellness Preferences',
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in [
                ('moon', 'Better Sleep'),
                ('feather', 'Manage Stress'),
                ('activity', 'Stay Active'),
                ('apple', 'Healthy Nutrition'),
                ('chart', 'Weight Management'),
                ('shield', 'Overall Wellness'),
              ])
                FilterChip(
                  showCheckmark: false,
                  backgroundColor: const Color(0xFF001D2D),
                  selectedColor: const Color(0xFF00506A),
                  side: BorderSide(
                    color: preferences.contains(item.$2)
                        ? beamCyan
                        : beamBorder,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  avatar: BeamIcon(item.$1, size: 12),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.$2,
                        style: TextStyle(
                          fontSize: 9,
                          color: preferences.contains(item.$2)
                              ? Colors.white
                              : beamMuted,
                        ),
                      ),
                      if (preferences.contains(item.$2)) ...[
                        const SizedBox(width: 5),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            color: beamCyan,
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.check, size: 10, color: beamNavy),
                          ),
                        ),
                      ],
                    ],
                  ),
                  selected: preferences.contains(item.$2),
                  onSelected: saving
                      ? null
                      : (value) => setState(() {
                          value
                              ? preferences.add(item.$2)
                              : preferences.remove(item.$2);
                        }),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget goal(
    String icon,
    String label,
    String value,
    String unit,
    VoidCallback minus,
    VoidCallback plus,
  ) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFF001F31),
      border: Border.all(color: beamBorder),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            BeamIcon(
              icon,
              size: 18,
              color: icon == 'moon'
                  ? const Color(0xFFAC95FF)
                  : icon == 'flame'
                  ? const Color(0xFFFF6475)
                  : beamCyan,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 9, color: beamMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
        ),
        Text(unit, style: const TextStyle(fontSize: 9, color: beamMuted)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: IconButton(
                tooltip: 'Decrease $label',
                constraints: const BoxConstraints(minHeight: 32),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: saving ? null : minus,
                icon: const Icon(Icons.remove, size: 18),
              ),
            ),
            Expanded(
              child: IconButton(
                tooltip: 'Increase $label',
                constraints: const BoxConstraints(minHeight: 32),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: saving ? null : plus,
                icon: const Icon(Icons.add, size: 18),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  Widget permissionCards() => Column(
    children: [
      for (final item in [
        (
          'bluetooth',
          'bluetooth',
          'Bluetooth',
          'Connect and sync your E Health Pulse.',
        ),
        (
          'notifications',
          'bell',
          'Notifications',
          'Reminders and health updates.',
        ),
        (
          'health',
          'heart',
          'Health Connect / HealthKit',
          'Connect steps, heart rate and sleep.',
        ),
        ('location', 'pin', 'Location (Optional)', 'Nearby activity insights.'),
      ])
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00283B), Color(0xFF001827)],
            ),
            border: Border.all(color: beamBorder),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF004459),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: BeamIcon(
                  item.$2,
                  size: 21,
                  color: item.$1 == 'health'
                      ? const Color(0xFFFF627F)
                      : item.$1 == 'notifications'
                      ? const Color(0xFF41BBFF)
                      : beamCyan,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$3,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.$4,
                      style: const TextStyle(
                        fontSize: 10,
                        color: beamMuted,
                        height: 1.4,
                      ),
                    ),
                    if (results[item.$1] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: BeamReveal(
                          key: ValueKey(results[item.$1]),
                          child: Text(
                            switch (results[item.$1]!) {
                              SetupPermissionResult.allowed => 'Allowed',
                              SetupPermissionResult.denied => 'Not allowed',
                              SetupPermissionResult.unavailable =>
                                'Unavailable on this device',
                              SetupPermissionResult.requested =>
                                'Access requested',
                            },
                            style: const TextStyle(
                              fontSize: 10,
                              color: beamCyan,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              SizedBox(
                width: 86,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [beamCyan, Color(0xFF81FFF4)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(86, 28),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          foregroundColor: beamNavy,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: requesting != null || saving
                            ? null
                            : () => request(item.$1),
                        child: Text(
                          requesting == item.$1
                              ? 'Requesting…'
                              : permissions[item.$1] == true
                              ? 'Allowed'
                              : 'Allow',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(86, 26),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: requesting != null || saving
                          ? null
                          : () => setState(() {
                              permissions[item.$1] = false;
                              results.remove(item.$1);
                            }),
                      child: const Text('Skip', style: TextStyle(fontSize: 10)),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(86, 24),
                        padding: const EdgeInsets.all(2),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: requesting != null
                          ? null
                          : () async {
                              final opened = await permissionService.manage();
                              if (!opened && mounted) {
                                setState(
                                  () => error = 'Settings are unavailable on this device.',
                                );
                              }
                            },
                      child: const Text(
                        'Manage',
                        style: TextStyle(fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF002235),
          border: Border.all(color: beamBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: accepted,
            onChanged: saving
                ? null
                : (v) => setState(() => accepted = v ?? false),
            title: const Text(
              'Your privacy matters',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'I agree to the Privacy Policy.',
              style: TextStyle(fontSize: 10, color: beamMuted),
            ),
          ),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Theme(
    data: beamTheme(context),
    child: PopScope(
      canPop: widget.editing && !saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) back();
      },
      child: Scaffold(
        backgroundColor: beamNavy,
        body: SafeArea(
          child: BeamReveal(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Back',
                            onPressed: widget.consent || widget.editing
                                ? back
                                : null,
                            icon: const BeamIcon('back', color: beamMuted),
                          ),
                          const Expanded(
                            child: Center(
                              child: BeamLogo(width: 90, horizontal: true),
                            ),
                          ),
                          TextButton(
                            onPressed: saving || requesting != null
                                ? null
                                : () {
                                    if (widget.consent) {
                                      setState(() => permissions = {});
                                    } else {
                                      submit();
                                    }
                                  },
                            child: Text(
                              widget.consent ? 'Skip All' : 'Skip',
                              style: const TextStyle(
                                fontSize: 10,
                                color: beamCyan,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 100),
                      child: Row(
                        children: [
                          for (var i = 0; i < 4; i++)
                            Expanded(
                              child: Container(
                                height: 4,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: i == (widget.consent ? 1 : 0)
                                      ? beamCyan
                                      : beamBorder,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 10),
                      child: Text(
                        'Step ${widget.consent ? 2 : 1} of 4',
                        style: const TextStyle(color: beamMuted, fontSize: 10),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.consent
                                            ? 'Enable'
                                            : 'Personalize',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        widget.consent
                                            ? 'Permissions'
                                            : 'Your Wellness',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: beamCyan,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        widget.consent
                                            ? 'Choose what E Health can access.'
                                            : 'A few details for your wellness plan.',
                                        style: const TextStyle(
                                          color: beamMuted,
                                          fontSize: 11,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: widget.consent
                                      ? const BeamImage(
                                          asset: BeamAssets.authWatch,
                                          label: 'E Health Pulse',
                                          height: 140,
                                        )
                                      : const _ProfileArt(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            widget.consent ? permissionCards() : profile(),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                      child: Column(
                        children: [
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                error!,
                                style: const TextStyle(
                                  color: Color(0xFFFF91A8),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          BeamButton(
                            saving
                                ? 'Saving…'
                                : widget.editing
                                ? 'Save Changes'
                                : widget.consent
                                ? 'Continue'
                                : 'Save and Continue',
                            arrow: true,
                            onPressed:
                                saving ||
                                    requesting != null ||
                                    (widget.consent && !accepted)
                                ? null
                                : submit,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ProfileArt extends StatelessWidget {
  const _ProfileArt();
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: .1,
    child: Container(
      height: 60,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF68EBF9), Color(0xFF006485), Color(0xFF001C30)],
        ),
        border: Border.all(color: beamCyan),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: beamCyan.withValues(alpha: .2), blurRadius: 24),
        ],
      ),
      child: Row(
        children: [
          const BeamIcon('person', size: 32, color: Color(0xFF96F5FF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 6),
                    color: beamCyan.withValues(alpha: .6),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
