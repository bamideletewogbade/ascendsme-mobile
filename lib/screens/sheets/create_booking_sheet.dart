import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart' as models;
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/customer_selector.dart';
import '../../services/booking_service.dart' as svc;
import '../../services/crm_service.dart';
import '../../state/app_state.dart';

/// Bottom sheet to create a new booking/appointment.
/// Features customer selector with typeahead, auto-fill on selection,
/// and inline customer creation.
class CreateBookingSheet extends StatefulWidget {
  final List<models.BookingService> services;
  const CreateBookingSheet({super.key, required this.services});

  @override
  State<CreateBookingSheet> createState() => _CreateBookingSheetState();
}

class _CreateBookingSheetState extends State<CreateBookingSheet> {
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  models.BookingService? _selectedService;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _saving = false;

  // Customer selector state
  String _customerName = '';
  models.Customer? _selectedCustomer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onCustomerChanged(String name, models.Customer? customer) {
    setState(() {
      _customerName = name;
      _selectedCustomer = customer;
      // Auto-fill phone and email when a customer is selected
      if (customer != null) {
        _phoneCtrl.text = customer.phone ?? '';
        _emailCtrl.text = customer.email ?? '';
      }
    });
  }

  Future<void> _save() async {
    if (_customerName.isEmpty) return;

    setState(() => _saving = true);
    final bizId = context.read<AppState>().business.id;
    if (bizId == null) return;

    final startTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final result = await svc.BookingService.createBooking(
      businessId: bizId,
      serviceName: _selectedService?.name ?? 'General',
      serviceId: _selectedService?.id,
      customerName: _customerName,
      customerPhone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
      customerEmail: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
      startTime: startTime,
      durationMinutes: _selectedService?.durationMinutes ?? 60,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      price: _selectedService?.price,
    );

    // Log CRM interaction for the booking
    if (result != null) {
      unawaited(_logCrmInteraction(bizId));
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, result != null);
  }

  Future<void> _logCrmInteraction(String bizId) async {
    final profile = await CrmService.getOrCreateCrmProfile(
      businessId: bizId,
      name: _customerName,
      phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
      email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
    );
    if (profile != null) {
      final svcName = _selectedService?.name ?? 'General';
      await CrmService.addInteraction(
        businessId: bizId,
        customerProfileId: profile['id'] as String,
        type: 'booking',
        description: 'Booking created for $svcName',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.read<AppState>();
    final bizId = state.business.id;

    return GlassSheet(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Text('New Booking',
                  style: AppType.heading(size: 18, color: c.text)),
              const SizedBox(height: 16),

              // ── Service selection ──
              Text('Service',
                  style: AppType.body(
                      size: 11.5, weight: FontWeight.w600, color: c.textMuted)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: c.bgInset,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<models.BookingService>(
                    value: _selectedService,
                    isExpanded: true,
                    hint: Text('Select service (optional)',
                        style: AppType.body(size: 13, color: c.textFaint)),
                    items: widget.services
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.name,
                                  style: AppType.body(size: 13, color: c.text)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedService = v),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Customer selector with typeahead ──
              CustomerSelector(
                businessId: bizId,
                recentCustomers: state.customers,
                initialName: _customerName,
                initialCustomer: _selectedCustomer,
                onChanged: _onCustomerChanged,
                label: 'Customer',
              ),
              const SizedBox(height: 14),

              // ── Phone ──
              AppInput(
                label: 'Phone (optional)',
                controller: _phoneCtrl,
                icon: Icons.phone_outlined,
                hint: 'Customer phone number',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),

              // ── Email (new field) ──
              AppInput(
                label: 'Email (optional)',
                controller: _emailCtrl,
                icon: Icons.email_outlined,
                hint: 'customer@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),

              // ── Date & Time ──
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date',
                            style: AppType.body(
                                size: 11.5,
                                weight: FontWeight.w600,
                                color: c.textMuted)),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 90)),
                            );
                            if (d != null) setState(() => _selectedDate = d);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: c.bgInset,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: c.border),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 15, color: c.textFaint),
                                const SizedBox(width: 8),
                                Text(
                                    '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                                    style: AppType.body(
                                        size: 13, color: c.text)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Time',
                            style: AppType.body(
                                size: 11.5,
                                weight: FontWeight.w600,
                                color: c.textMuted)),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: _selectedTime,
                            );
                            if (t != null) setState(() => _selectedTime = t);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: c.bgInset,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: c.border),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time,
                                    size: 15, color: c.textFaint),
                                const SizedBox(width: 8),
                                Text(_selectedTime.format(context),
                                    style: AppType.body(
                                        size: 13, color: c.text)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Notes ──
              AppInput(
                label: 'Notes (optional)',
                controller: _notesCtrl,
                icon: Icons.notes_outlined,
                hint: 'Any special notes',
              ),
              const SizedBox(height: 20),

              AppBtn('Create Booking',
                  full: true, onTap: _saving ? null : _save),
            ],
          ),
      ),
    );
  }
}
