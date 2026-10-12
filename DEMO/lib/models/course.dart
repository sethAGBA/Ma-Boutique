class Course {
  final String id;
  final String name;
  final String? description;

  Course({
    required this.id,
    required this.name,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'],
      name: map['name'],
      description: map['description'],
    );
  }

  factory Course.empty() => Course(id: '', name: '', description: '');
} 