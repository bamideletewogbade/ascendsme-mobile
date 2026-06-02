import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/booking_service.dart' as svc;
import '../../state/app_state.dart';
import '../sheets/create_booking_sheet.dart';
import '../sheets/create_booking_service_sheet.dart';

/// Booking screen — manages appointments and booking services.
/// Shows a segmented control between [Services] and [Bookings] views.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String _view = 'bookings'; // 'bookings' | 'services'
  String _statusFilter = 'all';
  bool _loaded = false;

  List<Booking> _bookings = [];
  List<BookingService> _services = [];
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _loadData();
  }

  Future<void> _loadData() async {
    final bizId = context.read<AppState>().business.id;
    if (bizId == null) return;
    setState(() => _loading = true);

    final results = await Future.wait([
      svc.BookingService.fetchBookings(businessId: bizId),
      svc.BookingService.fetchServices(businessId: bizId),
    ]);

    if (!mounted) return;
    setState(() {
      _bookings = (results[0] as List).map((r) => Booking.fromRow(r as Map<String, dynamic>)).toList();
      _services = (results[1] as List).map((r) => BookingService.fromRow(r as Map<String, dynamic>)).toList();
      _loading = false;
    });
  }

  List<Booking> get _filteredBookings {
    if (_statusFilter == 'all') return _bookings;
    return _bookings.where((b) => b.status == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader(
              'Bookings',
              onBack: () => Navigator.pop(context),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
            ),
            // View toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _ViewToggle(label: 'Bookings', active: _view == 'bookings', onTap: () => setState(() => _view = 'bookings')),
                  const SizedBox(width: 8),
                  _ViewToggle(label: 'Services', active: _view == 'services', onTap: () => setState(() => _view = 'services')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _view == 'bookings' ? _buildBookingsView(c) : _buildServicesView(c),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsView(AppColorsX c) {
    if (_bookings.isEmpty) {
      return _EmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'No bookings yet',
        subtitle: 'Create your first booking to start managing appointments.',
        actionLabel: 'New Booking',
        onAction: () => _showCreateBooking(context),
      );
    }

    return Column(
      children: [
        // Status filter chips
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _StatusChip(label: 'All', active: _statusFilter == 'all', onTap: () => setState(() => _statusFilter = 'all')),
              _StatusChip(label: 'Pending', active: _statusFilter == 'pending', onTap: () => setState(() => _statusFilter = 'pending')),
              _StatusChip(label: 'Confirmed', active: _statusFilter == 'confirmed', onTap: () => setState(() => _statusFilter = 'confirmed')),
              _StatusChip(label: 'Fulfilled', active: _statusFilter == 'fulfilled', onTap: () => setState(() => _statusFilter = 'fulfilled')),
              _StatusChip(label: 'Cancelled', active: _statusFilter == 'cancelled', onTap: () => setState(() => _statusFilter = 'cancelled')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              // Summary
              if (_filteredBookings.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${_filteredBookings.length} ${_filteredBookings.length == 1 ? 'booking' : 'bookings'}',
                    style: AppType.body(size: 12.5, color: c.textMuted),
                  ),
                ),
              ..._filteredBookings.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BookingCard(
                      booking: b,
                      onTap: () => _showBookingDetail(context, b),
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServicesView(AppColorsX c) {
    if (_services.isEmpty) {
      return _EmptyState(
        icon: Icons.miscellaneous_services_outlined,
        title: 'No services yet',
        subtitle: 'Add the services you offer so customers can book them.',
        actionLabel: 'Add Service',
        onAction: () => _showCreateService(context),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Row(
          children: [
            Text('${_services.length} ${_services.length == 1 ? 'service' : 'services'}',
                style: AppType.body(size: 12.5, color: c.textMuted)),
            const Spacer(),
            GestureDetector(
              onTap: () => _showCreateService(context),
              child: Text('+ Add',
                  style: AppType.body(size: 13, weight: FontWeight.w600, color: c.teal)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._services.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ServiceCard(
                service: s,
                onToggle: (active) => _toggleService(s, active),
                onEdit: () => _editService(context, s),
              ),
            )),
      ],
    );
  }

  Future<void> _showCreateBooking(BuildContext context) async {
    final bizId = context.read<AppState>().business.id;
    if (bizId == null) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateBookingSheet(services: _services),
    );
    if (result == true) _loadData();
  }

  Future<void> _showCreateService(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateBookingServiceSheet(),
    );
    if (result == true) _loadData();
  }

  void _showBookingDetail(BuildContext context, Booking booking) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassSheet(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(booking.customerName,
                        style: AppType.heading(size: 18, color: c.text)),
                  ),
                  _StatusPill(booking.statusLabel),
                ],
              ),
              const SizedBox(height: 12),
              _DetailRow(icon: Icons.miscellaneous_services_outlined, label: booking.serviceName),
              _DetailRow(icon: Icons.access_time,
                  label: '${_formatTime(booking.startTime)} (${booking.durationMinutes} min)'),
              if (booking.customerPhone != null)
                _DetailRow(icon: Icons.phone_outlined, label: booking.customerPhone!),
              if (booking.customerEmail != null)
                _DetailRow(icon: Icons.email_outlined, label: booking.customerEmail!),
              if (booking.notes != null)
                _DetailRow(icon: Icons.notes_outlined, label: booking.notes!),
              if (booking.price != null)
                _DetailRow(icon: Icons.payments_outlined, label: 'GHS ${booking.price!.round()}'),
              if (booking.status == 'pending' || booking.status == 'confirmed') ...[
                const SizedBox(height: 20),
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
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadData();
                        }),
                      ),
                    if (booking.status == 'pending' || booking.status == 'confirmed') ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppBtn(
                          booking.status == 'confirmed' ? 'Fulfil' : 'Cancel',
                          variant: BtnVariant.outline,
                          onTap: () async {
                            final newStatus = booking.status == 'confirmed' ? 'fulfilled' : 'cancelled';
                            await svc.BookingService.updateBookingStatus(
                              bookingId: booking.id,
                              businessId: booking.businessId,
                              status: newStatus,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadData();
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
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
    _loadData();
  }

  void _editService(BuildContext context, BookingService service) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassSheet(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(service.name,
                  style: AppType.heading(size: 18, color: c.text)),
              const SizedBox(height: 16),
              if (service.description != null)
                Text(service.description!,
                    style: AppType.body(size: 13, color: c.textMuted)),
              const SizedBox(height: 4),
              if (service.price != null)
                Text('GHS ${service.price!.round()} · ${service.durationMinutes} min',
                    style: AppType.body(size: 13, weight: FontWeight.w600, color: c.text)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: AppBtn(
                      'Delete',
                      variant: BtnVariant.outline,
                      onTap: () async {
                        final bizId = context.read<AppState>().business.id;
                        if (bizId == null) return;
                        await svc.BookingService.deleteService(serviceId: service.id, businessId: bizId);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadData();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day} · $h:$min $amPm';
  }
}

// ── View Toggle ─────────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ViewToggle({required this.label, required this.active, required this.onTap});

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
          border: Border.all(color: active ? c.teal.withValues(alpha: 0.3) : c.border),
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

// ── Status Chip ──────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _StatusChip({required this.label, required this.active, required this.onTap});

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
          child: Text(label,
              style: AppType.body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: active ? Colors.white : c.textMuted)),
        ),
      ),
    );
  }
}

// ── Booking Card ────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;
  const _BookingCard({required this.booking, required this.onTap});

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
                    style: AppType.body(size: 10, weight: FontWeight.w700, color: c.teal)),
                Text(timeStr,
                    style: AppType.body(size: 9, color: c.teal)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.customerName,
                    style: AppType.body(size: 13.5, weight: FontWeight.w600, color: c.text)),
                const SizedBox(height: 2),
                Text(booking.serviceName,
                    style: AppType.body(size: 12, color: c.textMuted)),
              ],
            ),
          ),
          _StatusPill(booking.statusLabel),
        ],
      ),
    );
  }
}

Widget _StatusPill(String label) {
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label,
          style: AppType.body(size: 10.5, weight: FontWeight.w600, color: fg)),
    );
  });
}

// ── Service Card ────────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final BookingService service;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  const _ServiceCard({required this.service, required this.onToggle, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: onEdit,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
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
                    style: AppType.body(size: 13.5, weight: FontWeight.w600, color: c.text)),
                const SizedBox(height: 2),
                Text(
                  '${service.durationMinutes} min${service.price != null ? ' · GHS ${service.price!.round()}' : ''}',
                  style: AppType.body(size: 11.5, color: c.textMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: service.isActive,
            onChanged: onToggle,
            activeColor: c.teal,
          ),
        ],
      ),
    );
  }
}

// ── Detail Row ──────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DetailRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: c.textFaint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: AppType.body(size: 13, color: c.text)),
          ),
        ],
      ),
    );
  }
}

// ── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle, actionLabel;
  final VoidCallback onAction;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: c.textFaint),
            const SizedBox(height: 16),
            Text(title, style: AppType.heading(size: 17, color: c.text)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: AppType.body(size: 13, color: c.textMuted)),
            const SizedBox(height: 20),
            AppBtn(actionLabel, onTap: onAction),
          ],
        ),
      ),
    );
  }
}
