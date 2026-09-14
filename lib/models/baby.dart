class Baby {
  final String id;
  final String name;
  final DateTime? birthDate;

  const Baby({required this.id, required this.name, this.birthDate});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'birthDate': birthDate?.toIso8601String(),
      };

  factory Baby.fromJson(Map<String, dynamic> json) => Baby(
        id: json['id'] as String,
        name: json['name'] as String,
        birthDate: json['birthDate'] != null
            ? DateTime.tryParse(json['birthDate'] as String)
            : null,
      );

  Baby copyWith({String? name, DateTime? birthDate, bool clearBirthDate = false}) => Baby(
        id: id,
        name: name ?? this.name,
        birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      );
}
