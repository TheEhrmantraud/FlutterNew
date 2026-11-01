class Advice {
  const Advice({required this.text, required this.receivedAt});
  final String text;
  final DateTime receivedAt;

  Map<String, dynamic> toJson() => {
    'text': text,
    'receivedAt': receivedAt.toIso8601String(),
  };

  factory Advice.fromJson(Map<String, dynamic> json) {
    final text = json['text'];
    final date = json['receivedAt'];
    if (text is! String || text.trim().isEmpty || date is! String) {
      throw const FormatException('Некорректный сохранённый совет');
    }
    return Advice(text: text.trim(), receivedAt: DateTime.parse(date));
  }
}

class AdviceSnapshot {
  const AdviceSnapshot({
    this.history = const [],
    this.favorites = const [],
    this.darkMode = false,
  });
  final List<Advice> history;
  final List<Advice> favorites;
  final bool darkMode;

  Map<String, dynamic> toJson() => {
    'history': history.map((advice) => advice.toJson()).toList(),
    'favorites': favorites.map((advice) => advice.toJson()).toList(),
    'darkMode': darkMode,
  };
}
