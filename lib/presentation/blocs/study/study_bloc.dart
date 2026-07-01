import 'package:flutter_bloc/flutter_bloc.dart'; // Changed to flutter_bloc
import 'package:equatable/equatable.dart';
import 'package:vens_hub/domain/study/repositories/study_repository.dart'; // Corrected interface import path
import 'package:vens_hub/data/models/textbook_model.dart'; // Corrected import
// import 'package:get/get.dart'; // Removed GetX import

part 'study_event.dart'; // Assuming these will be renamed to snake_case
part 'study_state.dart'; // Assuming these will be renamed to snake_case

class StudyBloc extends Bloc<StudyEvent, StudyState> {
  final StudyRepository studyRepository; // Injected dependency

  StudyBloc({required this.studyRepository}) : super(StudyInitial()) {
    on<SearchQueryUpdated>((event, emit) {
      if (state is StudyLoaded) {
        final current = state as StudyLoaded;
        emit(
          StudyLoaded(
            textbooks: current.textbooks,
            searchQuery: event.query,
            isSearching: current.isSearching,
          ),
        );
      }
    });

    on<SearchToggled>((event, emit) {
      if (state is StudyLoaded) {
        final current = state as StudyLoaded;
        emit(
          StudyLoaded(
            textbooks: current.textbooks,
            searchQuery: current.isSearching ? '' : current.searchQuery,
            isSearching: !current.isSearching,
          ),
        );
      }
    });
  }
}
