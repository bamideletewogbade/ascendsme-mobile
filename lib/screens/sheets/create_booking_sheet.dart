import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart' as models;
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/booking_service.dart' as svc;
import '../../state/app_state.dart';

/// Bottom sheet to create a new booking/appointment.
class CreateBookingSheet extends StatefulWidget {
  final List<models.BookingService> services;
  const CreateBookingSheet({super.key, required this.services});

  @override
  State<CreateBookingSheet> createState() => _CreateBookingSheetState();
}

class _CreateBookingSheetState extends State<CreateBookingSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  models.BookingService? _selectedService;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

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
      customerName: name,
      customerPhone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
      startTime: startTime,
      durationMinutes: _selectedService?.durationMinutes ?? 60,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      price: _selectedService?.price,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context, result != null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassSheet(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Booking',
                style: AppType.heading(size: 18, color: c.text)),
            const SizedBox(height: 16),

            // Service selection
            Text('Service',
                style: AppType.body(size: 11.5, weight: FontWeight.w600, color: c.textMuted)),
            const SizedBox(height: 6),
            DropdownButtonFormField<models.BookingService>(
              value: _selectedService,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: c.border),
                ),
                filled: true,
                fillColor: c.bgInset,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              hint: Text('Select service (optional)',
                  style: AppType.body(size: 13, color: c.textFaint)),
              items: widget.services.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.name,
                        style: AppType.body(size: 13, color: c.text)),
                  )).toList(),
              onChanged: (v) => setState(() => _selectedService = v),
            ),
            const SizedBox(height: 16),

            // Customer name
            AppInput(
              label: 'Customer name *',
              controller: _nameCtrl,
              icon: Icons.person_outline,
              hint: 'Enter customer name',
            ),
            const SizedBox(height: 14),

            // Phone
            AppInput(
              label: 'Phone (optional)',
              controller: _phoneCtrl,
              icon: Icons.phone_outlined,
              hint: 'Customer phone number',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),

            // Date & Time
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date',
                          style: AppType.body(size: 11.5, weight: FontWeight.w600, color: c.textMuted)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (d != null) setState(() => _selectedDate = d);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: c.bgInset,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 15, color: c.textFaint),
                              const SizedBox(width: 8),
                              Text('${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                                  style: AppType.body(size: 13, color: c.text)),
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
                          style: AppType.body(size: 11.5, weight: FontWeight.w600, color: c.textMuted)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: c.bgInset,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, size: 15, color: c.textFaint),
                              const SizedBox(width: 8),
                              Text(_selectedTime.format(context),
                                  style: AppType.body(size: 13, color: c.text)),
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

            // Notes
            AppInput(
              label: 'Notes (optional)',
              controller: _notesCtrl,
              icon: Icons.notes_outlined,
              hint: 'Any special notes',
            ),
            const SizedBox(height: 20),

            AppBtn('Create Booking',
                full: true,
                onTap: _saving ? null : _save),
          ],
        ),
      ),
    );
  }
}
