import 'dart:convert';

class OrderCourse {
  const OrderCourse({required this.id, required this.name});

  static const maxCount = 20;
  static const maxNameLength = 40;
  final String id;
  final String name;

  Map<String, Object?> toJson() => {'id': id, 'name': name};
}

void validateCourses(
  List<OrderCourse> courses,
  Iterable<String?> lineCourseIds, {
  String? activeCourseId,
}) {
  final ids = <String>{};
  final names = <String>{};
  if (courses.length > OrderCourse.maxCount) {
    throw const FormatException('Too many course groups');
  }
  for (final course in courses) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$').hasMatch(course.id) ||
        course.name.trim().isEmpty ||
        course.name != course.name.trim() ||
        course.name.length > OrderCourse.maxNameLength ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(course.name) ||
        !ids.add(course.id) ||
        !names.add(course.name.toLowerCase())) {
      throw const FormatException('Invalid course group');
    }
  }
  if (lineCourseIds.any((id) => id != null && !ids.contains(id)) ||
      (activeCourseId != null && !ids.contains(activeCourseId))) {
    throw const FormatException('Invalid course relationship');
  }
}

List<OrderCourse> parseCourses(Object? value) {
  if (value is! List || value.length > OrderCourse.maxCount) {
    throw const FormatException('Invalid course inventory');
  }
  final courses = <OrderCourse>[];
  for (final row in value) {
    if (row is! Map ||
        row.length != 2 ||
        row['id'] is! String ||
        row['name'] is! String) {
      throw const FormatException('Invalid course group');
    }
    courses.add(
      OrderCourse(id: row['id'] as String, name: row['name'] as String),
    );
  }
  validateCourses(courses, const []);
  return List.unmodifiable(courses);
}

List<OrderCourse> decodeCourses(Object? value) {
  if (value is! String || value.length > 16384) {
    throw const FormatException('Invalid course snapshot');
  }
  return parseCourses(jsonDecode(value));
}

class CourseSection<T> {
  const CourseSection({required this.course, required this.lines});

  final OrderCourse? course;
  final List<T> lines;
}

/// Preserves course order and line order, placing ungrouped lines first.
List<CourseSection<T>> courseSections<T>(
  List<OrderCourse> courses,
  List<T> lines,
  String? Function(T) courseId,
) => [
  for (final course in [null, ...courses])
    if (lines.any((line) => courseId(line) == course?.id))
      CourseSection(
        course: course,
        lines: lines.where((line) => courseId(line) == course?.id).toList(),
      ),
];
