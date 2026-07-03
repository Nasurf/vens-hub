import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vens_hub/presentation/blocs/course/course_state.dart';

class CourseCubit extends Cubit<CourseState> {
  CourseCubit() : super(CourseInitial());

  void updateCourse(String course) {
    // This cubit might need a different state structure
    // For now, we'll emit CourseInitial as a placeholder
    emit(CourseInitial());
  }

  void updateTopic(List<dynamic> topics) {
    // This cubit might need a different state structure
    // For now, we'll emit CourseInitial as a placeholder
    emit(CourseInitial());
  }
}
