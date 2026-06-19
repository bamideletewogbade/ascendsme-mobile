import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/share_utils.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/booking_service.dart' as svc;
import '../../services/crm_service.dart';
import '../../state/app_state.dart';
import '../sheets/create_booking_sheet.dart';
import '../sheets/create_booking_service_sheet.dart';

/// Booking screen — manages appointments, services, and the booking portal.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String _view = 'bookings'; // 'bookings' | 'services'
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.bookings.isEmpty && !state.bookingsLoading) {
        state.loadBookings();
      }
    });
  }

  List<Booking> get _filteredBookings {
    final all = context.read<AppState>().bookings;
    if (_statusFilter == 'all') return all;
    return all.where((b) => b.status == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            _buildHeader(c),
            // ── View toggle ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Row(
                children: [
                  _ViewToggle(
                    label: 'Bookings',
                    active: _view == 'bookings',
                    onTap: () => setState(() => _view = 'bookings'),
                  ),
                  const SizedBox(width: 8),
                  _ViewToggle(
                    label: 'Services',
                    active: _view == 'services',
                    onTap: () => setState(() => _view = 'services'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _view == 'bookings' ? _buildBookingsView(c) : _buildServicesView(c)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppColorsX c) {
    final state = context.read<AppState>();
    final handle = state.business.handle.replaceAll('@', '');
    final portalUrl = 'https://ascendsme.africa/b/$handle';

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              AnimatedPress(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38,
                  height: 38,
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
                child: Text('Bookings',
                    style: AppType.heading(size: 18, color: c.text)),
              ),
              // Portal link button
              GestureDetector(
                onTap: () => _sharePortalLink(context, portalUrl),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.tealSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.teal.withValues(alpha: 0.3)),
                  ),
                  child: AppIcon('share', size: 16, color: c.teal),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showCreateService(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.bgInset,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.border),
                  ),
                  child: AppIcon('tune', size: 16, color: c.textMuted),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showCreateBooking(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: c.teal,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          // Portal link card
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _sharePortalLink(context, portalUrl),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c.tealSurface, c.tealSurfaceStrong.withValues(alpha: 0.5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: c.teal.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c.teal,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.link_rounded, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Booking portal active',
                            style: AppType.body(
                                size: 12.5, weight: FontWeight.w600, color: c.text)),
                        Text(portalUrl,
                            style: AppType.body(
                                size: 10.5, color: c.teal),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.teal,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share_rounded, size: 10, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('Share',
                            style: AppType.body(
                                size: 10, weight: FontWeight.w600, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sharePortalLink(BuildContext context, String url) async {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 4),
            Text('Share booking portal',
                style: AppType.heading(size: 18, color: c.text)),
            const SizedBox(height: 4),
            Text('Customers can see your services and book directly.',
                style: AppType.body(size: 12.5, color: c.textMuted)),
            const SizedBox(height: 16),
            // URL display
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.bgInset,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(url,
                        style: AppType.mono(size: 11, color: c.text),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: url));
                      Navigator.pop(ctx);
                      _showSnackBar('Link copied to clipboard');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: c.bgInsetStrong,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.copy_rounded, size: 16, color: c.teal),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppBtn(
                    'Share via WhatsApp',
                    icon: 'chat',
                    fontSize: 13,
                    full: true,
                    onTap: () async {
                      final bizName = context.read<AppState>().business.name;
                      final msg =
                          'Book an appointment with $bizName! Browse our services and schedule a time that works for you: $url';
                      await ShareUtils.shareViaWhatsApp(message: msg, context: ctx);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppBtn(
                    'Copy link',
                    icon: 'check',
                    variant: BtnVariant.secondary,
                    fontSize: 13,
                    full: true,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: url));
                      Navigator.pop(ctx);
                      _showSnackBar('Link copied! Share it with your customers.');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Bookings View ─────────────────────────────────────────────────────────

  Widget _buildBookingsView(AppColorsX c) {
    final state = context.watch<AppState>();
    if (state.bookingsLoading && state.bookings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.bookings.isEmpty) {
      return _EmptyBookingState(onCreate: () => _showCreateBooking(context));
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final todayBookings = _filteredBookings
        .where((b) =>
            b.startTime.isAfter(today.subtract(const Duration(hours: 1))) &&
            b.startTime.isBefore(tomorrow))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final upcomingBookings = _filteredBookings
        .where((b) => b.startTime.isAfter(tomorrow))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final pastBookings = _filteredBookings
        .where((b) => b.startTime.isBefore(today.subtract(const Duration(hours: 1))))
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    final pendingCount = _filteredBookings.where((b) => b.status == 'pending').length;
    final todayRevenue = todayBookings.fold<double>(
        0, (sum, b) => sum + (b.price ?? 0));

    return Column(
      children: [
        // ── Stats grid ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Row(
            children: [
              _StatCard(
                label: 'Today',
                value: '${todayBookings.length}',
                sub: todayBookings.isEmpty
                    ? 'No bookings'
                    : todayRevenue > 0 ? 'GHS ${todayRevenue.round()}' : null,
                color: c.teal,
              ),
              const SizedBox(width: 8),
              _StatCard(
                label: 'Upcoming',
                value: '${upcomingBookings.length}',
                sub: upcomingBookings.isEmpty ? 'None scheduled' : null,
                color: c.blue,
              ),
              const SizedBox(width: 8),
              _StatCard(
                label: 'Pending',
                value: '$pendingCount',
                sub: pendingCount > 0 ? 'Needs attention' : null,
                color: c.amber,
              ),
              const SizedBox(width: 8),
              _StatCard(
                label: 'Past',
                value: '${pastBookings.length}',
                sub: pastBookings.length > 0 ? 'Completed' : null,
                color: c.textMuted,
              ),
            ],
          ),
        ),

        // ── Status filter chips ──
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _StatusChip(
                label: 'All',
                active: _statusFilter == 'all',
                onTap: () => setState(() => _statusFilter = 'all'),
                count: state.bookings.length,
              ),
              _StatusChip(
                label: 'Pending',
                active: _statusFilter == 'pending',
                onTap: () => setState(() => _statusFilter = 'pending'),
                count: state.bookings.where((b) => b.status == 'pending').length,
              ),
              _StatusChip(
                label: 'Confirmed',
                active: _statusFilter == 'confirmed',
                onTap: () => setState(() => _statusFilter = 'confirmed'),
                count: state.bookings.where((b) => b.status == 'confirmed').length,
              ),
              _StatusChip(
                label: 'Fulfilled',
                active: _statusFilter == 'fulfilled',
                onTap: () => setState(() => _statusFilter = 'fulfilled'),
                count: state.bookings.where((b) => b.status == 'fulfilled').length,
              ),
              _StatusChip(
                label: 'Cancelled',
                active: _statusFilter == 'cancelled',
                onTap: () => setState(() => _statusFilter = 'cancelled'),
                count: state.bookings.where((b) => b.status == 'cancelled').length,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── Booking list ──
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<AppState>().loadBookings(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                if (todayBookings.isNotEmpty) ..._buildSection(
                    c, 'Today', todayBookings.length, c.teal, todayBookings,
                    isToday: true),
                if (upcomingBookings.isNotEmpty) ..._buildSection(
                    c, 'Upcoming', upcomingBookings.length, c.blue, upcomingBookings),
                if (pastBookings.isNotEmpty) ..._buildSection(
                    c, 'Past', pastBookings.length, c.textFaint, pastBookings),
                if (_filteredBookings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.search_off_outlined,
                              size: 36, color: c.textFaint),
                          const SizedBox(height: 8),
                          Text('No $_statusFilter bookings',
                              style: AppType.body(
                                  size: 14,
                                  weight: FontWeight.w600,
                                  color: c.text)),
                          const SizedBox(height: 4),
                          Text('Try a different filter.',
                              style: AppType.body(
                                  size: 12, color: c.textMuted)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSection(AppColorsX c, String title, int count, Color dotColor,
      List<Booking> bookings, {bool isToday = false}) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppAnimation.fast,
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(title, style: AppType.heading(size: 15, color: c.text)),
            const SizedBox(width: 6),
            Text('($count)',
                style: AppType.body(size: 12, color: c.textMuted)),
          ],
        ),
      ),
      ...bookings.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FadeInSlide(
              index: e.key,
              child: _BookingCard(
                booking: e.value,
                onTap: () => _showBookingDetail(context, e.value),
                compact: !isToday,
              ),
            ),
          )),
      const SizedBox(height: 12),
    ];
  }

  // ── Services View ─────────────────────────────────────────────────────────

  Widget _buildServicesView(AppColorsX c) {
    final state = context.watch<AppState>();
    final services = state.bookingServices;
    if (state.bookingsLoading && state.bookingServices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (services.isEmpty) {
      return _EmptyServicesState(onCreate: () => _showCreateService(context));
    }

    final activeCount = services.where((s) => s.isActive).length;
    final totalRevenue = services.fold<double>(
        0, (sum, s) => sum + (s.price ?? 0));

    return RefreshIndicator(
      onRefresh: () => context.read<AppState>().loadBookings(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          // Services summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.bgElevated,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${services.length} services',
                          style: AppType.heading(size: 16, color: c.text)),
                      const SizedBox(height: 2),
                      Text('$activeCount active · ${services.where((s) => !s.isActive).length} inactive',
                          style: AppType.body(size: 12, color: c.textMuted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.tealSurface,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    'Avg GHS ${services.isEmpty ? 0 : (totalRevenue / services.length).round()}',
                    style: AppType.body(
                        size: 11, weight: FontWeight.w600, color: c.teal)),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showCreateService(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.teal,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('+ Add',
                        style: AppType.body(
                            size: 11, weight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Service cards
          ...services.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FadeInSlide(
                  index: e.key,
                  child: _ServiceCard(
                    service: e.value,
                    onToggle: (active) => _toggleService(e.value, active),
                    onEdit: () => _editService(context, e.value),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  // ── Action handlers ───────────────────────────────────────────────────────

  Future<void> _showCreateBooking(BuildContext context) async {
    final state = context.read<AppState>();
    final bizId = state.business.id;
    if (bizId == null) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateBookingSheet(services: state.bookingServices),
    );
    if (result == true) state.loadBookings();
  }

  Future<void> _showCreateService(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateBookingServiceSheet(),
    );
    if (result == true) context.read<AppState>().loadBookings();
  }

  void _showBookingDetail(BuildContext context, Booking booking) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassSheet(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              _buildDetailHeader(c, booking, ctx),
              const SizedBox(height: 16),

              // ── Details card ──
              _buildDetailInfo(c, booking),
              const SizedBox(height: 14),

              // ── Contact section ──
              if (booking.customerPhone != null || booking.customerEmail != null) ...[
                _buildDetailContact(c, booking, ctx),
                const SizedBox(height: 14),
              ],

              // ── Reminder button ──
              if (booking.status == 'pending' || booking.status == 'confirmed') ...[
                _buildDetailActions(c, booking, ctx),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailHeader(AppColorsX c, Booking booking, BuildContext ctx) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date/time badge
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: c.tealSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${booking.startTime.month}/${booking.startTime.day}',
                  style: AppType.body(
                      size: 11, weight: FontWeight.w700, color: c.teal)),
              Text(_formatTimeShort(booking.startTime),
                  style: AppType.body(size: 9, color: c.teal)),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(booking.customerName,
                  style: AppType.heading(size: 18, color: c.text)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(booking.serviceName,
                        style: AppType.body(size: 13, color: c.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (booking.durationMinutes > 0) ...[
                    const SizedBox(width: 4),
                    Text('· ${booking.durationMinutes} min',
                        style: AppType.body(
                            size: 11, color: c.textFaint)),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        statusPill(booking.statusLabel),
      ],
    );
  }

  Widget _buildDetailInfo(AppColorsX c, Booking booking) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.bgInset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.access_time,
            label: 'Date & time',
            value: _formatDetailDate(booking.startTime),
          ),
          Divider(height: 20, color: c.border),
          _InfoRow(
            icon: Icons.timer_outlined,
            label: 'Duration',
            value: '${booking.durationMinutes} minutes',
          ),
          if (booking.price != null && booking.price! > 0) ...[
            Divider(height: 20, color: c.border),
            _InfoRow(
              icon: Icons.payments_outlined,
              label: 'Price',
              value: 'GHS ${booking.price!.round()}',
              valueColor: c.teal,
            ),
          ],
          if (booking.notes != null && booking.notes!.isNotEmpty) ...[
            Divider(height: 20, color: c.border),
            _InfoRow(
              icon: Icons.notes_outlined,
              label: 'Notes',
              value: booking.notes!,
            ),
          ],
          // Status timeline
          Divider(height: 20, color: c.border),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: c.textFaint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  booking.status == 'fulfilled'
                      ? 'This booking has been fulfilled'
                      : booking.status == 'cancelled'
                          ? 'This booking was cancelled'
                          : booking.status == 'confirmed'
                              ? 'Confirmed — waiting to be fulfilled'
                              : 'Pending — needs your confirmation',
                  style: AppType.body(size: 11.5, color: c.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailContact(
      AppColorsX c, Booking booking, BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Contact information',
            style: AppType.heading(size: 14, color: c.text)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.bgInset,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              if (booking.customerPhone != null)
                _ContactAction(
                  icon: Icons.phone_outlined,
                  label: booking.customerPhone!,
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: booking.customerPhone!));
                    _showSnackBar('Phone copied: ${booking.customerPhone}');
                  },
                ),
              if (booking.customerPhone != null &&
                  booking.customerEmail != null)
                Divider(height: 16, color: c.border),
              if (booking.customerEmail != null)
                _ContactAction(
                  icon: Icons.email_outlined,
                  label: booking.customerEmail!,
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: booking.customerEmail!));
                    _showSnackBar('Email copied: ${booking.customerEmail}');
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailActions(
      AppColorsX c, Booking booking, BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Actions', style: AppType.heading(size: 14, color: c.text)),
        const SizedBox(height: 8),
        // WhatsApp reminder
        AppBtn(
          'Send WhatsApp reminder',
          icon: 'chat',
          variant: BtnVariant.secondary,
          full: true,
          fontSize: 13,
          onTap: () {
            final reminder = _buildReminder(booking);
            Clipboard.setData(ClipboardData(text: reminder));
            Navigator.pop(ctx);
            _showSnackBar('Reminder copied! Paste it into WhatsApp to send.');
          },
        ),
        const SizedBox(height: 10),        // Status actions
              Row(
                children: [
                  if (booking.status == 'pending')
                    Expanded(
                      child: AppBtn('Confirm', onTap: () async {
                        await svc.BookingService.updateBookingStatus(
                          bookingId: booking.id,
                          businessId: booking.businessId,
                          status: 'confirmed',
                        );
                        unawaited(_logBookingInteraction(
                          bizId: booking.businessId,
                          customerName: booking.customerName,
                          customerPhone: booking.customerPhone,
                          serviceName: booking.serviceName,
                          action: 'confirmed',
                        ));
                        if (ctx.mounted) Navigator.pop(ctx);
                        context.read<AppState>().loadBookings();
                      }),
                    ),
                  if (booking.status == 'pending' || booking.status == 'confirmed') ...[
                    if (booking.status == 'pending') const SizedBox(width: 10),
                    Expanded(
                      child: AppBtn(
                        booking.status == 'confirmed' ? 'Fulfil' : 'Cancel',
                        variant: BtnVariant.outline,
                        onTap: () async {
                          final newStatus =
                              booking.status == 'confirmed' ? 'fulfilled' : 'cancelled';
                          await svc.BookingService.updateBookingStatus(
                            bookingId: booking.id,
                            businessId: booking.businessId,
                            status: newStatus,
                          );
                          unawaited(_logBookingInteraction(
                            bizId: booking.businessId,
                            customerName: booking.customerName,
                            customerPhone: booking.customerPhone,
                            serviceName: booking.serviceName,
                            action: newStatus,
                          ));
                          if (ctx.mounted) Navigator.pop(ctx);
                          context.read<AppState>().loadBookings();
                        },
                      ),
                    ),
                  ],
                ],
              ),
      ],
    );
  }

  String _buildReminder(Booking booking) {
    final dt = booking.startTime;
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    final dateStr = '${dt.month}/${dt.day} at $h:$min $amPm';
    return 'Hi ${booking.customerName}! Just a reminder about your ${booking.serviceName} appointment on $dateStr. See you there! - AscendSME';
  }

  String _formatTimeShort(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h$amPm';
  }

  String _formatDetailDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $h:$min $amPm';
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: AppType.body(size: 13, color: Colors.white)),
        backgroundColor: context.colors.navyDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleService(BookingService service, bool active) async {
    final bizId = context.read<AppState>().business.id;
    if (bizId == null) return;
    await svc.BookingService.updateService(
      serviceId: service.id,
      businessId: bizId,
      isActive: active,
    );
    context.read<AppState>().loadBookings();
  }

  void _editService(BuildContext context, BookingService service) {
    final c = context.colors;
    final nameCtrl = TextEditingController(text: service.name);
    final descCtrl = TextEditingController(text: service.description ?? '');
    final priceCtrl =
        TextEditingController(text: service.price?.toStringAsFixed(0) ?? '');
    final durCtrl =
        TextEditingController(text: service.durationMinutes.toString());
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassSheet(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Edit service',
                          style: AppType.heading(size: 18, color: c.text)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c.bgInset,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.close, size: 16, color: c.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Name',
                    style: AppType.body(
                        size: 12, weight: FontWeight.w600, color: c.textMuted)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: nameCtrl,
                  style: AppType.body(size: 14, color: c.text),
                  decoration: _inputDeco(c, 'Service name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Text('Description (optional)',
                    style: AppType.body(
                        size: 12, weight: FontWeight.w600, color: c.textMuted)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: descCtrl,
                  style: AppType.body(size: 14, color: c.text),
                  decoration: _inputDeco(c, 'Brief description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Price (GHS)',
                              style: AppType.body(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: c.textMuted)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: priceCtrl,
                            style: AppType.body(size: 14, color: c.text),
                            decoration: _inputDeco(c, '0'),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Duration (min)',
                              style: AppType.body(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: c.textMuted)),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: durCtrl,
                            style: AppType.body(size: 14, color: c.text),
                            decoration: _inputDeco(c, '60'),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              return (n == null || n < 5) ? 'Min 5' : null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AppBtn(
                        'Save changes',
                        fontSize: 13,
                        full: true,
                        onTap: () async {
                          if (!formKey.currentState!.validate()) return;
                          final bizId = context.read<AppState>().business.id;
                          if (bizId == null) return;
                          await svc.BookingService.updateService(
                            serviceId: service.id,
                            businessId: bizId,
                            name: nameCtrl.text.trim(),
                            description: descCtrl.text.trim(),
                            price: double.tryParse(priceCtrl.text),
                            durationMinutes: int.tryParse(durCtrl.text),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          context.read<AppState>().loadBookings();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppBtn(
                        'Delete',
                        variant: BtnVariant.ghost,
                        full: true,
                        fontSize: 13,
                        onTap: () async {
                          final bizId = context.read<AppState>().business.id;
                          if (bizId == null) return;
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              backgroundColor: c.bgElevated,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              title: Text('Delete service?',
                                  style: AppType.heading(
                                      size: 17, color: c.text)),
                              content: Text(
                                  'Remove ${service.name}? This cannot be undone.',
                                  style: AppType.body(
                                      size: 13, color: c.textMuted)),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dCtx, false),
                                  child: Text('Keep',
                                      style: AppType.body(
                                          size: 13,
                                          weight: FontWeight.w600,
                                          color: c.textMuted)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  child: Text('Delete',
                                      style: AppType.body(
                                          size: 13,
                                          weight: FontWeight.w600,
                                          color: c.rose)),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                          await svc.BookingService.deleteService(
                              serviceId: service.id, businessId: bizId);
                          if (ctx.mounted) Navigator.pop(ctx);
                          context.read<AppState>().loadBookings();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(AppColorsX c, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: AppType.body(size: 14, color: c.textFaint),
        filled: true,
        fillColor: c.bgInset,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.rose),
        ),
      );

  /// Log a CRM interaction when a booking status changes.
  Future<void> _logBookingInteraction({
    required String bizId,
    required String customerName,
    String? customerPhone,
    required String serviceName,
    required String action,
  }) async {
    final label = switch (action) {
      'confirmed' => 'confirmed',
      'fulfilled' => 'fulfilled',
      'cancelled' => 'cancelled',
      _ => 'updated',
    };
    final profile = await CrmService.getOrCreateCrmProfile(
      businessId: bizId,
      name: customerName,
      phone: customerPhone,
    );
    if (profile != null) {
      unawaited(CrmService.addInteraction(
        businessId: bizId,
        customerProfileId: profile['id'] as String,
        type: 'booking',
        description: 'Booking $label — $serviceName',
      ));
    }
  }
}

// ── View Toggle ─────────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ViewToggle(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimation.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.tealSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? c.teal.withValues(alpha: 0.3) : c.border),
        ),
        child: Text(label,
            style: AppType.body(
                size: 13,
                weight: FontWeight.w600,
                color: active ? c.teal : c.textMuted)),
      ),
    );
  }
}

// ── Stat Card ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final String? sub;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            Text(value,
                style: AppType.heading(size: 20, color: color)),
            const SizedBox(height: 1),
            Text(label,
                style: AppType.label(size: 9, color: c.textMuted)),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(size: 8, color: c.textFaint)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Status Chip ─────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final bool active;
  final int count;
  final VoidCallback onTap;
  const _StatusChip({
    required this.label,
    required this.active,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? c.navy : c.bgInset,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? c.navy : c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: AppType.body(
                      size: 12,
                      weight: FontWeight.w600,
                      color: active ? Colors.white : c.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: 0.2)
                        : c.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('$count',
                      style: AppType.label(
                          size: 9,
                          color: active ? Colors.white : c.textFaint)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Booking Card ────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;
  final bool compact;

  const _BookingCard({
    required this.booking,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final h = booking.startTime.hour > 12
        ? booking.startTime.hour - 12
        : (booking.startTime.hour == 0 ? 12 : booking.startTime.hour);
    final amPm = booking.startTime.hour >= 12 ? 'PM' : 'AM';
    final min = booking.startTime.minute.toString().padLeft(2, '0');
    final timeStr = '$h:$min $amPm';

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Time badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.tealSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${booking.startTime.month}/${booking.startTime.day}',
                    style: AppType.body(
                        size: 10, weight: FontWeight.w700, color: c.teal)),
                Text(timeStr,
                    style: AppType.body(size: 9, color: c.teal)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.customerName,
                    style: AppType.body(
                        size: 13.5, weight: FontWeight.w600, color: c.text)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(booking.serviceName,
                          style: AppType.body(size: 11.5, color: c.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (booking.price != null && booking.price! > 0) ...[
                      const SizedBox(width: 4),
                      Text('· GHS ${booking.price!.round()}',
                          style: AppType.body(
                              size: 11,
                              weight: FontWeight.w600,
                              color: c.teal)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          statusPill(booking.statusLabel),
        ],
      ),
    );
  }
}

// ── Status Pill ─────────────────────────────────────────────────────────────

Widget statusPill(String label) {
  return Builder(builder: (context) {
    final c = context.colors;
    final (bg, fg) = switch (label.toLowerCase()) {
      'confirmed' => (c.greenSurface, c.green),
      'cancelled' => (c.roseSurface, c.rose),
      'fulfilled' => (c.tealSurface, c.tealDeep),
      _ => (c.amberSurface, c.amber),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label,
          style: AppType.body(
              size: 10.5, weight: FontWeight.w600, color: fg)),
    );
  });
}

// ── Service Card ────────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final BookingService service;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  const _ServiceCard(
      {required this.service,
      required this.onToggle,
      required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: onEdit,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.tealSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: AppIcon('sparkles', size: 18, color: c.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name,
                    style: AppType.body(
                        size: 13.5, weight: FontWeight.w600, color: c.text)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: c.bgInsetStrong,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('${service.durationMinutes} min',
                          style: AppType.body(
                              size: 10, color: c.textMuted)),
                    ),    if (service.price != null) ...[
      SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          color: c.tealSurface,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('GHS ${service.price!.round()}',
            style: AppType.body(
                size: 10,
                weight: FontWeight.w600,
                color: c.teal)),
      ),
    ],
                    if (!service.isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: c.roseSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Inactive',
                            style: AppType.body(
                                size: 10,
                                weight: FontWeight.w500,
                                color: c.rose)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Active toggle
          Switch(
            value: service.isActive,
            onChanged: onToggle,
            activeThumbColor: c.teal,
          ),
        ],
      ),
    );
  }
}

// ── Contact Action ─────────────────────────────────────────────────────────

class _ContactAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ContactAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.tealSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: c.teal),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppType.body(
                        size: 12.5, weight: FontWeight.w600, color: c.text)),
                Text('Tap to copy',
                    style: AppType.body(size: 10, color: c.textFaint)),
              ],
            ),
          ),
          Icon(Icons.copy_rounded, size: 14, color: c.textFaint),
        ],
      ),
    );
  }
}

// ── Info Row ────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: c.textFaint),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(label,
              style: AppType.body(size: 12, color: c.textMuted)),
        ),
        Expanded(
          child: Text(value,
              style: AppType.body(
                  size: 13,
                  weight: FontWeight.w500,
                  color: valueColor ?? c.text)),
        ),
      ],
    );
  }
}

// ── Empty States ───────────────────────────────────────────────────────────

class _EmptyBookingState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyBookingState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.tealSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child:
                  Icon(Icons.calendar_today_outlined, size: 32, color: c.teal),
            ),
            const SizedBox(height: 20),
            Text('No bookings yet',
                style: AppType.heading(size: 18, color: c.text)),
            const SizedBox(height: 8),
            Text(
              'Create your first booking to start managing appointments. Customers can also book directly through your portal link.',
              textAlign: TextAlign.center,
              style: AppType.body(size: 13, color: c.textMuted),
            ),
            const SizedBox(height: 24),
            AppBtn('New Booking', icon: 'add', onTap: onCreate),
          ],
        ),
      ),
    );
  }
}

class _EmptyServicesState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyServicesState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.tealSurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: AppIcon('sparkles', size: 32, color: c.teal),
            ),
            const SizedBox(height: 20),
            Text('No services yet',
                style: AppType.heading(size: 18, color: c.text)),
            const SizedBox(height: 8),
            Text(
              'Add the services you offer so customers can book them through your portal.',
              textAlign: TextAlign.center,
              style: AppType.body(size: 13, color: c.textMuted),
            ),
            const SizedBox(height: 24),
            AppBtn('Add Service', icon: 'add', onTap: onCreate),
          ],
        ),
      ),
    );
  }
}
