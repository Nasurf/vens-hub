import 'package:equatable/equatable.dart';

abstract class PdfViewerState extends Equatable {
  const PdfViewerState();

  @override
  List<Object?> get props => [];
}

class PdfViewerInitial extends PdfViewerState {
  const PdfViewerInitial();
}

class PdfViewerLoading extends PdfViewerState {
  final String? pdfPath;
  const PdfViewerLoading({this.pdfPath});

  @override
  List<Object?> get props => [pdfPath];
}

class PdfViewerLoaded extends PdfViewerState {
  final String? pdfPath;
  final bool isTextSelected;
  final String? selectedText;
  final bool isFullScreen;
  final double currentZoom;
  final int currentPage;
  final int totalPages;
  final bool showControls;

  const PdfViewerLoaded({
    this.pdfPath,
    this.isTextSelected = false,
    this.selectedText,
    this.isFullScreen = false,
    this.currentZoom = 1.0,
    this.currentPage = 1,
    this.totalPages = 1,
    this.showControls = true,
  });

  PdfViewerLoaded copyWith({
    String? pdfPath,
    bool? isTextSelected,
    String? selectedText,
    bool? isFullScreen,
    double? currentZoom,
    int? currentPage,
    int? totalPages,
    bool? showControls,
  }) {
    return PdfViewerLoaded(
      pdfPath: pdfPath ?? this.pdfPath,
      isTextSelected: isTextSelected ?? this.isTextSelected,
      selectedText: selectedText ?? this.selectedText,
      isFullScreen: isFullScreen ?? this.isFullScreen,
      currentZoom: currentZoom ?? this.currentZoom,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      showControls: showControls ?? this.showControls,
    );
  }

  @override
  List<Object?> get props => [
    pdfPath,
    isTextSelected,
    selectedText,
    isFullScreen,
    currentZoom,
    currentPage,
    totalPages,
    showControls,
  ];
}

class PdfViewerError extends PdfViewerState {
  final String errorMessage;
  final String? pdfPath;

  const PdfViewerError(this.errorMessage, {this.pdfPath});

  @override
  List<Object?> get props => [errorMessage, pdfPath];
}
