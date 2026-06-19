import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';

/// Full-screen preview for uploaded business documents (verification images,
/// PDFs, etc.). Shows the image for image-type documents, and a detail card
/// with open/share actions for all types.
class DocumentPreviewScreen extends StatefulWidget {
  final BusinessDocument doc;

  const DocumentPreviewScreen({super.key, required this.doc});

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  bool _imageLoaded = false;

  bool get _isImage => widget.doc.fileType.startsWith('image/');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final doc = widget.doc;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: c.bgElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.border),
                      ),
                      child: Icon(Icons.arrow_back, size: 18, color: c.text),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(doc.name,
                        style: AppType.heading(size: 18, color: c.text),
                        overflow: TextOverflow.ellipsis),
                  ),
                  GestureDetector(
                    onTap: _shareDocument,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: c.tealSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.share_outlined, size: 18, color: c.teal),
                    ),
                  ),
                ],
              ),
            ),

            // ── Document preview area ──
            Expanded(
              child: _isImage ? _buildImagePreview(c) : _buildFilePreview(c),
            ),

            // ── Bottom metadata card ──
            _buildMetaCard(c),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(AppColorsX c) {
    final doc = widget.doc;
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_imageLoaded)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(c.teal)),
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                doc.documentUrl,
                fit: BoxFit.contain,
                width: MediaQuery.of(context).size.width - 40,
                errorBuilder: (_, _, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _imageLoaded = true);
                  });
                  return _buildFallbackPreview(c);
                },
                loadingBuilder: (_, child, progress) {
                  if (progress == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _imageLoaded = true);
                    });
                    return child;
                  }
                  return _buildLoadingPreview(c, progress);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingPreview(
      AppColorsX c, ImageChunkEvent? progress) {
    final pct = progress != null && progress.expectedTotalBytes != null
        ? (progress.cumulativeBytesLoaded / progress.expectedTotalBytes!)
        : 0.0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 300,
      decoration: BoxDecoration(
        color: c.bgInset,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(
                value: pct > 0 ? pct : null,
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(c.teal),
              ),
            ),
            const SizedBox(height: 12),
            Text('Loading image…',
                style: AppType.body(size: 13, color: c.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackPreview(AppColorsX c) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 300,
      decoration: BoxDecoration(
        color: c.bgInset,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 48, color: c.textFaint),
            const SizedBox(height: 12),
            Text('Preview not available',
                style: AppType.body(size: 14, color: c.textMuted)),
            const SizedBox(height: 4),
            Text('Open the document to view its contents.',
                style: AppType.body(size: 12, color: c.textFaint)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePreview(AppColorsX c) {
    final doc = widget.doc;
    final (icon, label) = switch (doc.fileType) {
      'application/pdf' => (Icons.picture_as_pdf, 'PDF Document'),
      _ => (Icons.insert_drive_file_outlined, 'Document file'),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: c.bgElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.border),
              ),
              child: Icon(icon, size: 36, color: c.teal),
            ),
            const SizedBox(height: 16),
            Text(label,
                style: AppType.heading(size: 17, color: c.text)),
            const SizedBox(height: 6),
            Text(
              'Preview is not available for this file type. '
              'Tap "Open" below to view the document externally.',
              textAlign: TextAlign.center,
              style: AppType.body(size: 13, color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaCard(AppColorsX c) {
    final doc = widget.doc;

    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        border: Border(top: BorderSide(color: c.border)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 16,
              offset: Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Detail rows
            Row(
              children: [
                _metaChip(
                    label: 'Category', value: _capitalize(doc.category), c: c),
                const SizedBox(width: 8),
                _metaChip(
                    label: 'Size', value: doc.fileSizeLabel, c: c),
                const SizedBox(width: 8),
                _metaChip(
                    label: 'Type',
                    value: doc.fileType.split('/').last.toUpperCase(),
                    c: c),
              ],
            ),
            if (doc.description != null &&
                doc.description!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(doc.description!,
                  style: AppType.body(size: 12.5, color: c.textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 16),
            // Actions
            Row(
              children: [
                Expanded(
                  child: AppBtn(
                    'Open document',
                    icon: 'eye',
                    full: true,
                    fontSize: 13,
                    onTap: _openDocument,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppBtn(
                    'Copy link',
                    icon: 'content_copy',
                    variant: BtnVariant.outline,
                    full: true,
                    fontSize: 13,
                    onTap: _copyLink,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaChip({
    required String label,
    required String value,
    required AppColorsX c,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: c.bgInset,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value,
                style: AppType.body(
                    size: 13, weight: FontWeight.w600, color: c.text),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 1),
            Text(label,
                style: AppType.label(size: 9, color: c.textMuted)),
          ],
        ),
      ),
    );
  }

  void _openDocument() {
    Clipboard.setData(ClipboardData(text: widget.doc.documentUrl));
    _showSnack('Document URL copied. Paste it in your browser to open.');
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: widget.doc.documentUrl));
    _showSnack('Document URL copied to clipboard');
  }

  Future<void> _shareDocument() async {
    await Share.shareXFiles(
      [XFile(widget.doc.documentUrl)],
      text: '${widget.doc.name} from AscendSME',
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void _showSnack(String msg) {
    if (!mounted) return;
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: AppType.body(size: 13, color: Colors.white)),
        backgroundColor: c.navyDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
