class LocationOption {
  final int id;
  final String name;
  final int? parentId;

  const LocationOption({
    required this.id,
    required this.name,
    this.parentId,
  });

  factory LocationOption.fromJson(
    Map<String, dynamic> json, {
    required String idKey,
    required String nameKey,
    String? parentIdKey,
  }) {
    int? readInt(String key) {
      final value =
          json[key] ?? json['${key[0].toUpperCase()}${key.substring(1)}'];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    String readString(String key) =>
        (json[key] ?? json['${key[0].toUpperCase()}${key.substring(1)}'])
            ?.toString()
            .trim() ??
        '';

    return LocationOption(
      id: readInt(idKey) ?? 0,
      name: readString(nameKey),
      parentId: parentIdKey == null ? null : readInt(parentIdKey),
    );
  }
}
