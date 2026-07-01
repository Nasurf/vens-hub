import 'dart:async';

import 'package:vens_hub/presentation/blocs/study/pdf_viewer_bloc.dart';
import 'package:vens_hub/presentation/blocs/study/pdf_viewer_event.dart';
import 'package:vens_hub/presentation/blocs/study/pdf_viewer_state.dart';
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

  String _selectedText = '';
  bool _pdfLoaded = false;
  Timer? _loadTimeoutTimer;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<PdfViewerBloc>();
    bloc.add(LoadPdf(widget.pdfPath));

    // Check if already loaded
    final state = bloc.state;
    if (state is PdfViewerLoaded && state.pdfPath == widget.pdfPath) {
      _pdfLoaded = true;
    } else {
      _startLoadTimeout();
    }
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    _loadTimeoutTimer?.cancel();
    super.dispose();
  }

  void _startLoadTimeout() {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted) return;
      final state = context.read<PdfViewerBloc>().state;
      if (state is PdfViewerLoading) {
        context.read<PdfViewerBloc>().add(
          const PdfLoadFailure('Taking too long. Opening in new tab...'),
        );
        _openInNewTab(widget.pdfPath);
      }
    });
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

  Future<void> _openInNewTab(String url) async {
    try {
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
    } catch (_) {}
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

        return Scaffold(
          appBar:
              isFullScreen
                  ? null
                  : AppBar(
                    title: Text(
                      widget.pdfTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Open in new tab',
                        onPressed: () => _openInNewTab(widget.pdfPath),
                        icon: const Icon(Icons.open_in_new_rounded),
                      ),
                    ],
                  ),
          body: Stack(
            children: [
              SfPdfViewer.network(
                widget.pdfPath,
                key: _pdfViewerKey,
                controller: _pdfViewerController,
                onTextSelectionChanged: _onTextSelectionChanged,
                canShowTextSelectionMenu: false,
                onDocumentLoaded: (details) {
                  _loadTimeoutTimer?.cancel();
                  setState(() => _pdfLoaded = true);
                  context.read<PdfViewerBloc>().add(
                    PdfLoadSuccess(details.document.pages.count),
                  );
                },
                onDocumentLoadFailed: (details) {
                  _loadTimeoutTimer?.cancel();
                  context.read<PdfViewerBloc>().add(
                    PdfLoadFailure('Failed to load. Opening in new tab...'),
                  );
                  _openInNewTab(widget.pdfPath);
                },
              ),
              if (isLoading) const Center(child: CircularProgressIndicator()),
              if (error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(error, textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
          floatingActionButton:
              _selectedText.isNotEmpty
                  ? FloatingActionButton.extended(
                    onPressed: _showAIAssistant,
                    icon: const Icon(Icons.smart_toy),
                    label: const Text('Ask AI'),
                  )
                  : null,
        );
      },
    );
  }
}
