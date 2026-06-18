class TaskTemplate {
  final String id;
  final String title;
  final String description;
  final List<String> requiredSkills;
  final String kind; // permanent | suggested
  final int usageCount;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;

  TaskTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.requiredSkills,
    required this.kind,
    required this.usageCount,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
  });

  bool get isPermanent => kind == 'permanent';

  factory TaskTemplate.fromJson(Map<String, dynamic> json) {
    return TaskTemplate(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      requiredSkills: json['required_skills'] != null
          ? List<String>.from(json['required_skills'] as List)
          : [],
      kind: json['kind'] as String? ?? 'suggested',
      usageCount: json['usage_count'] as int? ?? 0,
      sortOrder: json['sort_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'required_skills': requiredSkills,
      'kind': kind,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }

  TaskTemplate copyWith({
    String? title,
    String? description,
    List<String>? requiredSkills,
    String? kind,
    int? sortOrder,
    bool? isActive,
  }) {
    return TaskTemplate(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      kind: kind ?? this.kind,
      usageCount: usageCount,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}
