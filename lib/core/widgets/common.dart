import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  const AppAvatar(this.initials, {super.key, this.size = 36, this.tone = 'teal'});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bg = tone == 'orange' ? c.amberSurface : c.tealSurface;
    final fg = tone == 'orange' ? c.amber : c.teal;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
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
      builder: (_, __) => Container(
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
    final hasText = widget.controller.text.isNotEmpty;

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
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'G',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Color(0xFF4285F4),
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BottomNav
// ─────────────────────────────────────────────
class BottomNav extends StatelessWidget {
  final AppTab current;
  final ValueChanged<AppTab> onTab;
  final VoidCallback onCreate;
  final NavVariant variant;

  const BottomNav({
    super.key,
    required this.current,
    required this.onTab,
    required this.onCreate,
    this.variant = NavVariant.classic,
  });

  static const _tabs = [
    (AppTab.home,      'Home',      Icons.home_outlined,                  Icons.home),
    (AppTab.finance,   'Finance',   Icons.account_balance_wallet_outlined, Icons.account_balance_wallet),
    (AppTab.customers, 'Customers', Icons.people_alt_outlined,             Icons.people_alt),
    (AppTab.profile, 'Profile', Icons.person_outline,                    Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      NavVariant.pill    => _pillNav(context),
      NavVariant.fab     => _classicNav(context, fab: true),
      NavVariant.classic => _classicNav(context, fab: false),
    };
  }

  Widget _classicNav(BuildContext context, {required bool fab}) {
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                for (int i = 0; i < _tabs.length; i++) ...[
                  if (fab && i == 2) _fabButton(context, c),
                  _tabButton(context, _tabs[i], c),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabButton(
      BuildContext ctx, (AppTab, String, IconData, IconData) t, AppColorsX c) {
    final active = current == t.$1;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTab(t.$1),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppAnimation.normal,
          curve: Curves.easeOut,
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
        ),
      ),
    );
  }

  Widget _fabButton(BuildContext context, AppColorsX c) {
    return SizedBox(
      width: 64,
      child: GestureDetector(
        onTap: onCreate,
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, -12),
            child: AnimatedPress(
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.teal, c.tealDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: c.teal.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
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
