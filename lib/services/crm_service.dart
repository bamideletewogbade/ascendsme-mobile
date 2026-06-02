/// CRM Service — wraps the shared `crm_profiles`, `crm_interactions`,
/// `customer_groups`, and `customer_group_members` tables (shared with web).
///
/// Mobile scope: view CRM profiles, log interactions, manage tags and groups,
/// track churn risk and CLV. Does NOT include campaign management or automations
/// (those are web-only for now).
///
/// All methods require supabaseConfigured to be true; callers should guard
/// with AppState.supabaseConfigured before routing here.

import 'app_logger.dart';
import 'supabase_service.dart';

class CrmService {
  /// Fetch the CRM profile for a customer, creating one if it doesn't exist.
  static Future<Map<String, dynamic>?> getOrCreateCrmProfile({
    required String businessId,
    required String name,
    String? email,
    String? phone,
  }) async {
    log.info('CrmService.getOrCreateCrmProfile — bizId=$businessId name="$name"');
    final sw = Stopwatch()..start();

    try {
      // Try to find existing profile by email or phone
      if (email != null || phone != null) {
        final conditions = <String>[];
        if (email != null) conditions.add('customer_email.eq.$email');
        if (phone != null) conditions.add('customer_phone.eq.$phone');
        if (conditions.isNotEmpty) {
          final existing = await SupabaseService.client
              .from('crm_profiles')
              .select('*')
              .eq('business_id', businessId)
              .or(conditions.join(','))
              .maybeSingle();
          if (existing != null) {
            log.info('CrmService.getOrCreateCrmProfile — found by email/phone (${sw.elapsedMilliseconds}ms)');
            return Map<String, dynamic>.from(existing as Map);
          }
        }
      }

      // Try by name
      if (name.trim().isNotEmpty) {
        final existing = await SupabaseService.client
            .from('crm_profiles')
            .select('*')
            .eq('business_id', businessId)
            .ilike('customer_name', name.trim())
            .maybeSingle();
        if (existing != null) {
          log.info('CrmService.getOrCreateCrmProfile — found by name (${sw.elapsedMilliseconds}ms)');
          return Map<String, dynamic>.from(existing as Map);
        }
      }

      // Create new profile
      final now = DateTime.now().toIso8601String().split('T')[0];
      final row = await SupabaseService.client
          .from('crm_profiles')
          .insert({
            'business_id': businessId,
            'customer_name': name.trim(),
            if (email != null && email.trim().isNotEmpty) 'customer_email': email.trim(),
            if (phone != null && phone.trim().isNotEmpty) 'customer_phone': phone.trim(),
            'first_interaction_date': now,
            'last_interaction_date': now,
            'total_orders': 0,
            'total_spent_ghs': 0,
            'customer_lifetime_value_ghs': 0,
            'churn_risk_score': 0,
            'tags': [],
          })
          .select()
          .single();
      log.info('CrmService.getOrCreateCrmProfile — created id=${row['id']} (${sw.elapsedMilliseconds}ms)');
      return Map<String, dynamic>.from(row as Map);
    } catch (e, st) {
      log.error('CrmService.getOrCreateCrmProfile failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Fetch all CRM profiles for this business.
  static Future<List<Map<String, dynamic>>> fetchCrmProfiles({
    required String businessId,
    String? query,
  }) async {
    log.debug('CrmService.fetchCrmProfiles — bizId=$businessId');
    final sw = Stopwatch()..start();
    try {
      var builder = SupabaseService.client
          .from('crm_profiles')
          .select('*')
          .eq('business_id', businessId);
      if (query != null && query.trim().isNotEmpty) {
        builder = builder.ilike('customer_name', '%${query.trim()}%');
      }
      final rows = await builder.order('updated_at', ascending: false).limit(50);
      log.info('CrmService.fetchCrmProfiles — ${rows.length} profiles (${sw.elapsedMilliseconds}ms)');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e, st) {
      log.error('CrmService.fetchCrmProfiles failed', error: e, stackTrace: st);
      return [];
    }
  }

  /// Log a CRM interaction.
  static Future<bool> addInteraction({
    required String businessId,
    required String customerProfileId,
    required String type,
    required String description,
    String? internalNotes,
    bool isInternal = false,
  }) async {
    log.info('CrmService.addInteraction — profileId=$customerProfileId type=$type');
    try {
      await SupabaseService.client.from('crm_interactions').insert({
        'business_id': businessId,
        'customer_id': customerProfileId,
        'interaction_type': type,
        'interaction_date': DateTime.now().toUtc().toIso8601String(),
        'description': description,
        if (internalNotes != null && internalNotes.trim().isNotEmpty)
          'internal_notes': internalNotes.trim(),
        'is_internal': isInternal,
      });
      return true;
    } catch (e, st) {
      log.error('CrmService.addInteraction failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Fetch all interactions for a CRM profile.
  static Future<List<Map<String, dynamic>>> getInteractions({
    required String businessId,
    required String customerProfileId,
  }) async {
    log.debug('CrmService.getInteractions — profileId=$customerProfileId');
    try {
      final rows = await SupabaseService.client
          .from('crm_interactions')
          .select('*')
          .eq('business_id', businessId)
          .eq('customer_id', customerProfileId)
          .order('interaction_date', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e, st) {
      log.error('CrmService.getInteractions failed', error: e, stackTrace: st);
      return [];
    }
  }

  /// Fetch customer groups for this business, with member counts.
  static Future<List<Map<String, dynamic>>> getCustomerGroups({
    required String businessId,
  }) async {
    log.debug('CrmService.getCustomerGroups — bizId=$businessId');
    try {
      final rows = await SupabaseService.client
          .from('customer_groups')
          .select('*')
          .eq('business_id', businessId)
          .order('created_at', ascending: false);
      final groups = List<Map<String, dynamic>>.from(rows as List);

      // Fetch member counts
      if (groups.isNotEmpty) {
        final groupIds = groups.map((g) => g['id'] as String).toList();
        final members = await SupabaseService.client
            .from('customer_group_members')
            .select('group_id')
            .inFilter('group_id', groupIds);
        final counts = <String, int>{};
        for (final m in (members as List)) {
          final gid = (m as Map)['group_id'] as String;
          counts[gid] = (counts[gid] ?? 0) + 1;
        }
        for (final g in groups) {
          g['member_count'] = counts[g['id']] ?? 0;
        }
      }
      return groups;
    } catch (e, st) {
      log.error('CrmService.getCustomerGroups failed', error: e, stackTrace: st);
      return [];
    }
  }

  /// Create a customer group.
  static Future<Map<String, dynamic>?> createCustomerGroup({
    required String businessId,
    required String name,
    String? description,
  }) async {
    log.info('CrmService.createCustomerGroup — bizId=$businessId name="$name"');
    try {
      final row = await SupabaseService.client
          .from('customer_groups')
          .insert({
            'business_id': businessId,
            'name': name.trim(),
            'description': description?.trim(),
            'color': '#009B9E',
            'icon': 'users',
            'is_dynamic': false,
          })
          .select()
          .single();
      return Map<String, dynamic>.from(row as Map);
    } catch (e, st) {
      log.error('CrmService.createCustomerGroup failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Add CRM profiles to a group.
  static Future<bool> addProfilesToGroup({
    required String groupId,
    required List<String> crmProfileIds,
  }) async {
    log.info('CrmService.addProfilesToGroup — groupId=$groupId count=${crmProfileIds.length}');
    try {
      final rows = crmProfileIds
          .where((id) => id.isNotEmpty)
          .map((id) => {'group_id': groupId, 'crm_profile_id': id})
          .toList();
      if (rows.isEmpty) return false;
      await SupabaseService.client
          .from('customer_group_members')
          .upsert(rows, onConflict: 'group_id,crm_profile_id', ignoreDuplicates: true);
      return true;
    } catch (e, st) {
      log.error('CrmService.addProfilesToGroup failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Add a tag to a CRM profile.
  static Future<bool> addTag({
    required String businessId,
    required String profileId,
    required String tag,
  }) async {
    log.info('CrmService.addTag — profileId=$profileId tag="$tag"');
    try {
      final profile = await SupabaseService.client
          .from('crm_profiles')
          .select('tags')
          .eq('business_id', businessId)
          .eq('id', profileId)
          .maybeSingle();
      if (profile == null) return false;
      final tags = (profile['tags'] as List<dynamic>?)?.cast<String>() ?? <String>[];
      if (tags.contains(tag)) return true;
      tags.add(tag.trim());
      await SupabaseService.client
          .from('crm_profiles')
          .update({'tags': tags, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', profileId);
      return true;
    } catch (e, st) {
      log.error('CrmService.addTag failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Remove a tag from a CRM profile.
  static Future<bool> removeTag({
    required String businessId,
    required String profileId,
    required String tag,
  }) async {
    log.info('CrmService.removeTag — profileId=$profileId tag="$tag"');
    try {
      final profile = await SupabaseService.client
          .from('crm_profiles')
          .select('tags')
          .eq('business_id', businessId)
          .eq('id', profileId)
          .maybeSingle();
      if (profile == null) return false;
      final tags = (profile['tags'] as List<dynamic>?)?.cast<String>() ?? <String>[];
      tags.remove(tag);
      await SupabaseService.client
          .from('crm_profiles')
          .update({'tags': tags, 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', profileId);
      return true;
    } catch (e, st) {
      log.error('CrmService.removeTag failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Update CRM metrics after a purchase (invoice paid or sale logged).
  static Future<bool> updateCustomerMetrics({
    required String businessId,
    required String profileId,
    required double amountGhs,
  }) async {
    log.info('CrmService.updateCustomerMetrics — profileId=$profileId amount=$amountGhs');
    try {
      final profile = await SupabaseService.client
          .from('crm_profiles')
          .select('*')
          .eq('business_id', businessId)
          .eq('id', profileId)
          .maybeSingle();
      if (profile == null) return false;

      final totalSpent = ((profile['total_spent_ghs'] as num?)?.toDouble() ?? 0) + amountGhs;
      final totalOrders = ((profile['total_orders'] as num?)?.toInt() ?? 0) + 1;
      final newClv = totalSpent * 1.2;
      final now = DateTime.now().toIso8601String().split('T')[0];

      await SupabaseService.client
          .from('crm_profiles')
          .update({
            'total_orders': totalOrders,
            'total_spent_ghs': totalSpent,
            'customer_lifetime_value_ghs': newClv,
            'last_interaction_date': now,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', profileId);
      return true;
    } catch (e, st) {
      log.error('CrmService.updateCustomerMetrics failed', error: e, stackTrace: st);
      return false;
    }
  }
}
