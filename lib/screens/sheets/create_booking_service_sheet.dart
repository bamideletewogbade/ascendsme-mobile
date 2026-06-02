import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/booking_service.dart';
import '../../state/app_state.dart';

/// Bottom sheet to create a new booking service offering.
class CreateBookingServiceSheet extends StatefulWidget {
  const CreateBookingServiceSheet({super.key});

  @override
  State<CreateBookingServiceSheet> createState() => _CreateBookingServiceSheetState();
}

class _CreateBookingServiceSheetState extends State<CreateBookingServiceSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  int _durationMinutes = 60;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    final bizId = context.read<AppState>().business.id;
    if (bizId == null) return;

    final price = double.tryParse(_priceCtrl.text.trim());
    final result = await BookingService.createService(
      businessId: bizId,
      name: name,
      description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      price: price,
      durationMinutes: _durationMinutes,
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
            Text('Add Service',
                style: AppType.heading(size: 18, color: c.text)),
            const SizedBox(height: 16),

            AppInput(
              label: 'Service name *',
              controller: _nameCtrl,
              icon: Icons.miscellaneous_services_outlined,
              hint: 'e.g. Haircut, Consultation',
            ),
            const SizedBox(height: 14),

            AppInput(
              label: 'Description (optional)',
              controller: _descCtrl,
              icon: Icons.notes_outlined,
              hint: 'Brief description',
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: AppInput(
                    label: 'Price (GHS)',
                    controller: _priceCtrl,
                    icon: Icons.payments_outlined,
                    hint: '0',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Duration',
                          style: AppType.body(size: 11.5, weight: FontWeight.w600, color: c.textMuted)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: c.bgInset,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _durationMinutes,
                            isExpanded: true,
                            items: [15, 30, 45, 60, 90, 120].map((m) => DropdownMenuItem(
                                  value: m,
                                  child: Text('$m min',
                                      style: AppType.body(size: 13, color: c.text)),
                                )).toList(),
                            onChanged: (v) => setState(() => _durationMinutes = v ?? 60),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            AppBtn('Add Service',
                full: true,
                onTap: _saving ? null : _save),
          ],
        ),
      ),
    );
  }
}
