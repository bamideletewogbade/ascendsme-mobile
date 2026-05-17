import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../tokens.dart';
import '../models.dart';
import '../../state/app_state.dart';

// ─────────────────────────────────────────────
// AppIcon — wraps Material icons with the design system's sizing/weight
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
// AppCard
// ─────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? background;
  final Border? border;
  final double radius;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.background,
    this.border,
    this.radius = 18,
    this.onTap,
    this.shadows,
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
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

// ─────────────────────────────────────────────
// AppPill — status / category badge
// ─────────────────────────────────────────────
enum PillTone { teal, orange, green, rose, amber, neutral, inverse }

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
      PillTone.teal    => (c.tealSurface, c.tealDeep),
      PillTone.orange  => (c.orangeSurface, c.orange),
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
        borderRadius: BorderRadius.circular(999),
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
// AppBtn
// ─────────────────────────────────────────────
enum BtnVariant { primary, secondary, ghost, outline, dark }

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
    final (bg, fg, bd) = switch (variant) {
      BtnVariant.primary   => (c.teal, Colors.white, c.teal),
      BtnVariant.secondary => (c.bgInset, c.text, c.border),
      BtnVariant.ghost     => (Colors.transparent, c.teal, Colors.transparent),
      BtnVariant.outline   => (Colors.transparent, c.text, c.borderStrong),
      BtnVariant.dark      => (c.text, c.bgElevated, c.text),
    };
    final fs = fontSize ?? 14.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: full ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: bd),
          boxShadow: variant == BtnVariant.primary
              ? [BoxShadow(color: c.teal.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
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
      ),
    );
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
    final bg = tone == 'orange' ? c.orangeSurface : c.tealSurface;
    final fg = tone == 'orange' ? c.orange : c.tealDeep;
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
// Monogram — "AS" branded tile
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
// Shimmer loading placeholder
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
      builder: (context2, snap) => Container(
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
// SubScreenHeader — back button + title + optional action
// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
// GoogleSignInButton — outlined button matching the design system, used on
// the sign-in and sign-up screens. The Google "G" is a flat colour-blocked
// approximation drawn with Container rotated quadrants; avoids shipping a
// raster asset just for one logo.
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
    return GestureDetector(
      onTap: loading ? null : onPressed,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: BorderRadius.circular(14),
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
    // Simplified Google "G" mark — colour-blocked, not the official SVG, but
    // recognisable. Replace with the official asset before public release.
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

class SubScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  const SubScreenHeader(this.title, {super.key, required this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: c.bgElevated,
                borderRadius: BorderRadius.circular(12),
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
          ?trailing,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BottomNav — three variants from the design
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
    (AppTab.profile,   'Profile',   Icons.person_outline,                  Icons.person),
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
    final isDark = context.isDark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0A0F11).withValues(alpha: 0.88)
            : Colors.white.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
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
    );
  }

  Widget _tabButton(BuildContext ctx, (AppTab, String, IconData, IconData) t, AppColorsX c) {
    final active = current == t.$1;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTab(t.$1),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? t.$4 : t.$3, size: 22,
                color: active ? c.teal : c.textFaint),
            const SizedBox(height: 3),
            Text(t.$2,
                style: AppType.body(
                    size: 10.5,
                    weight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? c.teal : c.textFaint)),
          ],
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
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: c.teal,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: c.teal.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillNav(BuildContext context) {
    final c = context.colors;
    final isDark = context.isDark;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 28, left: 16, right: 16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF141B1E).withValues(alpha: 0.78)
                : Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(999),
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
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(
                      horizontal: active ? 14 : 11, vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? c.teal : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(active ? t.$4 : t.$3, size: 17,
                          color: active ? Colors.white : c.textMuted),
                      if (active) ...[
                        const SizedBox(width: 6),
                        Text(t.$2,
                            style: AppType.body(
                                size: 12, weight: FontWeight.w600,
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
    );
  }
}

// ─────────────────────────────────────────────
// PlaceholderImage — striped box used for images not yet loaded
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
        borderRadius: BorderRadius.circular(12),
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
// Sheet drag handle
// ─────────────────────────────────────────────
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Container(
        width: 38, height: 4,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: c.borderStrong,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TierRing — avatar with animated tier progress arc
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
                color: context.colors.tealDeep,
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
// StreakChip
// ─────────────────────────────────────────────
