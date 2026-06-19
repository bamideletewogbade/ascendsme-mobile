import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/document_service.dart';
import 'document_preview_screen.dart';
import '../../services/app_logger.dart';
import '../../state/app_state.dart';

/// Document Vault — upload and view business documents for verification,
/// compliance, and record-keeping. Mobile-friendly: simple list + upload.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<BusinessDocument> _documents = [];
  bool _loading = true;
  bool _uploading = false;
  String _categoryFilter = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final bizId = state.business.id;
    if (bizId == null) {
      setState(() {
        _documents = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      _documents = await DocumentService.fetchDocuments(businessId: bizId);
      _documents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e, st) {
      log.error('DocumentsScreen._load failed', error: e, stackTrace: st);
      _documents = [];
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _uploadDocument() async {
    final state = context.read<AppState>();
    final bizId = state.business.id;
    if (bizId == null) {
      _showSnackBar('Sign in to upload documents');
      return;
    }

    final file = await DocumentService.pickDocument();
    if (file == null || !mounted) return;

    setState(() => _uploading = true);

    // Show a category picker for the uploaded document
    final category = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryPicker(),
    );
    if (category == null || !mounted) {
      setState(() => _uploading = false);
      return;
    }

    try {
      final doc = await DocumentService.uploadDocument(
        businessId: bizId,
        name: file.name.split('.').first,
        category: category,
        file: file,
      );
      if (doc != null && mounted) {
        setState(() => _documents.insert(0, doc));
        _showSnackBar('${file.name} uploaded');
      }
    } catch (e) {
      if (mounted) _showSnackBar(DocumentService.friendlyUploadError(e));
    }
    if (mounted) setState(() => _uploading = false);
  }

  List<BusinessDocument> get _filteredDocs {
    var result = _documents;
    if (_categoryFilter != 'all') {
      result = result.where((d) => d.category == _categoryFilter).toList();
    }
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result
          .where((d) =>
              d.name.toLowerCase().contains(q) ||
              d.fileName.toLowerCase().contains(q))
          .toList();
    }
    return result;
  }

  String get _totalSizeLabel {
    if (_documents.isEmpty) return '0 B';
    final totalBytes = _documents.fold<int>(0, (sum, d) => sum + d.fileSize);
    if (totalBytes < 1024) return '$totalBytes B';
    if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, int> get _categoryCounts {
    final counts = <String, int>{};
    for (final d in _documents) {
      counts[d.category] = (counts[d.category] ?? 0) + 1;
    }
    return counts;
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppType.body(size: 13, color: Colors.white)),
        backgroundColor: context.colors.navyDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final filtered = _filteredDocs;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader('Document Vault',
                onBack: () => Navigator.pop(context),
                trailing: _buildUploadBtn(c)),
            if (_uploading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation(c.teal)),
                    ),
                    const SizedBox(width: 8),
                    Text('Uploading…',
                        style: AppType.body(size: 12, color: c.teal)),
                  ],
                ),
              ),
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_documents.isEmpty)
              Expanded(child: _EmptyState(c: c, onUpload: _uploadDocument))
            else
              Expanded(
                child: Column(
                  children: [
                    // ── Stats summary ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Row(
                        children: [
                          _DocStat(
                              label: 'Total',
                              value: '${_documents.length}',
                              color: c.teal),
                          const SizedBox(width: 8),
                          _DocStat(
                              label: 'Size',
                              value: _totalSizeLabel,
                              color: c.textMuted),
                          const SizedBox(width: 8),
                          _DocStat(
                              label: 'Verification',
                              value: '${_categoryCounts['verification'] ?? 0}',
                              color: c.amber),
                        ],
                      ),
                    ),
                    // ── Search bar ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.bgInset,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: c.border),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: AppType.body(size: 13, color: c.text),
                          decoration: InputDecoration(
                            hintText: 'Search documents…',
                            hintStyle: AppType.body(size: 13, color: c.textFaint),
                            prefixIcon: Icon(Icons.search,
                                size: 16, color: c.textFaint),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    child: Icon(Icons.close,
                                        size: 16, color: c.textMuted),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ),
                    // ── Category filter chips ──
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          _FilterChip(
                              label: 'All',
                              active: _categoryFilter == 'all',
                              count: _documents.length,
                              onTap: () => setState(() => _categoryFilter = 'all')),
                          _FilterChip(
                              label: 'Verification',
                              active: _categoryFilter == 'verification',
                              count: _categoryCounts['verification'] ?? 0,
                              onTap: () => setState(() => _categoryFilter = 'verification')),
                          _FilterChip(
                              label: 'Financial',
                              active: _categoryFilter == 'financial',
                              count: _categoryCounts['financial'] ?? 0,
                              onTap: () => setState(() => _categoryFilter = 'financial')),
                          _FilterChip(
                              label: 'Legal',
                              active: _categoryFilter == 'legal',
                              count: _categoryCounts['legal'] ?? 0,
                              onTap: () => setState(() => _categoryFilter = 'legal')),
                          _FilterChip(
                              label: 'Other',
                              active: _categoryFilter == 'other',
                              count: _categoryCounts['other'] ?? 0,
                              onTap: () => setState(() => _categoryFilter = 'other')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // ── Document list ──
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: filtered.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 40),
                                  _EmptyFilterState(c: c, category: _categoryFilter),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                                itemCount: filtered.length,
                                itemBuilder: (_, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: FadeInSlide(
                                    index: i,
                                    child: _DocumentRow(
                                      doc: filtered[i],
                                      onTap: () => _showDocDetail(context, filtered[i]),
                                      onDelete: () => _deleteDoc(context, filtered[i]),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDocDetail(BuildContext context, BusinessDocument doc) {
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
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _docIconColor(doc.category, c).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_docIcon(doc.category),
                        size: 20, color: _docIconColor(doc.category, c)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doc.name,
                            style: AppType.heading(size: 18, color: c.text)),
                        const SizedBox(height: 2),
                        Text(doc.fileName,
                            style: AppType.mono(size: 11, color: c.textFaint)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Details
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.bgInset,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _docDetailRow(c, 'Category', _capitalize(doc.category)),
                    const SizedBox(height: 8),
                    _docDetailRow(c, 'Size', doc.fileSizeLabel),
                    const SizedBox(height: 8),
                    _docDetailRow(c, 'Type', doc.fileType),
                    const SizedBox(height: 8),
                    _docDetailRow(c, 'Uploaded', _formatDate(doc.createdAt)),
                    if (doc.verificationTaskId != null) ...[
                      const SizedBox(height: 8),
                      _docDetailRow(c, 'Verification', 'Linked to verification'),
                    ],
                  ],
                ),
              ),
              if (doc.description != null && doc.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(doc.description!,
                    style: AppType.body(size: 13, color: c.textMuted)),
              ],
              const SizedBox(height: 20),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: AppBtn(
                      'Open document',
                      icon: 'visibility',
                      full: true,
                      fontSize: 13,
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DocumentPreviewScreen(doc: doc),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppBtn(
                      'Delete',
                      variant: BtnVariant.outline,
                      full: true,
                      fontSize: 13,
                      onTap: () {
                        Navigator.pop(ctx);
                        _deleteDoc(context, doc);
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
    );
  }

  Future<void> _deleteDoc(BuildContext context, BusinessDocument doc) async {
    final c = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete document?',
            style: AppType.heading(size: 17, color: c.text)),
        content: Text('Remove ${doc.name} from your vault? This cannot be undone.',
            style: AppType.body(size: 13, color: c.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep',
                style: AppType.body(size: 13, weight: FontWeight.w600, color: c.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: AppType.body(size: 13, weight: FontWeight.w600, color: c.rose)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final bizId = context.read<AppState>().business.id;
    if (bizId == null) return;

    try {
      await DocumentService.deleteDocument(
                          businessId: bizId,
                          documentId: doc.id,
                          storagePath: doc.storagePath,
                        );
      if (!mounted) return;
      setState(() => _documents.removeWhere((d) => d.id == doc.id));
      _showSnackBar('${doc.name} deleted');
    } catch (e) {
      if (mounted) _showSnackBar('Failed to delete document');
    }
  }

  Widget _buildUploadBtn(AppColorsX c) {
    return GestureDetector(
      onTap: _uploading ? null : _uploadDocument,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: c.teal,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(_uploading ? Icons.hourglass_top : Icons.upload_file,
            size: 18, color: Colors.white),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _formatDate(DateTime dt) =>
      '${dt.month}/${dt.day}/${dt.year}';

  IconData _docIcon(String category) => switch (category) {
        'verification' => Icons.shield_outlined,
        'financial'    => Icons.account_balance_outlined,
        'legal'        => Icons.balance_outlined,
        _              => Icons.description_outlined,
      };

  Color _docIconColor(String category, AppColorsX c) => switch (category) {
        'verification' => c.green,
        'financial'    => c.teal,
        'legal'        => c.blue,
        _              => c.textMuted,
      };

  Widget _docDetailRow(AppColorsX c, String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppType.body(size: 12, color: c.textMuted)),
          Text(value,
              style: AppType.body(size: 12, weight: FontWeight.w600, color: c.text)),
        ],
      );
}

// ── Category picker bottom sheet ──────────────────────────────────────────

class _CategoryPicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const categories = [
      ('verification', 'Verification', Icons.shield_outlined),
      ('financial', 'Financial', Icons.account_balance_outlined),
      ('legal', 'Legal', Icons.balance_outlined),
      ('other', 'Other', Icons.folder_outlined),
    ];

    return GlassSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text('Select category',
                style: AppType.heading(size: 17, color: c.text)),
          ),
          ...categories.map((cat) => ListTile(
                leading: Icon(cat.$3, color: c.teal),
                title: Text(cat.$2,
                    style: AppType.body(size: 14, weight: FontWeight.w500, color: c.text)),
                onTap: () => Navigator.pop(context, cat.$1),
              )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final int count;
  final VoidCallback onTap;

  const _FilterChip({
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

// ── Stat chip ─────────────────────────────────────────────────────────────

class _DocStat extends StatelessWidget {
  final String label, value;
  final Color color;

  const _DocStat({
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

// ── Document row ──────────────────────────────────────────────────────────

class _DocumentRow extends StatelessWidget {
  final BusinessDocument doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DocumentRow({
    required this.doc,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, iconColor) = switch (doc.category) {
      'verification' => (Icons.shield_outlined, c.green),
      'financial'    => (Icons.account_balance_outlined, c.teal),
      'legal'        => (Icons.balance_outlined, c.blue),
      _              => (Icons.description_outlined, c.textMuted),
    };

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.name,
                    style: AppType.body(size: 13, weight: FontWeight.w600, color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(doc.fileSizeLabel,
                        style: AppType.body(size: 11, color: c.textFaint)),
                    const SizedBox(width: 6),
                    Text('·',
                        style: AppType.body(size: 11, color: c.textFaint)),
                    const SizedBox(width: 6),
                    Text(doc.category[0].toUpperCase() + doc.category.substring(1),
                        style: AppType.body(size: 11, color: c.textFaint)),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: c.textFaint),
        ],
      ),
    );
  }
}

// ── Empty states ──────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final AppColorsX c;
  final VoidCallback onUpload;
  const _EmptyState({required this.c, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: c.navySurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.folder_open_outlined, size: 28, color: c.navyDeep),
            ),
            const SizedBox(height: 16),
            Text('No documents yet',
                style: AppType.heading(size: 17, color: c.text)),
            const SizedBox(height: 8),
            Text(
              'Upload business documents for verification — tax certificates, registration docs, bank statements, and more.',
              textAlign: TextAlign.center,
              style: AppType.body(size: 13, color: c.textMuted),
            ),
            const SizedBox(height: 20),
            AppBtn('Upload document',
                icon: 'upload',
                onTap: onUpload),
          ],
        ),
      ),
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  final AppColorsX c;
  final String category;

  const _EmptyFilterState({required this.c, required this.category});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_outlined, size: 40, color: c.textFaint),
            const SizedBox(height: 12),
            Text('No ${_capitalize(category)} documents',
                style: AppType.body(size: 15, weight: FontWeight.w600, color: c.text)),
            const SizedBox(height: 4),
            Text('Try a different category or upload a new document.',
                textAlign: TextAlign.center,
                style: AppType.body(size: 12.5, color: c.textMuted)),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
