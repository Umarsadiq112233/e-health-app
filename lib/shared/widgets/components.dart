import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../health_catalog.dart';
export 'health_chart.dart';
export 'artwork.dart';
import 'artwork.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const PrimaryButton(this.label, {super.key, this.onPressed});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
  );
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const SecondaryButton(this.label, {super.key, required this.onPressed});
  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: onPressed, child: Text(label));
}

class AppTextField extends StatefulWidget {
  final String label;
  final String? initial;
  final bool readOnly;
  final bool password;
  final TextInputType? keyboard;
  final ValueChanged<String>? onChanged;
  const AppTextField(
    this.label, {
    super.key,
    this.initial,
    this.readOnly = false,
    this.password = false,
    this.keyboard,
    this.onChanged,
  });
  @override
  State<AppTextField> createState() => _FieldState();
}

class _FieldState extends State<AppTextField> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      initialValue: widget.initial,
      readOnly: widget.readOnly,
      onChanged: widget.onChanged,
      obscureText: widget.password && hidden,
      keyboardType: widget.keyboard,
      validator: (v) => v == null || v.trim().isEmpty
          ? 'Please enter ${widget.label.toLowerCase()}'
          : widget.keyboard == TextInputType.emailAddress &&
                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)
          ? 'Enter a valid email'
          : widget.keyboard == TextInputType.number &&
                (double.tryParse(v) ?? 0) <= 0
          ? 'Enter a number greater than zero'
          : widget.password && v.length < 6
          ? 'Use at least 6 characters'
          : null,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: widget.password
            ? IconButton(
                tooltip: hidden ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => hidden = !hidden),
                icon: Icon(
                  hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              )
            : null,
      ),
    ),
  );
}

class Panel extends StatelessWidget {
  final Widget child;
  final Color? color;
  final VoidCallback? onTap;
  final int entranceDelay;
  const Panel({
    super.key,
    required this.child,
    this.color,
    this.onTap,
    this.entranceDelay = 0,
  });
  @override
  Widget build(BuildContext context) => Entrance(
    delay: entranceDelay,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: color == null
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).brightness == Brightness.dark
            ? Color.alphaBlend(
                color!.withValues(alpha: .12),
                Theme.of(context).colorScheme.surface,
              )
            : color,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              boxShadow: AppShadows.soft,
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class BadgeIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const BadgeIcon(
    this.icon, {
    super.key,
    this.color = AppColors.primary,
    this.size = 44,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      shape: BoxShape.circle,
    ),
    child: Icon(
      icon,
      color: color == AppColors.primary
          ? Theme.of(context).colorScheme.primary
          : color,
      size: size * .5,
    ),
  );
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 14),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class HealthMetricCard extends StatelessWidget {
  final Metric metric;
  final VoidCallback onTap;
  final String status;
  const HealthMetricCard(
    this.metric, {
    super.key,
    required this.onTap,
    this.status = 'No data yet',
  });
  @override
  Widget build(BuildContext context) => Panel(
    entranceDelay: (HealthCatalog.metrics.indexOf(metric).clamp(0, 5) % 3) * 35,
    onTap: onTap,
    child: Row(
      children: [
        BadgeIcon(metric.icon, color: metric.color, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.name,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${metric.value} ${metric.unit}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class GoalProgressCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback? onTap;
  const GoalProgressCard(this.goal, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) => Panel(
    onTap: onTap,
    child: Row(
      children: [
        CircularProgressMetric(
          progress: goal.progress,
          color: goal.color,
          size: 46,
          child: Icon(
            goal.icon,
            color: AppColors.adaptive(context, goal.color),
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                goal.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Text(goal.detail, style: AppTypography.subtitle),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: goal.progress),
                duration: AppMotion.duration(context),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 3,
                  color: goal.color,
                  backgroundColor: goal.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class CircularProgressMetric extends StatelessWidget {
  final double progress, size;
  final Color color;
  final Widget child;
  const CircularProgressMetric({
    super.key,
    required this.progress,
    required this.child,
    this.size = 140,
    this.color = AppColors.green,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${(progress * 100).round()} percent of goal',
    child: SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.clamp(0, 1)),
              duration: AppMotion.duration(context),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 5,
                strokeCap: StrokeCap.round,
                backgroundColor: color.withValues(alpha: .12),
                color: AppColors.adaptive(context, color),
              ),
            ),
          ),
          child,
        ],
      ),
    ),
  );
}

class InsightCard extends StatelessWidget {
  final (String, String, IconData, Color) item;
  const InsightCard(this.item, {super.key});
  @override
  Widget build(BuildContext context) => Panel(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BadgeIcon(item.$3, color: item.$4),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.$1,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 7),
              Text(item.$2, style: AppTypography.subtitle),
            ],
          ),
        ),
      ],
    ),
  );
}

class SettingTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final VoidCallback onTap;
  const SettingTile(
    this.title,
    this.icon, {
    super.key,
    this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    leading: icon == Icons.blur_circular
        ? const AppArtworkImage(
            asset: AppArtwork.ring,
            label: 'E Sync silver titanium ring',
            height: 32,
            width: 32,
            padding: EdgeInsets.zero,
          )
        : Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
    title: Text(title, style: const TextStyle(fontSize: 14)),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle!,
            style: const TextStyle(color: AppColors.green, fontSize: 12),
          ),
    trailing: const Icon(Icons.chevron_right, size: 18),
    onTap: onTap,
  );
}

class DeviceStatusCard extends StatelessWidget {
  final VoidCallback onTap;
  final String name, status;
  const DeviceStatusCard({
    super.key,
    required this.onTap,
    this.name = 'No wearable connected',
    this.status = 'Connect your health device to start syncing supported data.',
  });
  @override
  Widget build(BuildContext context) => Panel(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const RingVisual(size: 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(status, style: AppTypography.subtitle),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PrimaryButton('Connect Device', onPressed: onTap),
      ],
    ),
  );
}

class PeriodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final List<String> options;
  const PeriodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.options = const ['Day', 'Week', 'Month'],
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: selected == option
                      ? AppColors.primary
                      : Colors.transparent,
                  foregroundColor: selected == option
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => onChanged(option),
                child: Semantics(
                  selected: selected == option,
                  child: Text(option),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class RingVisual extends StatelessWidget {
  final double size;
  const RingVisual({super.key, this.size = 190});
  @override
  Widget build(BuildContext context) => AppArtworkImage(
    asset: AppArtwork.ring,
    label: 'E Sync Smart Ring in silver titanium',
    height: size,
    width: size,
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      BrandMark(),
      SizedBox(height: 12),
      Text('Your Health. Smarter. Every Day.', style: AppTypography.subtitle),
    ],
  );
}

class EmptyState extends StatelessWidget {
  final String message;
  const EmptyState(this.message, {super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(message, style: AppTypography.subtitle),
    ),
  );
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading demo readings',
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              height: 70,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
            ),
          const Text('Loading demo readings…', style: AppTypography.subtitle),
        ],
      ),
    ),
  );
}

class ErrorState extends StatelessWidget {
  final VoidCallback retry;
  const ErrorState({super.key, required this.retry});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Icon(Icons.error_outline, size: 48, color: AppColors.red),
      const Text('Connection interrupted. Please try again.'),
      SecondaryButton('Try again', onPressed: retry),
    ],
  );
}

/// A single, finite entrance; Flutter disposes its animation with the widget.
class Entrance extends StatelessWidget {
  final Widget child;
  final int delay;
  const Entrance({super.key, required this.child, this.delay = 0});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.standard + Duration(milliseconds: delay),
    curve: Interval(delay / (240 + delay), 1, curve: Curves.easeOutCubic),
    builder: (context, value, _) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, (1 - value) * 8),
        child: child,
      ),
    ),
  );
}

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 132});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FAF5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'E Health logo',
      ),
    ),
  );
}
