// Booking Service — wraps `booking_services` and `bookings` tables
// (shared with web). Mobile scope: list/create services, list/create
// bookings, update booking status. No availability management in v1.

import 'app_logger.dart';
import 'supabase_service.dart';

class BookingService {
  /// Fetch all booking services for this business.
  static Future<List<Map<String, dynamic>>> fetchServices({
    required String businessId,
  }) async {
    log.debug('BookingService.fetchServices — bizId=$businessId');
    final sw = Stopwatch()..start();
    try {
      final rows = await SupabaseService.client
          .from('booking_services')
          .select('*')
          .eq('business_id', businessId)
          .order('service_name', ascending: true);
      log.info('BookingService.fetchServices — ${rows.length} services (${sw.elapsedMilliseconds}ms)');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e, st) {
      log.error('BookingService.fetchServices failed', error: e, stackTrace: st);
      return [];
    }
  }

  /// Create a new booking service.
  static Future<Map<String, dynamic>?> createService({
    required String businessId,
    required String name,
    String? description,
    double? price,
    int durationMinutes = 60,
  }) async {
    log.info('BookingService.createService — bizId=$businessId name="$name"');
    final sw = Stopwatch()..start();
    try {
      final row = await SupabaseService.client
          .from('booking_services')
          .insert({
            'business_id': businessId,
            'service_name': name.trim(),
            if (description != null && description.trim().isNotEmpty)
              'description': description.trim(),
            if (price != null) 'price_ghs': price.round(),
            'duration_minutes': durationMinutes,
            'is_active': true,
          })
          .select()
          .single();
      log.info('BookingService.createService — done id=${row['id']} (${sw.elapsedMilliseconds}ms)');
      return Map<String, dynamic>.from(row as Map);
    } catch (e, st) {
      log.error('BookingService.createService failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Update a booking service.
  static Future<bool> updateService({
    required String serviceId,
    required String businessId,
    String? name,
    String? description,
    double? price,
    int? durationMinutes,
    bool? isActive,
  }) async {
    log.info('BookingService.updateService — id=$serviceId');
    try {
      final updates = <String, dynamic>{
        if (name != null) 'service_name': name.trim(),
        if (description != null) 'description': description.trim(),
        if (price != null) 'price_ghs': price.round(),
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
        if (isActive != null) 'is_active': isActive,
      };
      if (updates.isEmpty) return true;
      await SupabaseService.client
          .from('booking_services')
          .update(updates)
          .eq('id', serviceId)
          .eq('business_id', businessId);
      return true;
    } catch (e, st) {
      log.error('BookingService.updateService failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Delete a booking service.
  static Future<bool> deleteService({
    required String serviceId,
    required String businessId,
  }) async {
    log.info('BookingService.deleteService — id=$serviceId');
    try {
      await SupabaseService.client
          .from('booking_services')
          .delete()
          .eq('id', serviceId)
          .eq('business_id', businessId);
      return true;
    } catch (e, st) {
      log.error('BookingService.deleteService failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Fetch all bookings for this business.
  /// Joins with booking_services to get service name, duration, and price.
  static Future<List<Map<String, dynamic>>> fetchBookings({
    required String businessId,
    String? status,
  }) async {
    log.debug('BookingService.fetchBookings — bizId=$businessId');
    final sw = Stopwatch()..start();
    try {
      var builder = SupabaseService.client
          .from('bookings')
          .select('*, booking_services(service_name, duration_minutes, price_ghs)')
          .eq('business_id', businessId);
      if (status != null && status.isNotEmpty) {
        builder = builder.eq('status', status);
      }
      final rows = await builder
          .order('booking_date', ascending: false)
          .order('booking_time', ascending: false)
          .limit(100);
      log.info('BookingService.fetchBookings — ${rows.length} bookings (${sw.elapsedMilliseconds}ms)');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e, st) {
      log.error('BookingService.fetchBookings failed', error: e, stackTrace: st);
      return [];
    }
  }

  /// Create a new booking.
  /// Note: service_name, duration_minutes, notes, and price are not stored
  /// on the bookings table — they come from the joined booking_services table.
  static Future<Map<String, dynamic>?> createBooking({
    required String businessId,
    required String serviceName,
    String? serviceId,
    required String customerName,
    String? customerPhone,
    String? customerEmail,
    required DateTime startTime,
    int durationMinutes = 60,
    String? notes,
    double? price,
  }) async {
    log.info('BookingService.createBooking — bizId=$businessId customer="$customerName"');
    final sw = Stopwatch()..start();
    try {
      final dateStr = '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}';
      final timeStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';

      final row = await SupabaseService.client
          .from('bookings')
          .insert({
            'business_id': businessId,
            if (serviceId != null && serviceId.isNotEmpty) 'service_id': serviceId,
            'client_name': customerName.trim(),
            if (customerPhone != null && customerPhone.trim().isNotEmpty)
              'client_phone': customerPhone.trim(),
            if (customerEmail != null && customerEmail.trim().isNotEmpty)
              'client_email': customerEmail.trim(),
            'booking_date': dateStr,
            'booking_time': timeStr,
            'status': 'pending',
          })
          .select()
          .single();
      log.info('BookingService.createBooking — done id=${row['id']} (${sw.elapsedMilliseconds}ms)');
      return Map<String, dynamic>.from(row as Map);
    } catch (e, st) {
      log.error('BookingService.createBooking failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Update a booking's status (confirm, cancel, fulfil).
  static Future<bool> updateBookingStatus({
    required String bookingId,
    required String businessId,
    required String status,
  }) async {
    log.info('BookingService.updateBookingStatus — id=$bookingId status=$status');
    try {
      await SupabaseService.client
          .from('bookings')
          .update({'status': status})
          .eq('id', bookingId)
          .eq('business_id', businessId);
      return true;
    } catch (e, st) {
      log.error('BookingService.updateBookingStatus failed', error: e, stackTrace: st);
      return false;
    }
  }
}
