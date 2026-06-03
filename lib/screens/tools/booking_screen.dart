import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        .where((b) =>
            b.startTime.isBefore(today.subtract(const Duration(hours: 1))))
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    return Column(
      children: [
        // Stats summary row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              _BookingStat(
                  label: 'Today',
                  value: '${todayBookings.length}',
                  color: c.teal),
              const SizedBox(width: 8),
              _BookingStat(
                  label: 'Upcoming',
                  value: '${upcomingBookings.length}',
                  color: c.blue),
              const SizedBox(width: 8),
              _BookingStat(
                  label: 'Past',
                  value: '${pastBookings.length}',
                  color: c.textMuted),
            ],
          ),
        ),
        // Status filter chips
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _StatusChip(label: 'All', active: _statusFilter == 'all', onTap: () => setState(() => _statusFilter = 'all'), count: _bookings.length),
              _StatusChip(label: 'Pending', active: _statusFilter == 'pending', onTap: () => setState(() => _statusFilter = 'pending'), count: _bookings.where((b) => b.status == 'pending').length),
              _StatusChip(label: 'Confirmed', active: _statusFilter == 'confirmed', onTap: () => setState(() => _statusFilter = 'confirmed'), count: _bookings.where((b) => b.status == 'confirmed').length),
              _StatusChip(label: 'Fulfilled', active: _statusFilter == 'fulfilled', onTap: () => setState(() => _statusFilter = 'fulfilled'), count: _bookings.where((b) => b.status == 'fulfilled').length),
              _StatusChip(label: 'Cancelled', active: _statusFilter == 'cancelled', onTap: () => setState(() => _statusFilter = 'cancelled'), count: _bookings.where((b) => b.status == 'cancelled').length),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                // Today section
                if (todayBookings.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: c.teal,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Today',
                            style: AppType.heading(size: 15, color: c.text)),
                        const SizedBox(width: 6),
                        Text('(${todayBookings.length})',
                            style: AppType.body(size: 12, color: c.textMuted)),
                      ],
                    ),
                  ),
                  ...todayBookings.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FadeInSlide(
                          index: e.key,
                          child: _BookingCard(
                            booking: e.value,
                            onTap: () => _showBookingDetail(context, e.value),
                          ),
                        ),
                      )),
                  const SizedBox(height: 12),
                ],
                // Upcoming section
                if (upcomingBookings.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: c.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Upcoming',
                            style: AppType.heading(size: 15, color: c.text)),
                        const SizedBox(width: 6),
                        Text('(${upcomingBookings.length})',
                            style: AppType.body(size: 12, color: c.textMuted)),
                      ],
                    ),
                  ),
                  ...upcomingBookings.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FadeInSlide(
                          index: e.key,
                          child: _BookingCard(
                            booking: e.value,
                            onTap: () => _showBookingDetail(context, e.value),
                          ),
                        ),
                      )),
                  const SizedBox(height: 12),
                ],
                // Past section
                if (pastBookings.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: c.textFaint,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Past',
                            style: AppType.heading(size: 15, color: c.text)),
                        const SizedBox(width: 6),
                        Text('(${pastBookings.length})',
                            style: AppType.body(size: 12, color: c.textMuted)),
                      ],
                    ),
                  ),
                  ...pastBookings.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FadeInSlide(
                          index: e.key,
                          child: _BookingCard(
                            booking: e.value,
                            onTap: () => _showBookingDetail(context, e.value),
                          ),
                        ),
                      )),
                ],
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

    final activeCount = _services.where((s) => s.isActive).length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Row(
            children: [
              Text('${_services.length} ${_services.length == 1 ? 'service' : 'services'}',
                  style: AppType.body(size: 12.5, color: c.textMuted)),
              Text(' · $activeCount active',
                  style: AppType.body(size: 12, color: c.green)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showCreateService(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.tealSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('+ Add',
                      style: AppType.body(size: 12, weight: FontWeight.w600, color: c.teal)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._services.asMap().entries.map((e) => Padding(
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
              // ── Header ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: c.tealSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${booking.startTime.month}/${booking.startTime.day}',
                            style: AppType.body(size: 11, weight: FontWeight.w700, color: c.teal)),
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
                        Text(booking.serviceName,
                            style: AppType.body(size: 13, color: c.textMuted)),
                      ],
                    ),
                  ),
                  _StatusPill(booking.statusLabel),
                ],
              ),
              const SizedBox(height: 16),

              // ── Details card ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.bgInset,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _DetailRow(icon: Icons.access_time,
                        label: '${_formatTime(booking.startTime)} (${booking.durationMinutes} min)'),
                    if (booking.price != null) ...[
                      const SizedBox(height: 8),
                      _DetailRow(icon: Icons.payments_outlined,
                          label: 'GHS ${booking.price!.round()}'),
                    ],
                    if (booking.notes != null && booking.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _DetailRow(icon: Icons.notes_outlined,
                          label: booking.notes!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Contact section ──
              if (booking.customerPhone != null ||
                  booking.customerEmail != null) ...[
                Text('Customer contact',
                    style: AppType.heading(size: 14, color: c.text)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.bgInset,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      if (booking.customerPhone != null)
                        _ContactAction(
                          icon: Icons.phone_outlined,
                          label: booking.customerPhone!,
                          hint: 'Tap to copy',
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: booking.customerPhone!));
                            _showSnackBar('Phone copied: ${booking.customerPhone}');
                          },
                        ),
                      if (booking.customerPhone != null &&
                          booking.customerEmail != null)
                        const SizedBox(height: 6),
                      if (booking.customerEmail != null)
                        _ContactAction(
                          icon: Icons.email_outlined,
                          label: booking.customerEmail!,
                          hint: 'Tap to copy',
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: booking.customerEmail!));
                            _showSnackBar('Email copied: ${booking.customerEmail}');
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── WhatsApp reminder ──
              if (booking.status == 'pending' || booking.status == 'confirmed')
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
                    _showSnackBar('Reminder copied! Paste it in WhatsApp to send.');
                  },
                ),

              const SizedBox(height: 12),

              // ── Status actions ──
              if (booking.status == 'pending' || booking.status == 'confirmed') ...[
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

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppType.body(size: 13, color: Colors.white)),
        backgroundColor: context.colors.navyDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    _loadData();
  }

  void _editService(BuildContext context, BookingService service) {
    final c = context.colors;
    final nameCtrl = TextEditingController(text: service.name);
    final descCtrl = TextEditingController(text: service.description ?? '');
    final priceCtrl = TextEditingController(
        text: service.price?.toStringAsFixed(0) ?? '');
    final durCtrl = TextEditingController(
        text: service.durationMinutes.toString());
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassSheet(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text('Edit service',
                          style: AppType.heading(size: 18, color: c.text)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 32, height: 32,
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

                // Name
                Text('Name',
                    style: AppType.body(size: 12, weight: FontWeight.w600, color: c.textMuted)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: nameCtrl,
                  style: AppType.body(size: 14, color: c.text),
                  decoration: _inputDeco(c, 'Service name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Description
                Text('Description (optional)',
                    style: AppType.body(size: 12, weight: FontWeight.w600, color: c.textMuted)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: descCtrl,
                  style: AppType.body(size: 14, color: c.text),
                  decoration: _inputDeco(c, 'Brief description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // Price + duration row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Price (GHS)',
                              style: AppType.body(size: 12, weight: FontWeight.w600, color: c.textMuted)),
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
                              style: AppType.body(size: 12, weight: FontWeight.w600, color: c.textMuted)),
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

                // Actions
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
                          _loadData();
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Text('Delete service?',
                                  style: AppType.heading(size: 17, color: c.text)),
                              content: Text('Remove ${service.name}? This cannot be undone.',
                                  style: AppType.body(size: 13, color: c.textMuted)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx, false),
                                  child: Text('Keep', style: AppType.body(size: 13, weight: FontWeight.w600, color: c.textMuted)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  child: Text('Delete', style: AppType.body(size: 13, weight: FontWeight.w600, color: c.rose)),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                          await svc.BookingService.deleteService(
                              serviceId: service.id, businessId: bizId);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadData();
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      color: active ? Colors.white : c.textMuted)),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: active ? Colors.white.withValues(alpha: 0.2) : c.border,
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

// ── Booking stat ─────────────────────────────────────────────────────────────

class _BookingStat extends StatelessWidget {
  final String label, value;
  final Color color;

  const _BookingStat({
    required this.label,
    required this.value,
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
                style: AppType.heading(size: 18, color: color)),
            const SizedBox(height: 1),
            Text(label,
                style: AppType.label(size: 10, color: c.textMuted)),
          ],
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

// ── Contact action row ───────────────────────────────────────────────────────

class _ContactAction extends StatelessWidget {
  final IconData icon;
  final String label, hint;
  final VoidCallback onTap;

  const _ContactAction({
    required this.icon,
    required this.label,
    required this.hint,
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
            width: 32, height: 32,
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
                    style: AppType.body(size: 12.5, weight: FontWeight.w600, color: c.text)),
                Text(hint,
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
