import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:open_space_parking/core/cloudinary/domain/entities/cloudinary_asset.dart';

class CloudinaryAssetPreview extends StatelessWidget {
  const CloudinaryAssetPreview({
    super.key,
    required this.url,
    this.asset,
    this.height = 120,
    this.onDelete,
    this.isDeleting = false,
  });

  final String url;
  final CloudinaryAsset? asset;
  final double height;
  final VoidCallback? onDelete;
  final bool isDeleting;

  bool get _isImage {
    if (asset != null) return asset!.isImage;
    final lower = url.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('.gif') ||
        lower.contains('/image/upload/');
  }

  bool get _isPdf {
    if (asset != null) return asset!.isPdf;
    return url.toLowerCase().contains('.pdf') ||
        url.toLowerCase().contains('/raw/upload/');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: height,
            child: _isImage
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _FallbackPreview(
                      icon: Icons.broken_image_outlined,
                      label: 'Preview unavailable',
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                  )
                : _FallbackPreview(
                    icon: _isPdf ? Icons.picture_as_pdf : Icons.description,
                    label: _isPdf ? 'PDF document' : 'Document',
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Open',
                  icon: const Icon(Icons.open_in_new, size: 20),
                  onPressed: () => _openUrl(url),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Delete',
                    icon: isDeleting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.error,
                            ),
                          )
                        : Icon(Icons.delete_outline, size: 20, color: colorScheme.error),
                    onPressed: isDeleting ? null : onDelete,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _displayName {
    if (asset != null) return asset!.fileName;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final segment = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (segment.isNotEmpty) return segment;
    }
    return 'Uploaded file';
  }

  Future<void> _openUrl(String target) async {
    final uri = Uri.parse(target);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _FallbackPreview extends StatelessWidget {
  const _FallbackPreview({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colorScheme.primary),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
