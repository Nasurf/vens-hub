import 'package:equatable/equatable.dart';

abstract class PdfViewerEvent extends Equatable {
  const PdfViewerEvent();

  @override
  List<Object?> get props => [];
}

class LoadPdf extends PdfViewerEvent {
  final String pdfPath;
  const LoadPdf(this.pdfPath);

  @override
  List<Object?> get props => [pdfPath];
}

class PdfLoadSuccess extends PdfViewerEvent {
  final int totalPages;
  const PdfLoadSuccess(this.totalPages);

  @override
  List<Object?> get props => [totalPages];
}

class PdfLoadFailure extends PdfViewerEvent {
  final String error;
  const PdfLoadFailure(this.error);

  @override
  List<Object?> get props => [error];
}

class SelectText extends PdfViewerEvent {
  final String? selectedText;
  const SelectText(this.selectedText);

  @override
  List<Object?> get props => [selectedText];
}

class ChangePage extends PdfViewerEvent {
  final int page;
  const ChangePage(this.page);

  @override
  List<Object?> get props => [page];
}

class ChangeZoom extends PdfViewerEvent {
  final double zoom;
  const ChangeZoom(this.zoom);

  @override
  List<Object?> get props => [zoom];
}

class ToggleFullScreen extends PdfViewerEvent {
  const ToggleFullScreen();
}

class ToggleControls extends PdfViewerEvent {
  const ToggleControls();
}

class ShowControls extends PdfViewerEvent {
  const ShowControls();
}

class HideControls extends PdfViewerEvent {
  const HideControls();
}

class ResetPdfViewer extends PdfViewerEvent {
  const ResetPdfViewer();
}
