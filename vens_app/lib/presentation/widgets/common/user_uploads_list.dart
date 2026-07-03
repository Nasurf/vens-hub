import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vens_hub/core/config/app_config.dart';

class UserUploadsList extends StatelessWidget {
  final String usersCollection;
  final void Function(String url, Map<String, dynamic> record)? onOpen;
  final bool onlyPdf;

  const UserUploadsList({
    super.key,
    this.usersCollection = 'users',
    this.onOpen,
    this.onlyPdf = true,
  });

  String _generateR2Url(String path) {
    final encodedPath = path.split('/').map(Uri.encodeComponent).join('/');
    return "${AppConfig.r2PublicDomain}/$encodedPath";
  }

  String? _getUrlFromRecord(Map<String, dynamic> rec) {
    // Check if we have a stored URL (backward compatibility)
    final storedUrl = rec['url'] as String?;
    if (storedUrl != null && storedUrl.isNotEmpty) {
      return storedUrl;
    }

    // Generate URL from path
    final path = rec['path'] as String?;
    if (path != null && path.isNotEmpty) {
      return _generateR2Url(path);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Sign in to view your uploads'));
    }
    final docRef = FirebaseFirestore.instance
        .collection(usersCollection)
        .doc(user.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _ListLoading();
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const _EmptyUploads();
        }
        final data = snapshot.data!.data() ?? {};
        List<Map<String, dynamic>> uploads =
            (data['uploaded_docs'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>();
        if (onlyPdf) {
          uploads =
              uploads
                  .where(
                    (e) => (e['content_type'] as String? ?? '')
                        .toLowerCase()
                        .contains('pdf'),
                  )
                  .toList();
        }
        uploads.sort(
          (a, b) => (b['uploaded_at'] as String? ?? '').compareTo(
            a['uploaded_at'] as String? ?? '',
          ),
        );

        if (uploads.isEmpty) {
          return const _EmptyUploads();
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: uploads.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final rec = uploads[index];
            final name =
                (rec['meta']?['orig_filename'] as String?) ??
                rec['key'] as String? ??
                'document';
            final url = _getUrlFromRecord(rec);
            final contentType =
                rec['content_type'] as String? ?? 'application/octet-stream';
            final sizeBytes = (rec['size_bytes'] as num?)?.toInt() ?? 0;
            final uploadedAt = rec['uploaded_at'] as String?;
            final category =
                rec['category'] as String? ??
                rec['meta']?['category'] as String? ??
                'notes';

            return _UploadCard(
              name: name,
              url: url,
              contentType: contentType,
              sizeBytes: sizeBytes,
              uploadedAtIso: uploadedAt,
              category: category,
              onOpen:
                  url == null || url.isEmpty
                      ? null
                      : () => onOpen?.call(url, rec),
            );
          },
        );
      },
    );
  }
}

class _UploadCard extends StatelessWidget {
  final String name;
  final String? url;
  final String contentType;
  final int sizeBytes;
  final String? uploadedAtIso;
  final String category;
  final VoidCallback? onOpen;

  const _UploadCard({
    required this.name,
    required this.url,
    required this.contentType,
    required this.sizeBytes,
    required this.uploadedAtIso,
    required this.category,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPdf = contentType.contains('pdf');
    final sizeKb = (sizeBytes / 1024)
        .clamp(0, double.infinity)
        .toStringAsFixed(1);
    final dateStr = _formatIso(uploadedAtIso);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            isPdf
                ? Icons.picture_as_pdf_rounded
                : (contentType.startsWith('image/')
                    ? Icons.image_rounded
                    : Icons.insert_drive_file_rounded),
            color: isPdf ? theme.colorScheme.error : theme.colorScheme.primary,
          ),
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Row(
          children: [
            _Chip(text: category),
            const SizedBox(width: 8),
            Text(
              '$sizeKb KB • $dateStr',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.open_in_new_rounded),
          onPressed: onOpen,
          tooltip: 'Open',
        ),
      ),
    );
  }

  static String _formatIso(String? iso) {
    if (iso == null || iso.isEmpty) return 'Unknown';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MMM d, yyyy • HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _EmptyUploads extends StatelessWidget {
  const _EmptyUploads();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            color: theme.colorScheme.primary,
            size: 36,
          ),
          const SizedBox(height: 8),
          Text('No uploads yet', style: theme.textTheme.bodyMedium),
          Text(
            'Upload a PDF to get started',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListLoading extends StatelessWidget {
  const _ListLoading();
  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
  }
}
