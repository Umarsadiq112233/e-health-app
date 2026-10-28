import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/state/app_session_cubit.dart';
import '../../../../shared/health_catalog.dart';
import '../../../../shared/widgets/beam_ui.dart';
import '../../../health_metrics/domain/health_reading.dart';
import '../../../health_metrics/presentation/cubit/health_cubit.dart';

enum CoachView { home, chat, insights, suggestions, history }

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({
    super.key,
    this.view = CoachView.home,
    this.question,
    this.conversationId,
  });
  final CoachView view;
  final String? question, conversationId;

  /// Opens the welcome screen for a new user, or resumes the latest chat.
  factory AiCoachScreen.resume({Key? key}) {
    final conversations = AppSessionCubit.instance.coachConversations;
    final id = conversations.isEmpty ? null : conversations.keys.last;
    return AiCoachScreen(
      key: key,
      view: id == null ? CoachView.home : CoachView.chat,
      conversationId: id,
    );
  }

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final session = AppSessionCubit.instance;
  final dismissed = <String>{};
  String period = 'Today';
  String? conversationId;
  @override
  void initState() {
    super.initState();
    conversationId = widget.conversationId;
    input.text = widget.question ?? '';
  }

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void open(CoachView view, {String? question, String? id}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AiCoachScreen(view: view, question: question, conversationId: id),
        ),
      );
  void send() {
    final text = input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      conversationId ??= DateTime.now().microsecondsSinceEpoch.toString();
      session.saveCoachMessage(conversationId!, text);
      input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String get title => switch (widget.view) {
    CoachView.home || CoachView.chat => 'AI Coach',
    CoachView.insights => 'My Insights',
    CoachView.suggestions => 'Goal Suggestions',
    CoachView.history => 'Chat History',
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
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        leading: widget.view == CoachView.home
            ? IconButton(
                tooltip: 'Coach menu',
                onPressed: menu,
                icon: const Icon(Icons.menu),
              )
            : null,
        actions: [
          if (widget.view == CoachView.home || widget.view == CoachView.chat)
            IconButton(
              tooltip: 'Chat history',
              onPressed: () => open(CoachView.history),
              icon: const Icon(Icons.history, color: beamCyan),
            ),
        ],
      ),
      body: SafeArea(
        child: widget.view == CoachView.chat
            ? chat()
            : BlocBuilder<AppSessionCubit, AppSessionState>(
                bloc: session,
                builder: (context, _) => BlocBuilder<HealthCubit, HealthState>(
                  bloc: HealthCubit.instance,
                  builder: (context, health) => Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: switch (widget.view) {
                          CoachView.home => home(),
                          CoachView.insights => insights(health),
                          CoachView.suggestions => suggestions(),
                          CoachView.history => history(),
                          CoachView.chat => [],
                        },
                      ),
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
  void menu() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: beamNavy,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in [
            (CoachView.insights, 'My Insights', 'chart'),
            (CoachView.suggestions, 'Goal Suggestions', 'target'),
            (CoachView.history, 'Chat History', 'clock'),
          ])
            ListTile(
              leading: BeamIcon(item.$3),
              title: Text(item.$2, style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                open(item.$1);
              },
            ),
        ],
      ),
    ),
  );
  List<Widget> home() => [
    SizedBox(
      height: 245,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: .35,
              child: Image.asset(
                'assets/beam/images/beam-wellness-mountains.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            width: 218,
            height: 218,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: beamCyan, width: 2),
              boxShadow: [
                BoxShadow(
                  color: beamCyan.withValues(alpha: .3),
                  blurRadius: 25,
                ),
              ],
            ),
          ),
          const BeamImage(
            asset: BeamAssets.coach,
            label: 'E Health AI wellness coach',
            height: 228,
            width: 228,
          ),
        ],
      ),
    ),
    const SizedBox(height: 18),
    Text(
      session.name.trim().isEmpty
          ? 'Hello there!'
          : 'Hello, ${session.name.trim().split(' ').first}!',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 7),
    const Text(
      'Your daily wellness companion.',
      textAlign: TextAlign.center,
      style: TextStyle(color: beamMuted, fontSize: 14),
    ),
    const SizedBox(height: 18),
    panel(
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: orb('sun', const Color(0xFFFFC54B)),
        title: const Text(
          'Small steps. Better habits.',
          style: TextStyle(fontSize: 14),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => open(CoachView.suggestions),
      ),
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        for (final item in [
          ('activity', 'Activity', const Color(0xFF00DDB0)),
          ('moon', 'Sleep', const Color(0xFFAC68FF)),
          ('feather', 'Wellness', const Color(0xFFFFC54B)),
        ])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => open(CoachView.chat, question: '${item.$2} tips'),
                child: panel(
                  Column(
                    children: [
                      orb(item.$1, item.$3),
                      const SizedBox(height: 10),
                      Text(item.$2, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  tint: item.$3,
                ),
              ),
            ),
          ),
      ],
    ),
    const SizedBox(height: 20),
    const Text(
      'Quick Questions',
      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 10),
    for (final item in [
      ('moon', 'How can I sleep better?'),
      ('sun', 'Tips for more energy'),
      ('activity', 'Simple home workouts'),
      ('heart', 'Healthy eating tips'),
    ])
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: panel(
          InkWell(
            onTap: () => open(CoachView.chat, question: item.$2),
            child: Row(
              children: [
                BeamIcon(item.$1, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.$2, style: const TextStyle(fontSize: 13)),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
        ),
      ),
    const SizedBox(height: 12),
    BeamButton('Start Conversation', onPressed: () => open(CoachView.chat)),
    const SizedBox(height: 14),
    disclaimer(),
  ];
  Widget chat() {
    final messages = session.coachConversations[conversationId] ?? <String>[];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        'assets/icons/connect/chatbot.png',
                        width: 42,
                        height: 42,
                        fit: BoxFit.contain,
                        semanticLabel: 'AI Coach chatbot',
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: panel(
                          const Text(
                            'What would you like to explore?',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  for (final text in messages) ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 270),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF087DF7), Color(0xFF00BDEB)],
                          ),
                        ),
                        child: Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (messages.isNotEmpty)
                    panel(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Coach is unavailable',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'AI service is not connected yet.',
                            style: TextStyle(color: beamMuted, fontSize: 13),
                          ),
                          TextButton(
                            onPressed: () => ScaffoldMessenger.of(context)
                                .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'AI service is not configured.',
                                    ),
                                  ),
                                ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final label in [
                    'Sleep tips',
                    'Easy workouts',
                    'Healthy meals',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(
                          label,
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: beamNavy,
                        side: const BorderSide(color: beamBorder),
                        onPressed: () {
                          input.text = label;
                        },
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => send(),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        hintStyle: const TextStyle(color: beamMuted),
                        filled: true,
                        fillColor: const Color(0xFF002033),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(26),
                          borderSide: const BorderSide(color: beamBorder),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: send,
                    style: IconButton.styleFrom(
                      backgroundColor: beamCyan,
                      foregroundColor: beamNavy,
                    ),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
            disclaimer(),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  List<Widget> insights(HealthState health) {
    final days = period == 'Today'
        ? 1
        : period == 'Week'
        ? 7
        : 30;
    return [
      SegmentedButton<String>(
        segments: [
          for (final value in ['Today', 'Week', 'Month'])
            ButtonSegment(value: value, label: Text(value)),
        ],
        selected: {period},
        onSelectionChanged: (value) => setState(() => period = value.first),
      ),
      const SizedBox(height: 20),
      LayoutBuilder(
        builder: (context, box) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in [
              (
                HealthMetricType.steps,
                'activity',
                'Steps',
                const Color(0xFF00DDB0),
              ),
              (
                HealthMetricType.sleep,
                'moon',
                'Sleep',
                const Color(0xFFAC68FF),
              ),
              (
                HealthMetricType.heartRate,
                'heart',
                'Heart Rate',
                const Color(0xFFFF617C),
              ),
              (HealthMetricType.hrv, 'chart', 'HRV', const Color(0xFFFFC54B)),
            ])
              SizedBox(
                width: (box.maxWidth - 12) / 2,
                child: Builder(
                  builder: (_) {
                    final readings = health.history(item.$1, days);
                    final latest = readings.isEmpty ? null : readings.last;
                    return panel(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          orb(item.$2, item.$4),
                          const SizedBox(height: 15),
                          Text(
                            latest == null
                                ? '—'
                                : '${latest.value.toStringAsFixed(item.$1 == HealthMetricType.sleep ? 1 : 0)} ${latest.unit}',
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.$3,
                            style: const TextStyle(
                              fontSize: 12,
                              color: beamMuted,
                            ),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            height: 32,
                            child: readings.isEmpty
                                ? const Align(
                                    alignment: Alignment.bottomLeft,
                                    child: Text(
                                      'No readings',
                                      style: TextStyle(
                                        color: beamMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  )
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      for (final reading in readings.skip(
                                        readings.length > 12
                                            ? readings.length - 12
                                            : 0,
                                      ))
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 2,
                                            ),
                                            child: Container(
                                              height:
                                                  5 +
                                                  27 *
                                                      (reading.value /
                                                              readings
                                                                  .map(
                                                                    (r) =>
                                                                        r.value,
                                                                  )
                                                                  .fold<double>(
                                                                    1,
                                                                    (a, b) =>
                                                                        a > b
                                                                        ? a
                                                                        : b,
                                                                  ))
                                                          .clamp(0, 1),
                                              decoration: BoxDecoration(
                                                color: item.$4,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                      tint: item.$4,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      const Text(
        'My Progress',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      for (final goal in session.goals.take(3))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: panel(
            Row(
              children: [
                Icon(goal.icon, color: beamCyan),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.name, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: goal.progress.clamp(0, 1),
                        color: beamCyan,
                        backgroundColor: beamBorder,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(goal.progress * 100).round()}%',
                  style: const TextStyle(color: beamMuted),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 10),
      panel(
        const Row(
          children: [
            BeamIcon('chart'),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Recorded health data',
                style: TextStyle(color: beamMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => open(CoachView.suggestions),
        child: const Text('Goal Suggestions'),
      ),
    ];
  }

  List<Widget> suggestions() => [
    const SizedBox(height: 16),
    const Center(child: BeamIcon('target', size: 104)),
    const SizedBox(height: 20),
    const Text(
      'Build Better Habits',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 8),
    const Text(
      'Choose a target that suits you.',
      textAlign: TextAlign.center,
      style: TextStyle(color: beamMuted, fontSize: 13),
    ),
    const SizedBox(height: 24),
    for (final item in [
      (
        'Daily Steps',
        'activity',
        'Set a daily step target.',
        const Color(0xFF00DDB0),
      ),
      (
        'Sleep Duration',
        'moon',
        'Set your sleep target.',
        const Color(0xFFAC68FF),
      ),
      ('Activity', 'flame', 'Set active minutes.', const Color(0xFFFFC54B)),
    ])
      if (!dismissed.contains(item.$1))
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: panel(
            Column(
              children: [
                Row(
                  children: [
                    orb(item.$2, item.$4),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$1,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.$3,
                            style: const TextStyle(
                              color: beamMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: BeamButton(
                        'Set Goal',
                        onPressed: () => editGoal(item.$1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BeamButton(
                        'Not Now',
                        secondary: true,
                        onPressed: () => setState(() => dismissed.add(item.$1)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            tint: item.$4,
          ),
        ),
    const SizedBox(height: 12),
    disclaimer(),
  ];
  Future<void> editGoal(String name) async {
    final index = session.goals.indexWhere((g) => g.name == name);
    if (index < 0) return;
    final goal = session.goals[index];
    var text = '';
    final form = GlobalKey<FormState>();
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: Form(
          key: form,
          child: TextFormField(
            onChanged: (v) => text = v,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: name == 'Sleep Duration'
                  ? 'Hours'
                  : name == 'Activity'
                  ? 'Minutes'
                  : 'Steps',
            ),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              return n == null ||
                      !n.isFinite ||
                      n <= 0 ||
                      (name == 'Sleep Duration' && n > 24)
                  ? 'Enter a valid target'
                  : null;
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
              if (form.currentState!.validate()) {
                Navigator.pop(context, double.parse(text));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      final current = double.tryParse(goal.detail.split('/').first.trim()) ?? 0;
      final currentLabel = current > 0
          ? current.toStringAsFixed(name == 'Sleep Duration' ? 1 : 0)
          : goal.detail.split('/').first.trim();
      session.updateGoal(
        index,
        Goal(
          goal.name,
          '$currentLabel / ${result.toStringAsFixed(name == 'Sleep Duration' ? 1 : 0)}${name == 'Sleep Duration'
              ? 'h'
              : name == 'Activity'
              ? ' min'
              : ''}',
          (current / result).clamp(0, 1),
          goal.icon,
          goal.color,
        ),
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Goal updated.')));
    }
  }

  List<Widget> history() => session.coachConversations.isEmpty
      ? [
          const SizedBox(height: 150),
          const Icon(Icons.forum_outlined, size: 84, color: beamMuted),
          const SizedBox(height: 22),
          const Text(
            'No conversations yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your chats will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: beamMuted),
          ),
          const SizedBox(height: 25),
          BeamButton(
            'Start Conversation',
            onPressed: () => open(CoachView.chat),
          ),
        ]
      : [
          for (final entry
              in session.coachConversations.entries.toList().reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: panel(
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: orb('brain', beamCyan),
                  title: Text(
                    entry.value.first,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${entry.value.length} messages · This session',
                    style: const TextStyle(fontSize: 12, color: beamMuted),
                  ),
                  onTap: () => open(CoachView.chat, id: entry.key),
                  trailing: IconButton(
                    tooltip: 'Delete conversation',
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => delete(entry.key),
                  ),
                ),
              ),
            ),
        ];
  Future<void> delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation?'),
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
      session.deleteCoachConversation(id);
    }
  }

  Widget disclaimer() => const Text(
    'Wellness guidance. Not medical advice.',
    textAlign: TextAlign.center,
    style: TextStyle(color: beamMuted, fontSize: 10),
  );
  Widget panel(Widget child, {Color tint = beamCyan}) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: tint.withValues(alpha: .24)),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [tint.withValues(alpha: .10), const Color(0xFF001A28)],
      ),
    ),
    child: child,
  );
  Widget orb(String icon, Color color) => Container(
    width: 47,
    height: 47,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: .15),
    ),
    child: Center(child: BeamIcon(icon, color: color, size: 28)),
  );
}
