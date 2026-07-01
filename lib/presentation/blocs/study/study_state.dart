part of 'study_bloc.dart';

sealed class StudyState extends Equatable {
  const StudyState();
}

final class StudyInitial extends StudyState {
  @override
  List<Object> get props => [];
}

class StudyLoading extends StudyState {
  @override
  List<Object> get props => [];
}

class StudyLoaded extends StudyState {
  final List<TextBookModel> textbooks;
  final String searchQuery;
  final bool isSearching;

  const StudyLoaded({
    required this.textbooks,
    this.searchQuery = '',
    this.isSearching = false,
  });

  List<TextBookModel> get filteredTextbooks =>
      searchQuery.isEmpty
          ? textbooks
          : textbooks
              .where(
                (book) =>
                    book.name.toLowerCase().contains(searchQuery.toLowerCase()),
              )
              .toList();

  @override
  List<Object> get props => [textbooks, searchQuery, isSearching];
}

class StudyError extends StudyState {
  final String message;
  const StudyError(this.message);

  @override
  List<Object> get props => [message];
}
