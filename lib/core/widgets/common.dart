import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../tokens.dart';
import '../models.dart';
import '../../state/app_state.dart';

// ─────────────────────────────────────────────
// AnimatedPress — scales child on tap for springy
// micro-interaction feedback on any interactive
// element.
// ─────────────────────────────────────────────
class AnimatedPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const AnimatedPress({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
  });

  @override
  State<AnimatedPress> createState() => _AnimatedPressState();
}

class _AnimatedPressState extends State<AnimatedPress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppAnimation.fast,
    );
    _anim = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) => Transform.scale(
          scale: _anim.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FadeInSlide — staggered entrance animation for
// list items / cards.
// ─────────────────────────────────────────────
class FadeInSlide extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delayPerItem;

  const FadeInSlide({
    super.key,
    required this.child,
    this.index = 0,
    this.delayPerItem = const Duration(milliseconds: 60),
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(widget.delayPerItem * widget.index, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ─────────────────────────────────────────────
// AppIcon — wraps Material icons with the design
// system's sizing/weight
// ─────────────────────────────────────────────
class AppIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const AppIcon(this.name, {super.key, this.size = 18, this.color});

  static const Map<String, IconData> _map = {
    'home': Icons.home_outlined,
    'wrench': Icons.build_outlined,
    'shield': Icons.shield_outlined,
    'help': Icons.help_outline,
    'description': Icons.description_outlined,
    'calendar': Icons.calendar_today_outlined,
    'people': Icons.people_outline,
    'wallet': Icons.account_balance_wallet_outlined,
    'inventory_2': Icons.inventory_2_outlined,
    'view_kanban': Icons.view_kanban_outlined,
    'how_to_reg': Icons.how_to_reg_outlined,
    'storefront': Icons.storefront_outlined,
    'receipt': Icons.receipt_outlined,
    'person_add': Icons.person_add_alt_1_outlined,
    'arrow_forward': Icons.arrow_forward,
    'arrow_back': Icons.arrow_back,
    'north_east': Icons.north_east,
    'chevron_right': Icons.chevron_right,
    'chevron_down': Icons.expand_more,
    'chevron_up': Icons.expand_less,
    'add': Icons.add,
    'close': Icons.close,
    'check': Icons.check,
    'sparkles': Icons.auto_awesome,
    'trending_up': Icons.trending_up,
    'trending_down': Icons.trending_down,
    'warning': Icons.warning_amber_outlined,
    'bell': Icons.notifications_outlined,
    'settings': Icons.settings_outlined,
    'logout': Icons.logout,
    'crown': Icons.workspace_premium_outlined,
    'lock': Icons.lock_outline,
    'search': Icons.search,
    'more_horiz': Icons.more_horiz,
    'globe': Icons.language,
    'chat': Icons.chat_bubble_outline,
    'phone': Icons.phone_outlined,
    'eye': Icons.visibility_outlined,
    'check_circle': Icons.check_circle_outline,
    'clock': Icons.access_time,
    'camera_alt': Icons.camera_alt_outlined,
    'campaign': Icons.campaign_outlined,
    'local_shipping': Icons.local_shipping_outlined,
    'bolt': Icons.bolt_outlined,
    'calculate': Icons.calculate_outlined,
    'palette': Icons.palette_outlined,
    'balance': Icons.balance_outlined,
    'star': Icons.star_outline,
    'download': Icons.download_outlined,
    'upload': Icons.upload_file,
    'share': Icons.share_outlined,
    'payments': Icons.payments_outlined,
    'mail': Icons.email_outlined,
    'tune': Icons.tune,
    'user': Icons.person_outline,
    'users': Icons.people_outline,
    'banknote': Icons.payments_outlined,
    'message_circle': Icons.chat_bubble_outline,
    'grid_view': Icons.grid_view_outlined,
    'sparkle': Icons.auto_awesome,
    'plus': Icons.add,
    'file_text': Icons.description_outlined,
    'request_quote': Icons.request_quote,
    'store': Icons.storefront_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _map[name.toLowerCase()] ?? Icons.circle_outlined;
    return Icon(icon, size: size, color: color);
  }
}

// ─────────────────────────────────────────────
// AppCard — elevated card with optional entrance
// animation and touch feedback.
// ─────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? background;
  final Border? border;
  final double radius;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;
  final bool animate; // Enters with fade+slide

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.background,
    this.border,
    this.radius = AppRadius.lg,
    this.onTap,
    this.shadows,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = Container(
      decoration: BoxDecoration(
        color: background ?? c.bgElevated,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? Border.all(color: c.border),
        boxShadow: shadows ?? AppShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: padding != null
          ? Padding(padding: padding!, child: child)
          : child,
    );

    Widget wrapped = content;
    if (onTap != null) {
      wrapped = AnimatedPress(onTap: onTap, child: content);
    }
    if (animate) {
      wrapped = FadeInSlide(child: wrapped);
    }
    return wrapped;
  }
}

// ─────────────────────────────────────────────
// AppPill — status / category badge
// ─────────────────────────────────────────────
enum PillTone { teal, orange, green, rose, amber, neutral, inverse, navy }

class AppPill extends StatelessWidget {
  final String label;
  final PillTone tone;
  final bool small;
  final String? icon;

  const AppPill(
    this.label, {
    super.key,
    this.tone = PillTone.neutral,
    this.small = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (tone) {
      PillTone.teal    => (c.tealSurface, c.teal),
      PillTone.navy    => (c.navySurface, c.navyDeep),
      PillTone.orange  => (c.amberSurface, c.amber),
      PillTone.green   => (c.greenSurface, c.green),
      PillTone.rose    => (c.roseSurface, c.rose),
      PillTone.amber   => (const Color(0x24F5B021), const Color(0xFFB07804)),
      PillTone.inverse => (c.text, c.bgElevated),
      PillTone.neutral => (c.bgInset, c.textMuted),
    };
    final fs = small ? 10.5 : 12.0;
    final py = small ? 3.0 : 4.0;
    final px = small ? 7.0 : 9.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: px, vertical: py),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            AppIcon(icon!, size: small ? 11 : 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppType.body(size: fs, weight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AppBtn — press-animated button with gradient
// support
// ─────────────────────────────────────────────
enum BtnVariant { primary, secondary, ghost, outline, dark, gradient }

class AppBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final BtnVariant variant;
  final bool full;
  final String? icon;
  final double? fontSize;

  const AppBtn(
    this.label, {
    super.key,
    this.onTap,
    this.variant = BtnVariant.primary,
    this.full = false,
    this.icon,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fs = fontSize ?? 14.0;

    final (bg, fg, bd) = switch (variant) {
      BtnVariant.primary   => (c.teal, Colors.white, c.teal),
      BtnVariant.secondary => (c.bgInset, c.text, c.border),
      BtnVariant.ghost     => (Colors.transparent, c.teal, Colors.transparent),
      BtnVariant.outline   => (Colors.transparent, c.text, c.borderStrong),
      BtnVariant.dark      => (c.text, c.bgElevated, c.text),
      BtnVariant.gradient  => (c.navy, Colors.white, c.navy), // handled by decor
    };

    final boxShadows = variant == BtnVariant.primary || variant == BtnVariant.gradient
        ? [BoxShadow(color: c.teal.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
        : null;

    Widget button = Container(
      width: full ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        gradient: variant == BtnVariant.gradient
            ? LinearGradient(
                colors: [c.teal, c.tealDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: variant != BtnVariant.gradient ? bg : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: bd),
        boxShadow: boxShadows,
      ),
      child: Row(
        mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            AppIcon(icon!, size: 16, color: fg),
            const SizedBox(width: 8),
          ],
          Text(label,
              style: AppType.body(size: fs, weight: FontWeight.w600, color: fg)),
        ],
      ),
    );

    if (onTap != null) {
      button = AnimatedPress(onTap: onTap, child: button);
    }
    return button;
  }
}

// ─────────────────────────────────────────────
// AppAvatar
// ─────────────────────────────────────────────
class AppAvatar extends StatelessWidget {
  final String initials;
  final double size;
  final String tone; // 'teal' | 'orange'
  /// Optional image URL. When provided, shows a network image instead of initials.
  final String? imageUrl;
  /// Called when the avatar is tapped. Useful for logo upload.
  final VoidCallback? onTap;

  const AppAvatar(this.initials, {
    super.key,
    this.size = 36,
    this.tone = 'teal',
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = tone == 'orange' ? c.amberSurface : c.tealSurface;
    final fg = tone == 'orange' ? c.amber : c.teal;

    /// Renders the initials fallback inside a circle.
    Widget initialsWidget() => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.outfit(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );

    /// When an imageUrl is provided, use Image.network with loadingBuilder
    /// (shimmer skeleton while loading) and errorBuilder (initials fallback
    /// on network failure).
    Widget avatar;
    if (imageUrl != null) {
      avatar = ClipOval(
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            // Show a shimmer skeleton while the image loads
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(size / 2),
                child: AppShimmer(width: size, height: size, radius: size / 2),
              ),
            );
          },
          errorBuilder: (_, __, ___) => initialsWidget(),
        ),
      );
    } else {
      avatar = initialsWidget();
    }

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }
}

// ─────────────────────────────────────────────
// AppMonogram — branded "AS" tile with gradient
// ─────────────────────────────────────────────
class AppMonogram extends StatelessWidget {
  final double size;
  const AppMonogram({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.teal, c.tealDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Text(
        'AS',
        style: GoogleFonts.outfit(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.02 * size * 0.42,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AppShimmer — animated loading placeholder with
// sweeping gradient
// ─────────────────────────────────────────────
class AppShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const AppShimmer({
    super.key,
    required this.width,
    required this.height,
    this.radius = 4,
  });

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1 + 3 * _ctrl.value, 0),
            end: Alignment(1 + 3 * _ctrl.value, 0),
            colors: [c.skeleton, c.bgInset, c.skeleton],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SectionHeader
// ─────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: AppType.heading(size: 17, color: c.text)),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: AppType.body(size: 13, weight: FontWeight.w600, color: c.teal)),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AppPeriodSelector — shared 1M / 3M / 6M / YTD pill row
// Uses Consumer<AppState> internally so it works anywhere.
// ─────────────────────────────────────────────
class AppPeriodSelector extends StatelessWidget {
  /// Optional padding override. Defaults to EdgeInsets.symmetric(horizontal: 12, vertical: 5).
  final EdgeInsetsGeometry? pillPadding;

  const AppPeriodSelector({super.key, this.pillPadding});

  static const _labels = ['1M', '3M', '6M', 'YTD'];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (ctx, state, _) {
        final sc = ctx.colors;
        return Row(
          children: [
            for (int i = 0; i < 4; i++)
              GestureDetector(
                onTap: () => state.setSelectedPeriod(i),
                child: AnimatedContainer(
                  duration: AppAnimation.fast,
                  padding: pillPadding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: state.selectedPeriodIndex == i
                        ? sc.tealSurface
                        : sc.bgElevated,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: state.selectedPeriodIndex == i
                          ? sc.teal
                          : sc.border,
                    ),
                  ),
                  child: Text(
                    _labels[i],
                    style: AppType.label(
                      size: 10,
                      color: state.selectedPeriodIndex == i
                          ? sc.tealDeep
                          : sc.textMuted,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// SubScreenHeader — back button + title + action
// ─────────────────────────────────────────────
class SubScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  const SubScreenHeader(this.title, {super.key, required this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          AnimatedPress(
            onTap: onBack,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: c.bgElevated,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: c.border),
              ),
              child: Icon(Icons.arrow_back, size: 18, color: c.text),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: AppType.heading(size: 18, color: c.text)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GlassSheet — bottom sheet with frosted glass
// background effect
// ─────────────────────────────────────────────
class GlassSheet extends StatelessWidget {
  final Widget child;
  final double maxHeightRatio;

  const GlassSheet({
    super.key,
    required this.child,
    this.maxHeightRatio = 0.9,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    double maxHeightRatio = 0.9,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GlassSheet(child: child, maxHeightRatio: maxHeightRatio),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * maxHeightRatio,
        ),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          color: c.bgElevated,
          boxShadow: AppShadows.sheet,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Sheet drag handle
// ─────────────────────────────────────────────
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: c.borderStrong,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AppInput — enhanced text field with animated
// focus border and leading icon
// ─────────────────────────────────────────────
class AppInput extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final String? hint;

  const AppInput({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.focusNode,
    this.hint,
  });

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isFocused = _focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: AppType.body(
                size: 11.5, weight: FontWeight.w600, color: c.textMuted)),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: AppAnimation.fast,
          height: 50,
          decoration: BoxDecoration(
            color: c.bgInset,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(                  color: isFocused ? c.teal : c.border,
              width: isFocused ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(widget.icon, size: 17,
                  color: isFocused ? c.teal : c.textFaint),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  obscureText: widget.obscure,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  autofillHints: widget.autofillHints,
                  onSubmitted: widget.onSubmitted,
                  style: AppType.body(
                      size: 14, weight: FontWeight.w500, color: c.text),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: widget.hint,
                    hintStyle: AppType.body(size: 14, color: c.textFaint),
                  ),
                ),
              ),
              if (widget.suffix != null) ...[widget.suffix!, const SizedBox(width: 14)],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// GoogleSignInButton
// ─────────────────────────────────────────────
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool loading;
  final String label;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.label = 'Continue with Google',
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPress(
      onTap: loading ? null : onPressed,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: c.borderStrong),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation(c.text),
                ),
              )
            else
              const _GoogleGlyph(size: 18),
            const SizedBox(width: 12),
            Text(label,
                style: AppType.body(
                    size: 14, weight: FontWeight.w600, color: c.text)),
          ],
        ),
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  final double size;
  const _GoogleGlyph({this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleGPainter(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AiFormattedText — formatted AI response with
// paragraph breaks, header detection, and cash
// highlights.
// ─────────────────────────────────────────────
class AiFormattedText extends StatelessWidget {
  final String text;
  final Color baseColor;
  final Color highlightColor;

  const AiFormattedText({
    super.key,
    required this.text,
    required this.baseColor,
    required this.highlightColor,
  });

  static final _cashPattern = RegExp(r'GHS\s?[0-9,]+(?:\.[0-9]+)?');

  @override
  Widget build(BuildContext context) {
    final paragraphs = text.split(RegExp(r'\n{2,}'));
    if (paragraphs.length <= 1) {
      return _buildParagraph(text.replaceAll('\n', ' '), bold: false);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.asMap().entries.map((e) {
        final para = e.value.trim();
        if (para.isEmpty) return const SizedBox.shrink();
        final isHeader = para.endsWith(':') ||
            (para.length < 60 && para == para.toUpperCase() &&
                !para.contains('GHS'));
        return Padding(
          padding: EdgeInsets.only(top: e.key > 0 ? 8 : 0),
          child: _buildParagraph(para, bold: isHeader),
        );
      }).toList(),
    );
  }

  Widget _buildParagraph(String para, {required bool bold}) {
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in _cashPattern.allMatches(para)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: para.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: AppType.body(
          size: 14,
          weight: FontWeight.w700,
          color: highlightColor,
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < para.length) {
      spans.add(TextSpan(text: para.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: AppType.body(
          size: bold ? 15 : 14,
          weight: bold ? FontWeight.w600 : FontWeight.w400,
          color: baseColor,
        ).copyWith(height: 1.4),
        children: spans,
      ),
    );
  }
}

/// Paints the official Google "G" logo with the four brand colors
/// (blue #4285F4, red #EA4335, yellow #FBBC05, green #34A853)
/// using SVG-derived paths from Google's branding assets.
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48.0;
    canvas.scale(s, s);

    // ── Blue segment (top/left arc) ────────────────────────────────────
    final bluePath = Path()
      ..moveTo(45.12, 24.5)
      ..cubicTo(45.12, 22.94, 44.98, 21.44, 44.72, 20.0)
      ..lineTo(24.0, 20.0)
      ..lineTo(24.0, 28.51)
      ..lineTo(35.84, 28.51)
      ..cubicTo(35.33, 31.26, 33.78, 33.59, 31.45, 35.15)
      ..lineTo(31.45, 40.67)
      ..lineTo(38.56, 40.67)
      ..cubicTo(42.72, 36.84, 45.12, 31.20, 45.12, 24.5)
      ..close();
    canvas.drawPath(bluePath, Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill);

    // ── Green segment (right side) ────────────────────────────────────
    final greenPath = Path()
      ..moveTo(24.0, 46.0)
      ..cubicTo(29.94, 46.0, 34.92, 44.03, 38.56, 40.67)
      ..lineTo(31.45, 35.15)
      ..cubicTo(29.48, 36.47, 26.96, 37.25, 24.0, 37.25)
      ..cubicTo(18.27, 37.25, 13.42, 33.38, 11.69, 28.18)
      ..lineTo(4.34, 28.18)
      ..lineTo(4.34, 33.88)
      ..cubicTo(7.96, 41.07, 15.4, 46.0, 24.0, 46.0)
      ..close();
    canvas.drawPath(greenPath, Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.fill);

    // ── Red segment (bottom left) ─────────────────────────────────────
    final redPath = Path()
      ..moveTo(11.69, 28.18)
      ..cubicTo(11.25, 26.84, 11.0, 25.44, 11.0, 24.0)
      ..cubicTo(11.0, 22.56, 11.25, 21.16, 11.69, 19.82)
      ..lineTo(11.69, 14.12)
      ..lineTo(4.34, 14.12)
      ..cubicTo(2.85, 17.09, 2.0, 20.45, 2.0, 24.0)
      ..cubicTo(2.0, 27.55, 2.85, 30.91, 4.34, 33.88)
      ..lineTo(11.69, 28.18)
      ..close();
    canvas.drawPath(redPath, Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.fill);

    // ── Yellow segment (bottom right) ─────────────────────────────────
    final yellowPath = Path()
      ..moveTo(24.0, 10.75)
      ..cubicTo(27.23, 10.75, 30.13, 11.86, 32.41, 14.04)
      ..lineTo(38.72, 7.73)
      ..cubicTo(34.91, 4.18, 29.93, 2.0, 24.0, 2.0)
      ..cubicTo(15.4, 2.0, 7.96, 6.93, 4.34, 14.12)
      ..lineTo(11.69, 19.82)
      ..cubicTo(13.42, 14.62, 18.27, 10.75, 24.0, 10.75)
      ..close();
    canvas.drawPath(yellowPath, Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// BottomNav
// ─────────────────────────────────────────────
class BottomNav extends StatelessWidget {
  final AppTab current;
  final ValueChanged<AppTab> onTab;
  final NavVariant variant;

  const BottomNav({
    super.key,
    required this.current,
    required this.onTab,
    this.variant = NavVariant.classic,
  });

  static const _tabs = [
    (AppTab.home,     'Home',     Icons.home_outlined,                    Icons.home),
    (AppTab.finance,  'Finance',  Icons.account_balance_wallet_outlined,  Icons.account_balance_wallet),
    (AppTab.tools,    'Tools',    Icons.build_outlined,                   Icons.build),
    (AppTab.profile,  'Profile',  Icons.person_outline,                   Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      NavVariant.pill    => _pillNav(context),
      NavVariant.fab     => _classicNav(context),
      NavVariant.classic => _classicNav(context),
    };
  }

  Widget _classicNav(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        border: Border(top: BorderSide(color: c.border)),
        boxShadow: const [
          BoxShadow(color: Color(0x0F031632), blurRadius: 24, offset: Offset(0, -8)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (final tab in _tabs) Expanded(child: _tabButton(context, tab, c)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(
      BuildContext ctx, (AppTab, String, IconData, IconData) t, AppColorsX c) {
    final active = current == t.$1;
    return GestureDetector(
      onTap: () => onTab(t.$1),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: AppAnimation.normal,
            curve: Curves.easeOutBack,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 3),
            decoration: BoxDecoration(
              color: active ? c.tealSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Icon(
              active ? t.$4 : t.$3,
              size: 20,
              color: active ? c.teal : c.textFaint,
            ),
          ),
          const SizedBox(height: 2),
          Text(t.$2,
              style: AppType.body(
                  size: 10.5,
                  weight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? c.teal : c.textFaint)),
        ],
      ),
    );
  }

  Widget _pillNav(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 28, left: 16, right: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: (context.isDark
                        ? const Color(0xFF141B1E)
                        : Colors.white)
                    .withValues(alpha: 0.78),
                border: Border.all(color: c.border),
                boxShadow: AppShadows.cardLg,
              ),
              padding: const EdgeInsets.all(6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: _tabs.map((t) {
                  final active = current == t.$1;
                  return GestureDetector(
                    onTap: () => onTab(t.$1),
                    child: AnimatedContainer(
                      duration: AppAnimation.normal,
                      curve: Curves.easeOutBack,
                      padding: EdgeInsets.symmetric(
                          horizontal: active ? 14 : 11, vertical: 9),
                      decoration: BoxDecoration(
                        color: active ? c.teal : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(active ? t.$4 : t.$3,
                              size: 17,
                              color: active
                                  ? Colors.white
                                  : c.textMuted),
                          if (active) ...[
                            const SizedBox(width: 6),
                            Text(t.$2,
                                style: AppType.body(
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color: Colors.white)),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PlaceholderImage
// ─────────────────────────────────────────────
class PlaceholderImage extends StatelessWidget {
  final double? width;
  final double height;
  final String? label;

  const PlaceholderImage({super.key, this.width, this.height = 80, this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: c.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.bgInset, c.bg, c.bgInset, c.bg],
          stops: const [0.0, 0.25, 0.5, 0.75],
          tileMode: TileMode.repeated,
        ),
      ),
      alignment: Alignment.center,
      child: label != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: c.bgElevated,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: c.border),
              ),
              child: Text(label!, style: AppType.mono(size: 10, color: c.textFaint)),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────
// TierRing
// ─────────────────────────────────────────────
class TierRing extends StatelessWidget {
  final int score;
  final String initials;
  final double size;

  const TierRing({super.key, required this.score, required this.initials, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final tier = getTier(score);
    final next = getNextTier(score);
    final prev = tier.min;
    final goal = next?.min ?? 100;
    final progress = ((score - prev) / (goal - prev)).clamp(0.0, 1.0);
    final tierColor = Color(tier.color);

    return SizedBox(
      width: size, height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          ringColor: tierColor,
          trackColor: context.colors.bgInset,
          strokeWidth: 3,
        ),
        child: Center(
          child: Container(
              margin: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: context.colors.tealSurface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: GoogleFonts.outfit(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w600,
                  color: context.colors.teal,
                ),
              ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor, trackColor;
  final double strokeWidth;

  const _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(rect, 0, 2 * 3.14159, false,
        Paint()..color = trackColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth);

    canvas.drawArc(
      rect, -3.14159 / 2, 2 * 3.14159 * progress, false,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.ringColor != ringColor;
}

// ─────────────────────────────────────────────
// AppSheetOption — option tile used in bottom-sheet photo pickers and
// other simple option lists. Works identically in Settings, Drawer, etc.
// ─────────────────────────────────────────────
class AppSheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const AppSheetOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20,
                color: destructive ? c.rose : c.text),
            const SizedBox(width: 14),
            Text(label,
                style: AppType.body(
                    size: 14,
                    weight: FontWeight.w500,
                    color: destructive ? c.rose : c.text)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// showPaymentMethodSheet — cash / mobile money / bank transfer picker.
// Returns the method key ('cash', 'momo', or 'bank') or null if dismissed.
// ─────────────────────────────────────────────
Future<String?> showPaymentMethodSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final c = ctx.colors;
      const options = [
        ('cash', 'Cash', Icons.money),
        ('momo', 'Mobile Money', Icons.phone_android),
        ('bank', 'Bank transfer', Icons.account_balance),
      ];
      return Container(
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(ctx).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 4),
            Text('How was it paid?',
                style: AppType.heading(size: 18, color: c.text)),
            const SizedBox(height: 6),
            Text('This creates a receipt linked to the invoice.',
                style: AppType.body(size: 12.5, color: c.textMuted)),
            const SizedBox(height: 16),
            for (final (value, label, icon) in options)
              GestureDetector(
                onTap: () => Navigator.pop(ctx, value),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: c.navySurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 18, color: c.navy),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(label,
                            style: AppType.body(
                                size: 14,
                                weight: FontWeight.w600,
                                color: c.text)),
                      ),
                      Icon(Icons.chevron_right, size: 18, color: c.textFaint),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────
// showPhotoOptionsSheet — bottom sheet with "Change photo" / "Remove photo"
// options. Returns 'change', 'remove', or null if dismissed.
// ─────────────────────────────────────────────
Future<String?> showPhotoOptionsSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final c = ctx.colors;
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: c.bgElevated,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 5,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: c.textFaint,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                AppSheetOption(
                  icon: Icons.camera_alt_outlined,
                  label: 'Change photo',
                  onTap: () => Navigator.pop(ctx, 'change'),
                ),
                AppSheetOption(
                  icon: Icons.delete_outline,
                  label: 'Remove photo',
                  onTap: () => Navigator.pop(ctx, 'remove'),
                  destructive: true,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    },
  );
}
