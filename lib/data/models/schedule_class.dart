class ScheduleModel {
  final String id;
  final String course;
  final String teacher;
  final String room;
  final String type;
  // Todo: Convert to appropriate datetime type
  final String startDate;
  final String endDate;

  ScheduleModel({
    required this.id,
    required this.course,
    required this.teacher,
    required this.room,
    required this.type,
    required this.startDate,
    required this.endDate,
  });
}
