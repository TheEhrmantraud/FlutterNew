import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/advice.dart';
import '../services/advice_service.dart';
import '../storage/advice_storage.dart';

class AdviceController extends ChangeNotifier {
  AdviceController(this.service, this.storage);
  final AdviceService service;
  final AdviceStorage storage;
  final List<Advice> _history = [];
  final List<Advice> _favorites = [];
  List<Advice> get history => List.unmodifiable(_history);
  List<Advice> get favorites => List.unmodifiable(_favorites);
  Advice? current;
  bool initialized = false;
  bool loading = false;
  bool darkMode = false;
  bool fromStorage = false;
  String? error;
  String? storageError;
  CancelToken? _cancelToken;
  Future<void> _pendingSave = Future.value();
  bool _disposed = false;

  bool isFavorite(Advice advice) =>
      _favorites.any((item) => item.text == advice.text);

  Future<void> initialize() async {
    try {
      final saved = await storage.load();
      if (_disposed) return;
      _history.addAll(saved.history.take(100));
      _favorites.addAll(saved.favorites);
      darkMode = saved.darkMode;
      current = _history.firstOrNull;
      fromStorage = current != null;
    } catch (_) {
      storageError = 'Не удалось прочитать сохранённые советы';
    }
    if (_disposed) return;
    initialized = true;
    notifyListeners();
    if (current == null) await fetch();
  }

  Future<void> fetch() async {
    if (loading || !initialized || _disposed) return;
    loading = true;
    error = null;
    _cancelToken = CancelToken();
    notifyListeners();
    try {
      final advice = await service.fetch(cancelToken: _cancelToken);
      if (_disposed) return;
      current = advice;
      fromStorage = false;
      _history.removeWhere((item) => item.text == advice.text);
      _history.insert(0, advice);
      if (_history.length > 100) _history.removeLast();
      await _save();
    } on AdviceFailure catch (failure) {
      error = failure.message;
    } on DioException catch (failure) {
      if (!CancelToken.isCancel(failure)) {
        error = 'Не удалось получить совет, попробуй ещё';
      }
    } catch (_) {
      error = 'Не удалось получить совет, попробуй ещё';
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> toggleFavorite(Advice advice) async {
    if (isFavorite(advice)) {
      _favorites.removeWhere((item) => item.text == advice.text);
    } else {
      _favorites.insert(0, advice);
    }
    notifyListeners();
    await _save();
  }

  Future<void> clearHistory() async {
    _history.clear();
    notifyListeners();
    await _save();
  }

  Future<void> toggleTheme() async {
    darkMode = !darkMode;
    notifyListeners();
    await _save();
  }

  Future<void> _save() {
    final snapshot = AdviceSnapshot(
      history: List.of(_history),
      favorites: List.of(_favorites),
      darkMode: darkMode,
    );
    _pendingSave = _pendingSave.then((_) async {
      try {
        await storage.save(snapshot);
        storageError = null;
      } catch (_) {
        storageError = 'Не удалось сохранить изменения на устройстве';
      }
      if (!_disposed) notifyListeners();
    });
    return _pendingSave;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelToken?.cancel();
    super.dispose();
  }
}
