import 'package:flutter_bloc/flutter_bloc.dart';
import 'pdf_viewer_event.dart';
import 'pdf_viewer_state.dart';

class PdfViewerBloc extends Bloc<PdfViewerEvent, PdfViewerState> {
  // Cache loaded PDFs to avoid reloading
  final Map<String, int> _loadedPdfs = {};
  String? _currentPdfPath;

  PdfViewerBloc() : super(const PdfViewerInitial()) {
    on<LoadPdf>(_onLoadPdf);
    on<PdfLoadSuccess>(_onPdfLoadSuccess);
    on<PdfLoadFailure>(_onPdfLoadFailure);
    on<SelectText>(_onSelectText);
    on<ChangePage>(_onChangePage);
    on<ChangeZoom>(_onChangeZoom);
    on<ToggleFullScreen>(_onToggleFullScreen);
    on<ToggleControls>(_onToggleControls);
    on<ShowControls>(_onShowControls);
    on<HideControls>(_onHideControls);
    on<ResetPdfViewer>(_onReset);
  }

  void _onLoadPdf(LoadPdf event, Emitter<PdfViewerState> emit) {
    _currentPdfPath = event.pdfPath;
    // Check if already loaded
    if (_loadedPdfs.containsKey(event.pdfPath)) {
      emit(
        PdfViewerLoaded(
          totalPages: _loadedPdfs[event.pdfPath]!,
          pdfPath: event.pdfPath,
        ),
      );
    } else {
      emit(PdfViewerLoading(pdfPath: event.pdfPath));
    }
  }

  void _onPdfLoadSuccess(PdfLoadSuccess event, Emitter<PdfViewerState> emit) {
    if (_currentPdfPath != null) {
      _loadedPdfs[_currentPdfPath!] = event.totalPages;
    }
    emit(
      PdfViewerLoaded(totalPages: event.totalPages, pdfPath: _currentPdfPath),
    );
  }

  void _onPdfLoadFailure(PdfLoadFailure event, Emitter<PdfViewerState> emit) {
    emit(PdfViewerError(event.error, pdfPath: _currentPdfPath));
  }

  void _onSelectText(SelectText event, Emitter<PdfViewerState> emit) {
    if (state is PdfViewerLoaded) {
      final loaded = state as PdfViewerLoaded;
      emit(
        loaded.copyWith(
          isTextSelected: event.selectedText?.isNotEmpty ?? false,
          selectedText: event.selectedText,
          showControls: true,
        ),
      );
    }
  }

  void _onChangePage(ChangePage event, Emitter<PdfViewerState> emit) {
    if (state is PdfViewerLoaded) {
      final loaded = state as PdfViewerLoaded;
      emit(loaded.copyWith(currentPage: event.page, showControls: true));
    }
  }

  void _onChangeZoom(ChangeZoom event, Emitter<PdfViewerState> emit) {
    if (state is PdfViewerLoaded) {
      final loaded = state as PdfViewerLoaded;
      emit(loaded.copyWith(currentZoom: event.zoom));
    }
  }

  void _onToggleFullScreen(
    ToggleFullScreen event,
    Emitter<PdfViewerState> emit,
  ) {
    if (state is PdfViewerLoaded) {
      final loaded = state as PdfViewerLoaded;
      emit(loaded.copyWith(isFullScreen: !loaded.isFullScreen));
    }
  }

  void _onToggleControls(ToggleControls event, Emitter<PdfViewerState> emit) {
    if (state is PdfViewerLoaded) {
      final loaded = state as PdfViewerLoaded;
      emit(loaded.copyWith(showControls: !loaded.showControls));
    }
  }

  void _onShowControls(ShowControls event, Emitter<PdfViewerState> emit) {
    if (state is PdfViewerLoaded) {
      final loaded = state as PdfViewerLoaded;
      if (!loaded.showControls) {
        emit(loaded.copyWith(showControls: true));
      }
    }
  }

  void _onHideControls(HideControls event, Emitter<PdfViewerState> emit) {
    if (state is PdfViewerLoaded) {
      final loaded = state as PdfViewerLoaded;
      if (loaded.showControls && !loaded.isTextSelected) {
        emit(loaded.copyWith(showControls: false));
      }
    }
  }

  void _onReset(ResetPdfViewer event, Emitter<PdfViewerState> emit) {
    _currentPdfPath = null;
    emit(const PdfViewerInitial());
  }

  void clearCache() => _loadedPdfs.clear();
}
