import 'dart:async';
import 'dart:io' show File;

import 'package:vens_hub/core/di/injection_container.dart' as di;
import 'package:vens_hub/core/services/storage/r2_storage_service.dart';
import 'package:vens_hub/presentation/blocs/study/pdf_viewer_bloc.dart';
import 'package:vens_hub/presentation/blocs/study/pdf_viewer_event.dart';
import 'package:vens_hub/presentation/blocs/study/pdf_viewer_state.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';
import 'package:vens_hub/presentation/widgets/common/ai_chat_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

class PdfViewScreen extends StatefulWidget {
  final String pdfPath;
  final String pdfTitle;

  const PdfViewScreen({
    super.key,
    required this.pdfPath,
    required this.pdfTitle,
  });

  @override
  State<PdfViewScreen> createState() => _PdfViewScreenState();
}

class _PdfViewScreenState extends State<PdfViewScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final R2StorageService _r2Service = di.sl<R2StorageService>();

  String _selectedText = '';
  String? _effectivePdfPath;
  bool _effectiveIsLocal = false;
  bool _isRetrying = false;
  bool _pdfLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadPdfWithCaching();
  }

  Future<void> _loadPdfWithCaching() async {
    if (!_isValidUrl(widget.pdfPath)) {
      context.read<PdfViewerBloc>().add(
        PdfLoadFailure('Invalid PDF URL: ${widget.pdfPath}'),
      );
      return;
    }

    final bloc = context.read<PdfViewerBloc>();
    bloc.add(LoadPdf(widget.pdfPath));

    // Check if already cached in bloc
    final state = bloc.state;
    if (state is PdfViewerLoaded && state.pdfPath == widget.pdfPath) {
      setState(() {
        _pdfLoaded = true;
        _effectivePdfPath = widget.pdfPath;
      });
      return;
    }

    try {
      final cachedPath = await _r2Service.getCachedPdfPath(widget.pdfPath);
      if (!mounted) return;
      setState(() {
        _effectivePdfPath = cachedPath ?? widget.pdfPath;
        _effectiveIsLocal = cachedPath != null;
      });

      // If NOT cached, trigger a background download to cache it for the next time
      if (cachedPath == null) {
        _r2Service.downloadToCache(widget.pdfPath);
      }
    } catch (e) {
      if (!mounted) return;
      if (_looksLikeNotFound(e)) {
        context.read<PdfViewerBloc>().add(
          const PdfLoadFailure('This document is no longer available.'),
        );
        return;
      }
      setState(() {
        _effectivePdfPath = widget.pdfPath;
        _effectiveIsLocal = false;
      });
      // Try background cache anyway if it's just a generic error
      _r2Service.downloadToCache(widget.pdfPath);
    }
  }

  bool _looksLikeNotFound(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('404') || text.contains('not found');
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.hasAuthority;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  void _onTextSelectionChanged(PdfTextSelectionChangedDetails details) {
    setState(() => _selectedText = details.selectedText ?? '');
  }

  void _showAIAssistant() {
    if (_selectedText.isEmpty) return;
    AiChatOverlay.show(
      context,
      contextText: "Selected PDF text: $_selectedText",
      initialQuestion: "Can you explain this text?",
    );
  }

  void _handleDocumentLoaded(int totalPages) {
    if (!mounted) return;
    setState(() {
      _pdfLoaded = true;
      _isRetrying = false;
    });
    context.read<PdfViewerBloc>().add(PdfLoadSuccess(totalPages));
  }

  void _handleDocumentLoadFailed(String description) {
    if (!mounted) return;
    final lower = description.toLowerCase();
    String message;
    if (lower.contains('404') || lower.contains('not found')) {
      message = 'This document is no longer available.';
    } else if (lower.contains('connection closed')) {
      message = 'Connection dropped. Please check your internet.';
    } else {
      message = 'Failed to load the PDF. Please try again.';
    }
    context.read<PdfViewerBloc>().add(PdfLoadFailure(message));
    AppNotifier.warning(context: context, message: message);
    setState(() => _isRetrying = false);
  }

  Future<void> _retryLoad() async {
    setState(() {
      _isRetrying = true;
      _effectivePdfPath = null;
      _effectiveIsLocal = false;
      _pdfLoaded = false;
    });
    await _loadPdfWithCaching();
  }

  Future<void> _openExternally(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      AppNotifier.error(
        context: context,
        message: 'Could not open externally.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PdfViewerBloc, PdfViewerState>(
      buildWhen: (prev, curr) {
        if (curr is PdfViewerError) return true;
        if (prev is PdfViewerLoading && curr is PdfViewerLoaded) return true;
        if (curr is PdfViewerLoaded && prev is PdfViewerLoaded) {
          return prev.isFullScreen != curr.isFullScreen;
        }
        return false;
      },
      builder: (context, state) {
        final isFullScreen = state is PdfViewerLoaded && state.isFullScreen;
        final error = state is PdfViewerError ? state.errorMessage : null;
        final isLoading = state is PdfViewerLoading && !_pdfLoaded;
        final theme = Theme.of(context);

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar:
              isFullScreen
                  ? null
                  : AppBar(
                    backgroundColor: theme.colorScheme.surface.withValues(
                      alpha: 0.95,
                    ),
                    elevation: 0,
                    centerTitle: false,
                    flexibleSpace: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      iconSize: 20,
                      splashRadius: 20,
                    ),
                    title: Column(
                      children: [
                        Text(
                          widget.pdfTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.download_rounded),
                        tooltip: 'Download',
                        onPressed: () => _openExternally(widget.pdfPath),
                        iconSize: 20,
                        splashRadius: 20,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
          body: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: isFullScreen ? 0 : kToolbarHeight,
                ),
                child:
                    error != null
                        ? _buildLoadError(context, error)
                        : _buildPdfViewer(),
              ),
              if (isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
          floatingActionButton:
              _selectedText.isNotEmpty
                  ? FloatingActionButton.extended(
                    onPressed: _showAIAssistant,
                    icon: const Icon(Icons.smart_toy_rounded),
                    label: const Text('Ask AI'),
                    elevation: 4,
                  )
                  : null,
        );
      },
    );
  }

  Widget _buildPdfViewer() {
    final pathToUse = _effectivePdfPath ?? widget.pdfPath;
    if (pathToUse.isEmpty) return const SizedBox.shrink();

    final useLocalFile = _effectiveIsLocal || !_isValidUrl(pathToUse);

    if (useLocalFile) {
      return SfPdfViewer.file(
        File(pathToUse),
        key: _pdfViewerKey,
        controller: _pdfViewerController,
        onTextSelectionChanged: _onTextSelectionChanged,
        canShowTextSelectionMenu: false,
        onDocumentLoaded: (d) => _handleDocumentLoaded(d.document.pages.count),
        onDocumentLoadFailed: (d) => _handleDocumentLoadFailed(d.description),
      );
    }

    return SfPdfViewer.network(
      pathToUse,
      key: _pdfViewerKey,
      controller: _pdfViewerController,
      onTextSelectionChanged: _onTextSelectionChanged,
      canShowTextSelectionMenu: false,
      onDocumentLoaded: (d) => _handleDocumentLoaded(d.document.pages.count),
      onDocumentLoadFailed: (d) => _handleDocumentLoadFailed(d.description),
    );
  }

  Widget _buildLoadError(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: theme.colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to open PDF',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isRetrying ? null : _retryLoad,
              icon:
                  _isRetrying
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.refresh_rounded),
              label: Text(_isRetrying ? 'Retrying…' : 'Try Again'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _openExternally(widget.pdfPath),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open in browser'),
            ),
          ],
        ),
      ),
    );
  }
}
