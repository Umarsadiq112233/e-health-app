class BeamReminder {
  const BeamReminder({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.date,
    required this.repeat,
    this.enabled = true,
    this.phone = true,
    this.watch = false,
  });
  final String id, category, title, description, repeat;
  final DateTime date;
  final bool enabled, phone, watch;
  BeamReminder withEnabled(bool value) => BeamReminder(
    id: id,
    category: category,
    title: title,
    description: description,
    date: date,
    repeat: repeat,
    enabled: value,
    phone: phone,
    watch: watch,
  );
}
