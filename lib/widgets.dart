import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'feed.dart';
import 'state.dart';
import 'theme.dart';

const double kMaxAppWidth = 520;

/// Phone-width column. Fills the screen on phones; on wide screens it is
/// centered with dark side margins. Uses exact sizes (no loose constraints).
class Frame extends StatelessWidget {
  final Widget child;
  const Frame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.navy,
      child: LayoutBuilder(builder: (context, c) {
        final w = math.min(c.maxWidth, kMaxAppWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: w, height: c.maxHeight, child: child),
        );
      }),
    );
  }
}

/// Traffic light logo (splash).
class TrafficLogo extends StatelessWidget {
  final double scale;
  const TrafficLogo({super.key, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c) => Container(
        width: 20 * scale,
        height: 20 * scale,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle));
    return Container(
      width: 58 * scale,
      height: 104 * scale,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12 * scale),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          dot(const Color(0xFFE74C3C)),
          dot(const Color(0xFFF4D35E)),
          dot(const Color(0xFF3DBB6C)),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color c;
  const _Dot(this.c);
  @override
  Widget build(BuildContext context) => Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

/// Dark top bar with logo, title and profile avatar.
class AppTopBar extends StatelessWidget {
  final bool showAvatar;
  final VoidCallback? onAvatarTap;
  const AppTopBar({super.key, this.showAvatar = true, this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.navy,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 14, 20, 14),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Dot(Color(0xFFE74C3C)),
                _Dot(Color(0xFFF4D35E)),
                _Dot(Color(0xFF3DBB6C)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Smart Traffic',
                    style: t(18, w: FontWeight.w600, c: Colors.white)),
                Text('Monitoring System',
                    style: t(11, c: const Color(0xFFB6C2D6))),
              ],
            ),
          ),
          if (showAvatar)
            GestureDetector(
              onTap: onAvatarTap,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: Color(0xFFB9C7E4), shape: BoxShape.circle),
                child: const Icon(Icons.person_outline,
                    size: 20, color: AppColors.navy),
              ),
            ),
        ],
      ),
    );
  }
}

/// Page header: big title, subtitle, date and "System Online" pill.
class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const PageHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t(30, w: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(subtitle, style: t(14, c: AppColors.muted)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: ClockText(
                format: (d) => '${fmtDate(d)} · ${fmtTime12(d)}',
                style: t(11, c: AppColors.muted),
              ),
            ),
            const StatusPill(),
          ],
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
            color: AppColors.mint, borderRadius: BorderRadius.circular(20)),
        child: Text('System Online',
            style: t(11, w: FontWeight.w600, c: AppColors.greenDark)),
      );
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color? borderColor;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.borderColor = AppColors.border,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: borderColor == null ? null : Border.all(color: borderColor!),
        ),
        child: child,
      );
}

/// Segmented tab control (Today / 7 days / 30 days etc.)
class SegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final bool blueText;
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.blueText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: AppColors.grayChip, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: List.generate(labels.length, (i) {
          final sel = i == index;
          final color = sel
              ? (blueText ? AppColors.blue : AppColors.ink)
              : AppColors.muted;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                decoration: BoxDecoration(
                  color: sel ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(labels[i],
                      style: t(12, w: FontWeight.w600, c: color)),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const Pill(this.text, {super.key, required this.bg, required this.fg});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: t(11, w: FontWeight.w600, c: fg)),
      );
}

class OutlineBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  const OutlineBtn(this.label, {super.key, this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => _Btn(label, icon, onTap, false);
}

class PrimaryBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  const PrimaryBtn(this.label, {super.key, this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => _Btn(label, icon, onTap, true);
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary;
  const _Btn(this.label, this.icon, this.onTap, this.primary);

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : AppColors.blue;
    return Material(
      color: primary ? AppColors.blue : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap ?? () {},
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: primary ? null : Border.all(color: AppColors.border),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: t(13, w: FontWeight.w600, c: fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet that respects the phone-width frame on large screens.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder,
    {bool scroll = false}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scroll,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: kMaxAppWidth),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: builder,
  );
}

/// Simple confirmation / info dialog.
Future<bool?> showInfo(BuildContext context, String title, String message,
    {String? confirm}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title, style: t(16, w: FontWeight.w700)),
      content: Text(message, style: t(13, c: AppColors.muted, h: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(confirm == null ? 'OK' : 'Cancel',
              style: t(13, w: FontWeight.w600, c: AppColors.blue)),
        ),
        if (confirm != null)
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirm, style: t(13, w: FontWeight.w600, c: AppColors.red)),
          ),
      ],
    ),
  );
}

/// Full page with a dark title bar and back button, in the phone-width frame.
class AppPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  const AppPage(
      {super.key,
      required this.title,
      required this.child,
      this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Frame(
        child: ColoredBox(
          color: AppColors.bg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: AppColors.navy,
                padding: EdgeInsets.fromLTRB(
                    8, MediaQuery.of(context).padding.top + 6, 8, 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(title,
                          style: t(17, w: FontWeight.w600, c: Colors.white)),
                    ),
                    ...actions,
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
