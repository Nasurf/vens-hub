part of 'study_bloc.dart';

sealed class StudyEvent extends Equatable {
  const StudyEvent();
}

class LoadStudyMaterials extends StudyEvent {
  final String path;
  const LoadStudyMaterials(this.path);

  @override
  List<Object> get props => [path];
}

class SearchQueryUpdated extends StudyEvent {
  // Renamed from UpdateSearchQuery
  final String query;
  const SearchQueryUpdated(this.query);

  @override
  List<Object> get props => [query];
}

class SearchToggled extends StudyEvent {
  // Renamed from ToggleSearch
  const SearchToggled();

  @override
  List<Object> get props => [];
}
