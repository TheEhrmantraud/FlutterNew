import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/advice.dart';

class AdviceStorage {
  AdviceStorage(this.preferences);
  final SharedPreferencesAsync preferences;

  Future<AdviceSnapshot> load() async {
    final raw = await preferences.getString('advice_collection_v1');
    if (raw == null) return const AdviceSnapshot();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    List<Advice> readList(String key) => (data[key] as List<dynamic>)
        .map((item) => Advice.fromJson(item as Map<String, dynamic>))
        .toList();
    return AdviceSnapshot(
      history: readList('history'),
      favorites: readList('favorites'),
      darkMode: data['darkMode'] == true,
    );
  }

  Future<void> save(AdviceSnapshot snapshot) => preferences.setString(
    'advice_collection_v1',
    jsonEncode(snapshot.toJson()),
  );
}
