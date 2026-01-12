class Position {
  final String id;
  final String name;
  final String alias;
  final int x;
  final int y;
  final DateTime createdAt;
  final DateTime updatedAt;

  Position({
    required this.id,
    required this.name,
    required this.alias,
    required this.x,
    required this.y,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Position copyWith({
    String? id,
    String? name,
    String? alias,
    int? x,
    int? y,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Position(
      id: id ?? this.id,
      name: name ?? this.name,
      alias: alias ?? this.alias,
      x: x ?? this.x,
      y: y ?? this.y,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'alias': alias,
        'x': x,
        'y': y,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory Position.fromJson(Map<String, dynamic> json) => Position(
        id: json['id'] as String,
        name: json['name'] as String,
        alias: json['alias'] as String,
        x: json['x'] as int,
        y: json['y'] as int,
        createdAt: json['createdAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int)
            : null,
      );

  @override
  String toString() {
    return 'Position(id: $id, name: $name, alias: $alias, x: $x, y: $y)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Position &&
        other.id == id &&
        other.name == name &&
        other.alias == alias &&
        other.x == x &&
        other.y == y;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        alias.hashCode ^
        x.hashCode ^
        y.hashCode;
  }
}
