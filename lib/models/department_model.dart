class DepartmentModel {
  final String name;

  DepartmentModel({
    required this.name,
  });

  factory DepartmentModel.fromJson(String name) {
    return DepartmentModel(name: name);
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DepartmentModel &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

