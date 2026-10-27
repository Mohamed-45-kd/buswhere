import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/tokens.dart';

/// Lucide icon from assets/icons (the DS icon set).
class BWIcon extends StatelessWidget {
  const BWIcon(this.name, {super.key, this.size = 24, this.color});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? BW.night;
    return SvgPicture.asset('assets/icons/$name.svg', width: size, height: size, colorFilter: ColorFilter.mode(c, BlendMode.srcIn));
  }
}

/// Touch-first press feedback: darken fill + scale to 0.98. No hover-only affordances.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.builder, this.onTap, this.scale = true, this.semanticLabel});
  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
  final bool scale;
  final String? semanticLabel;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _p = false;
  void _set(bool v) {
    if (widget.onTap != null && _p != v) setState(() => _p = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _set(true),
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  widget.onTap!();
                }
              : null,
          child: AnimatedScale(scale: _p && widget.scale ? 0.98 : 1, duration: BW.fast, curve: BW.easeOut, child: widget.builder(_p)),
        ),
      ),
    );
  }
}

enum BtnVariant { primary, secondary, dark, onDark, outline, ghost, danger }

class BWButton extends StatelessWidget {
  const BWButton(this.label, {super.key, this.subLabel, this.variant = BtnVariant.primary, this.icon, this.iconRight, this.onTap, this.small = false, this.fullWidth = true, this.busy = false});
  final String label;
  final String? subLabel;
  final BtnVariant variant;
  final String? icon, iconRight;
  final VoidCallback? onTap;
  final bool small, fullWidth, busy;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final (bg, pr, fg, sub, border) = switch (variant) {
      BtnVariant.primary => (BW.busYellow, BW.yellow600, BW.night, BW.night700, null),
      BtnVariant.secondary => (BW.teal, BW.teal700, BW.white, BW.teal100, null),
      BtnVariant.dark => (BW.night, BW.night700, BW.white, BW.onDarkMuted, null),
      BtnVariant.onDark => (BW.night700, BW.night600, BW.white, BW.onDarkMuted, null),
      BtnVariant.outline => (BW.white, BW.sand200, BW.night, BW.night600, BW.night),
      BtnVariant.ghost => (Colors.transparent, BW.teal100, BW.teal, BW.night600, null),
      BtnVariant.danger => (BW.red600, const Color(0xFF8F1E18), BW.white, BW.red100, null),
    };
    final h = subLabel != null ? 64.0 : (small ? 44.0 : 56.0);
    return Pressable(
      onTap: disabled || busy ? null : onTap,
      semanticLabel: subLabel == null ? label : '$label, $subLabel',
      builder: (p) => AnimatedContainer(
        duration: BW.fast,
        constraints: BoxConstraints(minHeight: h),
        width: fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: small ? 16 : 24, vertical: 6),
        decoration: BoxDecoration(
          color: disabled ? BW.night200 : (p ? pr : bg),
          borderRadius: BorderRadius.circular(BW.rMd),
          border: border != null ? Border.all(color: disabled ? BW.night300 : border, width: 2) : null,
        ),
        child: DefaultTextStyle(
          style: TextStyle(fontFamily: 'Sora', color: disabled ? BW.night500 : fg, fontWeight: FontWeight.w700, fontSize: small ? 15 : 17, height: 22 / 17),
          textAlign: TextAlign.center,
          child: Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
              else if (icon != null)
                BWIcon(icon!, size: small ? 20 : 22, color: disabled ? BW.night500 : fg),
              if (icon != null || busy) const SizedBox(width: 10),
              Flexible(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(label),
                  if (subLabel != null) Text(subLabel!, style: TextStyle(fontWeight: FontWeight.w400, fontSize: 13, height: 18 / 13, color: disabled ? BW.night500 : sub)),
                ]),
              ),
              if (iconRight != null) ...[const SizedBox(width: 10), BWIcon(iconRight!, size: small ? 20 : 22, color: disabled ? BW.night500 : fg)],
            ],
          ),
        ),
      ),
    );
  }
}

enum IconBtnVariant { ghost, filled, primary, dark, onDark }

class BWIconButton extends StatelessWidget {
  const BWIconButton(this.icon, {super.key, required this.label, this.variant = IconBtnVariant.ghost, this.size = 48, this.onTap, this.float = false});
  final String icon, label;
  final IconBtnVariant variant;
  final double size;
  final VoidCallback? onTap;
  final bool float;
  @override
  Widget build(BuildContext context) {
    final (bg, pr, fg) = switch (variant) {
      IconBtnVariant.ghost => (Colors.transparent, BW.sand200, BW.night),
      IconBtnVariant.filled => (BW.white, BW.sand200, BW.night),
      IconBtnVariant.primary => (BW.busYellow, BW.yellow600, BW.night),
      IconBtnVariant.dark => (BW.night, BW.night700, BW.white),
      IconBtnVariant.onDark => (BW.night700, BW.night600, BW.white),
    };
    return Tooltip(
      message: label,
      child: Pressable(
        onTap: onTap,
        scale: false,
        semanticLabel: label,
        builder: (p) => AnimatedContainer(
          duration: BW.fast,
          width: size,
          height: size,
          decoration: BoxDecoration(color: p ? pr : bg, borderRadius: BorderRadius.circular(size >= 56 ? BW.rMd : BW.rSm), boxShadow: float ? BW.shadowFloat : null),
          alignment: Alignment.center,
          child: BWIcon(icon, size: size >= 56 ? 28 : 24, color: fg),
        ),
      ),
    );
  }
}

enum CardVariant { normal, outlined, sunken, dark, info, warning }

class BWCard extends StatelessWidget {
  const BWCard({super.key, required this.child, this.variant = CardVariant.normal, this.padding = const EdgeInsets.all(16), this.onTap, this.radius = BW.rLg});
  final Widget child;
  final CardVariant variant;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final bg = switch (variant) {
      CardVariant.normal || CardVariant.outlined => BW.white,
      CardVariant.sunken => BW.sand200,
      CardVariant.dark => BW.night,
      CardVariant.info => BW.teal100,
      CardVariant.warning => BW.yellow100,
    };
    Widget box(bool p) => AnimatedContainer(
          duration: BW.fast,
          width: double.infinity,
          padding: padding,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: p ? Color.lerp(bg, BW.night, 0.04) : bg,
            borderRadius: BorderRadius.circular(radius),
            border: variant == CardVariant.outlined ? Border.all(color: BW.borderSubtle) : null,
          ),
          child: DefaultTextStyle.merge(style: TextStyle(color: variant == CardVariant.dark ? BW.white : BW.night), child: child),
        );
    return onTap == null ? box(false) : Pressable(onTap: onTap, scale: false, builder: box);
  }
}

enum Tone { neutral, yellow, teal, dark }

class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.tone = Tone.neutral, this.size = 44, this.iconSize = 24, this.radius = BW.rSm});
  final String icon;
  final Tone tone;
  final double size, iconSize, radius;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      Tone.neutral => (BW.sand200, BW.night),
      Tone.yellow => (BW.busYellow, BW.night),
      Tone.teal => (BW.teal100, BW.teal700),
      Tone.dark => (BW.night, BW.white),
    };
    return Container(width: size, height: size, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)), alignment: Alignment.center, child: BWIcon(icon, size: iconSize, color: fg));
  }
}

class BWListItem extends StatelessWidget {
  const BWListItem({super.key, required this.title, this.subtitle, this.icon, this.tone = Tone.neutral, this.leading, this.trailing, this.chevron = false, this.onTap, this.divider = false, this.dim = false});
  final String title;
  final String? subtitle, icon;
  final Tone tone;
  final Widget? leading, trailing;
  final bool chevron, divider, dim;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    Widget row(bool p) => AnimatedContainer(
          duration: BW.fast,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: p ? BW.sand200 : Colors.transparent, border: divider ? const Border(bottom: BorderSide(color: BW.borderSubtle)) : null),
          child: Opacity(
            opacity: dim ? 0.55 : 1,
            child: Row(children: [
              if (leading != null) leading! else if (icon != null) IconTile(icon!, tone: tone),
              if (leading != null || icon != null) const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w600, color: BW.night)),
                  if (subtitle != null) Text(subtitle!, style: BWText.small.copyWith(color: BW.textSecondary)),
                ]),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (chevron) const Padding(padding: EdgeInsets.only(left: 6), child: BWIcon('chevron-right', size: 22, color: BW.night500)),
            ]),
          ),
        );
    return onTap == null ? row(false) : Pressable(onTap: onTap, scale: false, builder: row);
  }
}

enum BadgeTone { live, info, neutral, danger, dark, success }

class BWBadge extends StatelessWidget {
  const BWBadge(this.text, {super.key, this.tone = BadgeTone.neutral, this.dot = false, this.small = false});
  final String text;
  final BadgeTone tone;
  final bool dot, small;
  @override
  Widget build(BuildContext context) {
    final (bg, fg, dc) = switch (tone) {
      BadgeTone.live => (BW.busYellow, BW.night, BW.night),
      BadgeTone.info => (BW.teal100, BW.teal700, BW.teal),
      BadgeTone.neutral => (BW.sand200, BW.night700, BW.night600),
      BadgeTone.danger => (BW.red100, BW.red600, BW.red600),
      BadgeTone.dark => (BW.night700, BW.white, BW.busYellow),
      BadgeTone.success => (BW.teal, BW.white, BW.white),
    };
    return Container(
      height: small ? 24 : 28,
      padding: EdgeInsets.symmetric(horizontal: small ? 10 : 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[Container(width: 8, height: 8, decoration: BoxDecoration(color: dc, shape: BoxShape.circle)), const SizedBox(width: 6)],
        Text(text, style: TextStyle(fontSize: small ? 13 : 14, fontWeight: FontWeight.w600, color: fg, height: 1)),
      ]),
    );
  }
}

class BWTag extends StatelessWidget {
  const BWTag(this.text, {super.key, this.selected = false, this.icon, this.onTap, this.disabled = false});
  final String text;
  final bool selected, disabled;
  final String? icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Pressable(
        onTap: disabled ? null : onTap,
        scale: false,
        builder: (p) => AnimatedContainer(
          duration: BW.fast,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? BW.night : (p ? BW.sand200 : BW.white),
            borderRadius: BorderRadius.circular(BW.rSm),
            border: Border.all(color: selected ? BW.night : BW.borderSubtle, width: 2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (selected) const BWIcon('check', size: 18, color: BW.white) else if (icon != null) BWIcon(icon!, size: 18, color: BW.night),
            if (selected || icon != null) const SizedBox(width: 8),
            Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: selected ? BW.white : BW.night)),
          ]),
        ),
      ),
    );
  }
}

class BWTopBar extends StatelessWidget {
  const BWTopBar({super.key, required this.title, this.subtitle, this.onBack, this.actions = const [], this.dark = false});
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: dark ? BW.night : BW.sand,
      constraints: const BoxConstraints(minHeight: 64),
      padding: EdgeInsets.fromLTRB(onBack != null ? 8 : 16, 8, 8, 8),
      child: Row(children: [
        if (onBack != null) BWIconButton('arrow-left', label: 'Ku noqo · Back', variant: dark ? IconBtnVariant.dark : IconBtnVariant.ghost, onTap: onBack),
        if (onBack != null) const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w700, color: dark ? BW.white : BW.night)),
            if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: BWText.small.copyWith(color: dark ? BW.onDarkMuted : BW.textSecondary)),
          ]),
        ),
        ...actions,
      ]),
    );
  }
}

class NavItem {
  const NavItem(this.id, this.icon, this.label);
  final String id, icon, label;
}

class BWBottomNav extends StatelessWidget {
  const BWBottomNav({super.key, required this.items, required this.value, required this.onChange});
  final List<NavItem> items;
  final String value;
  final ValueChanged<String> onChange;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 8, 10 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(color: BW.white, border: Border(top: BorderSide(color: BW.borderSubtle))),
      child: Row(children: [
        for (final it in items)
          Expanded(
            child: Pressable(
              onTap: () => onChange(it.id),
              scale: false,
              semanticLabel: it.label,
              builder: (_) {
                final on = it.id == value;
                return SizedBox(
                  height: 56,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    AnimatedContainer(
                      duration: BW.base,
                      width: 64,
                      height: 32,
                      decoration: BoxDecoration(color: on ? BW.busYellow : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                      alignment: Alignment.center,
                      child: BWIcon(it.icon, size: 22, color: on ? BW.night : BW.night600),
                    ),
                    const SizedBox(height: 4),
                    Text(it.label, style: TextStyle(fontSize: 13, height: 16 / 13, fontWeight: on ? FontWeight.w700 : FontWeight.w600, color: on ? BW.night : BW.night600)),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }
}

enum ToastTone { neutral, success, danger }

class BWToast extends StatelessWidget {
  const BWToast(this.message, {super.key, this.tone = ToastTone.neutral, this.icon, this.actionLabel, this.onAction});
  final String message;
  final ToastTone tone;
  final String? icon, actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final (bg, ic) = switch (tone) {
      ToastTone.neutral => (BW.night, BW.busYellow),
      ToastTone.success => (BW.teal, BW.white),
      ToastTone.danger => (BW.red600, BW.white),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(BW.rMd)),
      child: Row(children: [
        if (icon != null) ...[BWIcon(icon!, size: 22, color: ic), const SizedBox(width: 12)],
        Expanded(child: Text(message, style: const TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600, color: BW.white))),
        if (actionLabel != null)
          Pressable(
            onTap: onAction,
            builder: (_) => Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0x24FFFFFF), borderRadius: BorderRadius.circular(12)),
              child: Text(actionLabel!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: BW.white)),
            ),
          ),
      ]),
    );
  }
}

enum BannerTone { info, warning, offline, danger }

class BWBanner extends StatelessWidget {
  const BWBanner({super.key, required this.title, this.message, this.tone = BannerTone.info, this.actionLabel, this.onAction});
  final String title;
  final String? message, actionLabel;
  final BannerTone tone;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final (bg, ic, icon) = switch (tone) {
      BannerTone.info => (BW.teal100, BW.teal700, 'info'),
      BannerTone.warning => (BW.yellow100, BW.night, 'triangle-alert'),
      BannerTone.offline => (BW.night, BW.busYellow, 'wifi-off'),
      BannerTone.danger => (BW.red100, BW.red600, 'circle-alert'),
    };
    final dark = tone == BannerTone.offline;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(BW.rMd)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: BWIcon(icon, size: 22, color: ic)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w700, color: dark ? BW.white : BW.night)),
            if (message != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(message!, style: BWText.small.copyWith(color: dark ? BW.onDarkMuted : BW.textSecondary))),
          ]),
        ),
        if (actionLabel != null)
          Pressable(
            onTap: onAction,
            builder: (_) => Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              child: Text(actionLabel!, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dark ? BW.teal300 : BW.teal)),
            ),
          ),
      ]),
    );
  }
}

/// Bottom-sheet dialog with 55% Night scrim, drag handle and optional yellow icon tile.
Future<T?> showBWSheet<T>(BuildContext context, {required String title, String? subtitle, String? icon, Widget? body, required List<Widget> Function(BuildContext) actions}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: BW.scrim,
    constraints: const BoxConstraints(maxWidth: BW.contentMax),
    builder: (ctx) => Container(
      decoration: const BoxDecoration(color: BW.white, borderRadius: BorderRadius.vertical(top: Radius.circular(BW.rXl))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom + MediaQuery.paddingOf(ctx).bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: BW.night300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          if (icon != null) ...[IconTile(icon, tone: Tone.yellow, size: 56, iconSize: 28, radius: BW.rMd), const SizedBox(height: 16)],
          Text(title, style: BWText.h2),
          if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle, style: BWText.body.copyWith(color: BW.textSecondary))),
          if (body != null) ...[const SizedBox(height: 16), body],
          const SizedBox(height: 16),
          for (final (i, a) in actions(ctx).indexed) ...[if (i > 0) const SizedBox(height: 12), a],
        ]),
      ),
    ),
  );
}

class StepBar extends StatelessWidget {
  const StepBar(this.step, {super.key, this.total = 3});
  final int step, total;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(children: [
          for (var i = 1; i <= total; i++) ...[
            if (i > 1) const SizedBox(width: 6),
            Expanded(child: AnimatedContainer(duration: BW.base, height: 6, decoration: BoxDecoration(color: i <= step ? BW.teal : BW.sand300, borderRadius: BorderRadius.circular(3)))),
          ],
        ]),
      );
}

class SegOption {
  const SegOption(this.value, this.label);
  final String value, label;
}

class BWSegmented extends StatelessWidget {
  const BWSegmented({super.key, required this.options, required this.value, required this.onChange, this.onDark = false});
  final List<SegOption> options;
  final String value;
  final ValueChanged<String> onChange;
  final bool onDark;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: onDark ? BW.night700 : BW.sand200, borderRadius: BorderRadius.circular(BW.rSm + 2)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final o in options)
          Pressable(
            onTap: () => onChange(o.value),
            scale: false,
            builder: (_) {
              final on = o.value == value;
              return AnimatedContainer(
                duration: BW.base,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: on ? (onDark ? BW.busYellow : BW.white) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                child: Text(o.label, style: TextStyle(fontSize: 15, fontWeight: on ? FontWeight.w700 : FontWeight.w600, color: on ? BW.night : (onDark ? BW.onDarkMuted : BW.night600))),
              );
            },
          ),
      ]),
    );
  }
}

class BWSwitchRow extends StatelessWidget {
  const BWSwitchRow({super.key, required this.label, this.subLabel, required this.value, required this.onChanged});
  final String label;
  final String? subLabel;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => onChanged(!value),
      scale: false,
      builder: (_) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: const TextStyle(fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w600)),
              if (subLabel != null) Text(subLabel!, style: BWText.small.copyWith(color: BW.textSecondary)),
            ]),
          ),
          const SizedBox(width: 12),
          AnimatedContainer(
            duration: BW.base,
            curve: BW.easeOut,
            width: 52,
            height: 32,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: value ? BW.teal : BW.night300, borderRadius: BorderRadius.circular(16)),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: BW.white, shape: BoxShape.circle)),
          ),
        ]),
      ),
    );
  }
}

class RadioOption {
  const RadioOption(this.value, this.label, [this.subLabel]);
  final String value, label;
  final String? subLabel;
}

class BWRadioGroup extends StatelessWidget {
  const BWRadioGroup({super.key, required this.options, required this.value, required this.onChange});
  final List<RadioOption> options;
  final String? value;
  final ValueChanged<String> onChange;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final o in options)
        Pressable(
          onTap: () => onChange(o.value),
          scale: false,
          builder: (_) {
            final on = o.value == value;
            return Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                AnimatedContainer(
                  duration: BW.fast,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? BW.teal : BW.night300, width: 2)),
                  alignment: Alignment.center,
                  child: on ? Container(width: 12, height: 12, decoration: const BoxDecoration(color: BW.teal, shape: BoxShape.circle)) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o.label, style: TextStyle(fontSize: 17, height: 24 / 17, fontWeight: on ? FontWeight.w700 : FontWeight.w600)),
                    if (o.subLabel != null) Text(o.subLabel!, style: BWText.small.copyWith(color: BW.textSecondary)),
                  ]),
                ),
              ]),
            );
          },
        ),
    ]);
  }
}

class BWInput extends StatelessWidget {
  const BWInput({super.key, this.controller, this.hint, this.icon, this.onChanged, this.keyboardType, this.maxLength, this.autofocus = false, this.prefixText, this.inputFormatters, this.label, this.obscure = false, this.onSubmitted});
  final TextEditingController? controller;
  final String? hint, icon, prefixText, label;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int? maxLength;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscure;
  final ValueChanged<String>? onSubmitted;
  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c) => OutlineInputBorder(borderRadius: BorderRadius.circular(BW.rSm), borderSide: BorderSide(color: c, width: 2));
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofocus: autofocus,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 17, height: 24 / 17, color: BW.night),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        hintStyle: const TextStyle(color: BW.textPlaceholder, fontSize: 17),
        prefixText: prefixText,
        prefixStyle: const TextStyle(fontSize: 17, color: BW.night, fontWeight: FontWeight.w600),
        prefixIcon: icon == null ? null : Padding(padding: const EdgeInsets.only(left: 14, right: 10), child: BWIcon(icon!, size: 22, color: BW.night500)),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        filled: true,
        fillColor: BW.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: b(BW.night300),
        focusedBorder: b(BW.teal),
        border: b(BW.night300),
      ),
    );
  }
}

/// "Somali · English" section label.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.primary, this.secondary, {super.key, this.large = false});
  final String primary, secondary;
  final bool large;
  @override
  Widget build(BuildContext context) => Text.rich(TextSpan(children: [
        TextSpan(text: primary, style: TextStyle(fontSize: large ? 18 : 16, fontWeight: FontWeight.w700, color: BW.night)),
        TextSpan(text: ' · $secondary', style: TextStyle(fontSize: large ? 18 : 16, fontWeight: FontWeight.w400, color: BW.textSecondary)),
      ]));
}

/// Single-column, max 480px content. Wider screens see Sand-300 around it.
class MobileFrame extends StatelessWidget {
  const MobileFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BW.sand300,
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: BW.contentMax), child: ClipRect(child: ColoredBox(color: BW.sand, child: child)))),
    );
  }
}
