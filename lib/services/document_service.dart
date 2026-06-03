/// Document Service — manages business document uploads for verification.
///
/// Wraps Supabase Storage (`verification-documents` bucket) and the
/// `business_documents` table. Handles file picking, uploading, listing,
/// and deleting documents.

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../core/models.dart';
import 'app_logger.dart';
import 'supabase_service.dart';

class DocumentService {
  /// Pick a document (image or PDF) from the device.
  static Future<PlatformFile?> pickDocument() async {
    log.debug('DocumentService.pickDocument');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'heic', 'heif'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    log.info('DocumentService.pickDocument — picked: ${file.name} (${file.size} bytes)');
    return file;
  }

  /// Upload a picked document to Supabase Storage and create a record.
  /// Returns the created [BusinessDocument] or null on failure.
  static Future<BusinessDocument?> uploadDocument({
    required String businessId,
    required String name,
    required String category,
    required PlatformFile file,
    String? verificationTaskId,
    String? description,
  }) async {
    if (file.bytes == null && file.path == null) {
      log.warning('DocumentService.uploadDocument — no file data');
      return null;
    }

    log.info('DocumentService.uploadDocument — name="$name" category=$category file=${file.name}');
    final sw = Stopwatch()..start();

    try {
      // Read file bytes (from memory or disk)
      List<int> bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else {
        final diskFile = File(file.path!);
        bytes = await diskFile.readAsBytes();
      }

      // Validate file size (max 10MB as per web's document service)
      const maxBytes = 10 * 1024 * 1024;
      if (bytes.length > maxBytes) {
        log.warning('DocumentService.uploadDocument — file too large: ${bytes.length} bytes');
        return null;
      }

      // Determine MIME type
      final ext = file.extension?.toLowerCase() ?? '';
      final mimeType = switch (ext) {
        'pdf' => 'application/pdf',
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'heic' || 'heif' => 'image/heic',
        _ => 'application/octet-stream',
      };

      final row = await SupabaseService.uploadBusinessDocument(
        businessId: businessId,
        name: name,
        category: category,
        fileName: file.name,
        fileBytes: bytes,
        fileType: mimeType,
        verificationTaskId: verificationTaskId,
        description: description,
      );

      log.info('DocumentService.uploadDocument — done (${sw.elapsedMilliseconds}ms)');
      return BusinessDocument.fromRow(row);
    } catch (e, st) {
      log.error('DocumentService.uploadDocument failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Fetch all documents for a business, optionally filtered by category.
  static Future<List<BusinessDocument>> fetchDocuments({
    required String businessId,
    String? category,
  }) async {
    log.debug('DocumentService.fetchDocuments — bizId=$businessId category=$category');
    final rows = await SupabaseService.fetchBusinessDocuments(
      businessId: businessId,
      category: category,
    );
    return rows.map(BusinessDocument.fromRow).toList();
  }

  /// Delete a document by id. Removes the file from Storage and the DB record.
  /// [storagePath] is the file's path in the Storage bucket (from
  /// [BusinessDocument.storagePath]).
  static Future<void> deleteDocument({
    required String businessId,
    required String documentId,
    required String storagePath,
  }) async {
    log.info('DocumentService.deleteDocument — bizId=$businessId docId=$documentId');
    await SupabaseService.deleteBusinessDocument(
      documentId: documentId,
      storagePath: storagePath,
    );
  }

  /// Returns a display-friendly error message for upload failures.
  static String friendlyUploadError(Object? error) {
    if (error is String && error.isNotEmpty) return error;
    final msg = error?.toString() ?? '';
    if (msg.contains('size')) return 'File is too large. Maximum size is 10 MB.';
    if (msg.contains('type')) return 'Only PDF and image files are supported.';
    return 'Upload failed. Check your connection and try again.';
  }
}
