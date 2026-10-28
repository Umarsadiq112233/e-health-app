import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/state/app_session_cubit.dart';
import '../../../../shared/widgets/beam_ui.dart';
import '../../domain/reminder.dart';

enum NotificationView { centre, reminders, editor, preferences }

class BeamNotificationScreen extends StatefulWidget {
  const BeamNotificationScreen({
    super.key,
    this.view = NotificationView.centre,
    this.reminder,
  });
  final NotificationView view;
  final BeamReminder? reminder;
  @override
  State<BeamNotificationScreen> createState() => _BeamNotificationScreenState();
}

class _BeamNotificationScreenState extends State<BeamNotificationScreen> {
  final session = AppSessionCubit.instance;
  final form = GlobalKey<FormState>();
  late final titleInput = TextEditingController(text: widget.reminder?.title);
  late final description = TextEditingController(
    text: widget.reminder?.description,
  );
  late String category = widget.reminder?.category ?? 'Medication';
  late String repeat = widget.reminder?.repeat ?? 'Once';
  late DateTime date =
      widget.reminder?.date ?? DateTime.now().add(const Duration(hours: 1));
  late bool phone = widget.reminder?.phone ?? true;
  bool watch = false;
  String filter = 'All';
  PermissionStatus? permission;
  static const categories = ['Medication', 'Appointment', 'Wellness', 'Other'];
  @override
  void initState() {
    super.initState();
    if (widget.view == NotificationView.preferences) checkPermission();
  }

  Future<void> checkPermission() async {
    final status = await Permission.notification.status;
    if (mounted) setState(() => permission = status);
  }

  @override
  void dispose() {
    titleInput.dispose();
    description.dispose();
    super.dispose();
  }

  void open(NotificationView view, {BeamReminder? reminder}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              BeamNotificationScreen(view: view, reminder: reminder),
        ),
      );
  String get title => switch (widget.view) {
    NotificationView.centre => 'Notifications',
    NotificationView.reminders => 'My Reminders',
    NotificationView.editor =>
      widget.reminder == null ? 'Create Reminder' : 'Edit Reminder',
    NotificationView.preferences => 'Notification Preferences',
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
        actions: [
          if (widget.view == NotificationView.reminders)
            IconButton(
              tooltip: 'Add reminder',
              onPressed: () => open(NotificationView.editor),
              icon: const Icon(Icons.add_circle, color: beamCyan, size: 30),
            ),
          if (widget.view == NotificationView.centre)
            PopupMenuButton<String>(
              tooltip: 'Notification options',
              onSelected: (value) => open(
                value == 'reminders'
                    ? NotificationView.reminders
                    : NotificationView.preferences,
              ),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'reminders', child: Text('My Reminders')),
                PopupMenuItem(value: 'preferences', child: Text('Preferences')),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<AppSessionCubit, AppSessionState>(
          bloc: session,
          builder: (context, _) => Center(
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
    ),
  );
  List<Widget> content() => switch (widget.view) {
    NotificationView.centre => [
      chips(['All', 'Device', 'Reminders', 'Account']),
      const SizedBox(height: 8),
      heading('Today'),
      panel(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              Icon(Icons.notifications_none, size: 56, color: beamCyan),
              SizedBox(height: 16),
              Text(
                'No notifications yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Your updates will appear here.',
                style: TextStyle(color: beamMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      button('My Reminders', () => open(NotificationView.reminders)),
      tile(
        Icons.tune,
        beamCyan,
        'Notification Preferences',
        () => open(NotificationView.preferences),
      ),
    ],
    NotificationView.reminders => [
      chips(['All', 'Medication', 'Appointment', 'Wellness']),
      for (final reminder in session.reminders.where(
        (r) => filter == 'All' || r.category == filter,
      ))
        panel(
          Row(
            children: [
              orb(icon(reminder.category), color(reminder.category), size: 52),
              const SizedBox(width: 13),
              Expanded(
                child: InkWell(
                  onTap: () =>
                      open(NotificationView.editor, reminder: reminder),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${MaterialLocalizations.of(context).formatShortDate(reminder.date)} · ${TimeOfDay.fromDateTime(reminder.date).format(context)}',
                        style: const TextStyle(fontSize: 12, color: beamMuted),
                      ),
                      Text(
                        reminder.repeat,
                        style: const TextStyle(fontSize: 11, color: beamMuted),
                      ),
                    ],
                  ),
                ),
              ),
              Switch(
                value: reminder.enabled,
                onChanged: (value) =>
                    session.saveReminder(reminder.withEnabled(value)),
                activeTrackColor: beamCyan,
                activeThumbColor: Colors.white,
              ),
              IconButton(
                tooltip: 'Edit ${reminder.title}',
                onPressed: () =>
                    open(NotificationView.editor, reminder: reminder),
                icon: const Icon(
                  Icons.chevron_right,
                  color: beamMuted,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      if (session.reminders
          .where((r) => filter == 'All' || r.category == filter)
          .isEmpty)
        panel(
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No reminders yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: beamMuted),
            ),
          ),
        ),
      button(
        'Add Reminder',
        () => open(NotificationView.editor),
        icon: Icons.add,
      ),
      const Text(
        'Saved in this session. Delivery is not enabled yet.',
        textAlign: TextAlign.center,
        style: TextStyle(color: beamMuted, fontSize: 11),
      ),
    ],
    NotificationView.editor => [
      Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading('Category'),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final value in categories)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: InkWell(
                        onTap: () => setState(() => category = value),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 17,
                            horizontal: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: category == value ? beamCyan : beamBorder,
                              width: category == value ? 1.5 : .6,
                            ),
                            color: const Color(0xFF002333),
                          ),
                          child: Column(
                            children: [
                              Icon(icon(value), color: color(value), size: 27),
                              const SizedBox(height: 9),
                              Text(value, style: const TextStyle(fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            heading('Title'),
            const SizedBox(height: 10),
            field(titleInput, 'Reminder title', required: true),
            const SizedBox(height: 18),
            heading('Description (optional)'),
            const SizedBox(height: 10),
            field(description, 'Add a note', lines: 2),
            const SizedBox(height: 18),
            heading('Date & Time'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: tile(
                    Icons.calendar_month,
                    Colors.white,
                    MaterialLocalizations.of(context).formatShortDate(date),
                    pickDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: tile(
                    Icons.schedule,
                    Colors.white,
                    TimeOfDay.fromDateTime(date).format(context),
                    pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            heading('Repeat'),
            const SizedBox(height: 10),
            panel(
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: repeat,
                  dropdownColor: beamNavy,
                  items: [
                    for (final value in ['Once', 'Every day', 'Every week'])
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => repeat = value!),
                ),
              ),
            ),
            const SizedBox(height: 18),
            heading('Notify On'),
            const SizedBox(height: 10),
            panel(
              Column(
                children: [
                  toggle(
                    Icons.phone_iphone,
                    beamCyan,
                    'Phone',
                    phone,
                    (value) => setState(() => phone = value),
                  ),
                  toggle(
                    Icons.watch_outlined,
                    const Color(0xFF00E1B2),
                    'Watch',
                    watch,
                    null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Watch delivery awaits device support.',
              style: TextStyle(color: beamMuted, fontSize: 11),
            ),
            const SizedBox(height: 20),
            button('Save Reminder', save),
            if (widget.reminder != null)
              TextButton(
                onPressed: remove,
                child: const Text(
                  'Delete Reminder',
                  style: TextStyle(color: Color(0xFFFF4C73)),
                ),
              ),
          ],
        ),
      ),
    ],
    NotificationView.preferences => [
      tile(
        Icons.notifications,
        const Color(0xFF16B6FF),
        'Push Notifications',
        managePermission,
        subtitle: permission == null
            ? 'Checking…'
            : permission!.isGranted
            ? 'Allowed'
            : 'Not allowed',
      ),
      heading('Device Alerts'),
      panel(
        Column(
          children: [
            preference(
              Icons.watch_outlined,
              const Color(0xFF25BDFF),
              'Connection & Sync',
            ),
            preference(
              Icons.battery_full,
              const Color(0xFF00EF81),
              'Low Battery',
            ),
          ],
        ),
      ),
      heading('Wellness Reminders'),
      panel(
        Column(
          children: [
            preference(
              Icons.directions_run,
              const Color(0xFF00EBAF),
              'Activity Reminders',
            ),
            preference(
              Icons.emoji_events,
              const Color(0xFFFFCB46),
              'Goal Reminders',
            ),
          ],
        ),
      ),
      heading('Medication & Appointments'),
      panel(
        Column(
          children: [
            preference(
              Icons.medication,
              const Color(0xFFFF4C73),
              'Medication Reminders',
            ),
            preference(
              Icons.calendar_month,
              const Color(0xFF20B8FF),
              'Appointment Reminders',
            ),
          ],
        ),
      ),
      heading('AI Coach'),
      panel(
        Column(
          children: [
            preference(
              Icons.smart_toy,
              const Color(0xFF00DDEB),
              'Wellness Tips',
            ),
            preference(
              Icons.lightbulb,
              const Color(0xFFFFCB46),
              'Motivational Reminders',
            ),
          ],
        ),
      ),
      const Text(
        'Preferences saved for this session.',
        textAlign: TextAlign.center,
        style: TextStyle(color: beamMuted, fontSize: 11),
      ),
    ],
  };
  Future<void> pickDate() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      initialDate: date.isBefore(now) ? now : date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (value != null && mounted) {
      setState(
        () => date = DateTime(
          value.year,
          value.month,
          value.day,
          date.hour,
          date.minute,
        ),
      );
    }
  }

  Future<void> pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(date),
    );
    if (value != null && mounted) {
      setState(
        () => date = DateTime(
          date.year,
          date.month,
          date.day,
          value.hour,
          value.minute,
        ),
      );
    }
  }

  void save() {
    if (!form.currentState!.validate()) return;
    if (repeat == 'Once' && !date.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future date and time.')),
      );
      return;
    }
    session.saveReminder(
      BeamReminder(
        id:
            widget.reminder?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        category: category,
        title: titleInput.text.trim(),
        description: description.text.trim(),
        date: date,
        repeat: repeat,
        phone: phone,
        enabled: widget.reminder?.enabled ?? true,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reminder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      session.deleteReminder(widget.reminder!.id);
      Navigator.pop(context);
    }
  }

  Future<void> managePermission() async {
    if (permission?.isPermanentlyDenied == true) {
      await openAppSettings();
    } else {
      await Permission.notification.request();
    }
    await checkPermission();
  }

  Widget preference(IconData icon, Color color, String label) => toggle(
    icon,
    color,
    label,
    session.preferences['notification:$label'] ?? true,
    (value) => session.preference('notification:$label', value),
  );
  Widget toggle(
    IconData icon,
    Color color,
    String label,
    bool value,
    ValueChanged<bool>? onChanged,
  ) => Row(
    children: [
      orb(icon, color),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
      Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: beamCyan,
        activeThumbColor: Colors.white,
      ),
    ],
  );
  Widget field(
    TextEditingController controller,
    String hint, {
    bool required = false,
    int lines = 1,
  }) => TextFormField(
    controller: controller,
    maxLines: lines,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    validator: required
        ? (value) =>
              value == null || value.trim().isEmpty ? 'Enter a title' : null
        : null,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: beamMuted),
      filled: true,
      fillColor: const Color(0xFF002232),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: beamBorder),
      ),
    ),
  );
  Widget chips(List<String> values) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final value in values)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: filter == value ? beamNavy : beamMuted,
                ),
              ),
              showCheckmark: false,
              selected: filter == value,
              selectedColor: beamCyan,
              backgroundColor: const Color(0xFF002232),
              shape: const StadiumBorder(side: BorderSide(color: beamBorder)),
              onSelected: (_) => setState(() => filter = value),
            ),
          ),
      ],
    ),
  );
  Widget heading(String text) => Text(
    text,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );
  Widget tile(
    IconData icon,
    Color color,
    String title,
    VoidCallback onTap, {
    String? subtitle,
  }) => panel(
    InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(width: 12),
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
        ],
      ),
    ),
  );
  Widget button(String text, VoidCallback onTap, {IconData? icon}) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      gradient: const LinearGradient(
        colors: [Color(0xFF00C8ED), Color(0xFF00F0E6)],
      ),
    ),
    child: TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: beamNavy,
        padding: const EdgeInsets.symmetric(vertical: 17),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 24),
            const SizedBox(width: 12),
          ],
          Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
  Widget panel(Widget child) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFF07516A), width: .8),
      gradient: const LinearGradient(
        colors: [Color(0xFF002537), Color(0xFF001822)],
      ),
    ),
    child: child,
  );
  Widget orb(IconData icon, Color color, {double size = 42}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: .17),
    ),
    child: Icon(icon, color: color, size: size * .58),
  );
  IconData icon(String category) => switch (category) {
    'Medication' => Icons.medication,
    'Appointment' => Icons.calendar_month,
    'Wellness' => Icons.directions_run,
    _ => Icons.more_horiz,
  };
  Color color(String category) => switch (category) {
    'Medication' => const Color(0xFFFF4C73),
    'Appointment' => const Color(0xFF15B9F4),
    'Wellness' => const Color(0xFF00EBAF),
    _ => beamMuted,
  };
}
