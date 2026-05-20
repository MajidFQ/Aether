class Task {
  final String id;
  final String title;
  final String description;
  final DateTime dueDate;
  final String priority; // 'low', 'medium', 'high'
  final bool isCompleted;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'priority': priority,
      'isCompleted': isCompleted,
    };
  }

  factory Task.fromMap(String id, Map<String, dynamic> map) {
    return Task(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      dueDate: DateTime.parse(map['dueDate']),
      priority: map['priority'] ?? 'medium',
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  Task copyWith({bool? isCompleted}) {
    return Task(
      id: id,
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
