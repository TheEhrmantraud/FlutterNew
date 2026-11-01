import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/app.dart';
import 'package:flutter_application_1/controllers/advice_controller.dart';
import 'package:flutter_application_1/interceptors/api_key_interceptor.dart';
import 'package:flutter_application_1/models/advice.dart';
import 'package:flutter_application_1/services/advice_service.dart';
import 'package:flutter_application_1/storage/advice_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class TestAdapter implements HttpClientAdapter {
  TestAdapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody response(dynamic data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

Advice advice(String text, [int day = 1]) =>
    Advice(text: text, receivedAt: DateTime(2026, 11, day, 12));

class Harness {
  Harness(FutureOr<ResponseBody> Function(RequestOptions) respond) {
    adapter = TestAdapter(respond);
    dio = createDio()..httpClientAdapter = adapter;
    controller = AdviceController(AdviceService(dio), storage);
  }

  late final TestAdapter adapter;
  late final Dio dio;
  final storage = AdviceStorage(SharedPreferencesAsync());
  late final AdviceController controller;

  void dispose() {
    controller.dispose();
    dio.close(force: true);
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('Dio adds the API key through interceptor and parses advice', () async {
    final h = Harness(
      (_) => response({'advice': '  Make time for yourself  '}),
    );
    addTearDown(h.dispose);
    final result = await h.controller.service.fetch();
    expect(result.text, 'Make time for yourself');
    expect(
      h.adapter.requests.single.uri.toString(),
      'https://api.api-ninjas.com/v1/advice',
    );
    expect(h.adapter.requests.single.headers['X-Api-Key'], apiKey);
    expect(h.dio.interceptors.whereType<ApiKeyInterceptor>(), hasLength(1));
    expect(h.dio.interceptors.whereType<PrettyDioLogger>(), hasLength(1));
  });

  test(
    'GetIt resolves shared network service and controller dependencies',
    () async {
      configureDependencies();
      addTearDown(() async => services.reset());
      expect(services<AdviceService>().dio, same(services<Dio>()));
      expect(
        services<AdviceController>().service,
        same(services<AdviceService>()),
      );
      expect(
        services<AdviceController>().storage,
        same(services<AdviceStorage>()),
      );
    },
  );

  for (final invalid in [
    null,
    [],
    {'advice': 3},
    {'advice': '  '},
  ]) {
    test('Invalid API response is handled $invalid', () async {
      final h = Harness((_) => response(invalid));
      addTearDown(h.dispose);
      await expectLater(
        h.controller.service.fetch(),
        throwsA(isA<AdviceFailure>()),
      );
    });
  }

  for (final entry in {
    401: 'Ключ API',
    403: 'доступ',
    429: 'Лимит',
    503: 'временно',
  }.entries) {
    test('HTTP ${entry.key} produces a useful error', () async {
      final h = Harness((_) => response({'error': 'API error'}, entry.key));
      addTearDown(h.dispose);
      await expectLater(
        h.controller.service.fetch(),
        throwsA(
          isA<AdviceFailure>().having(
            (e) => e.message,
            'message',
            contains(entry.value),
          ),
        ),
      );
    });
  }

  test('Timeout produces a retry message', () async {
    final h = Harness(
      (options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      ),
    );
    addTearDown(h.dispose);
    await expectLater(
      h.controller.service.fetch(),
      throwsA(
        isA<AdviceFailure>().having(
          (e) => e.message,
          'message',
          contains('долго'),
        ),
      ),
    );
  });

  test('Favorites history and theme survive controller restart', () async {
    final h = Harness((_) => response({'advice': 'Stay curious'}));
    addTearDown(h.dispose);
    await h.controller.initialize();
    await h.controller.toggleFavorite(h.controller.current!);
    await h.controller.toggleTheme();
    final restarted = AdviceController(AdviceService(h.dio), h.storage);
    addTearDown(restarted.dispose);
    await restarted.initialize();
    expect(restarted.current!.text, 'Stay curious');
    expect(restarted.favorites.single.text, 'Stay curious');
    expect(restarted.darkMode, isTrue);
    expect(restarted.fromStorage, isTrue);
    expect(h.adapter.requests, hasLength(1));
    await restarted.clearHistory();
    final stored = await h.storage.load();
    expect(stored.history, isEmpty);
    expect(stored.favorites.single.text, 'Stay curious');
  });

  test('History is capped at 100 unique advice items', () async {
    var text = 'New thought';
    final h = Harness((_) => response({'advice': text}));
    addTearDown(h.dispose);
    await h.storage.save(
      AdviceSnapshot(history: List.generate(100, (i) => advice('Thought $i'))),
    );
    await h.controller.initialize();
    await h.controller.fetch();
    expect(h.controller.history, hasLength(100));
    expect(h.controller.history.first.text, 'New thought');
    text = 'Thought 1';
    await h.controller.fetch();
    expect(h.controller.history, hasLength(100));
    expect(h.controller.history.first.text, 'Thought 1');
    expect(
      h.controller.history.where((e) => e.text == 'Thought 1'),
      hasLength(1),
    );
  });

  test(
    'Repeated taps do not issue parallel requests and failures retain advice',
    () async {
      final pending = Completer<ResponseBody>();
      final h = Harness((_) => pending.future);
      addTearDown(h.dispose);
      await h.storage.save(
        AdviceSnapshot(history: [advice('Keep this thought')]),
      );
      await h.controller.initialize();
      final request = h.controller.fetch();
      await h.controller.fetch();
      pending.complete(response({'error': 'unavailable'}, 503));
      await request;
      expect(h.adapter.requests, hasLength(1));
      expect(h.controller.current!.text, 'Keep this thought');
      expect(h.controller.history, hasLength(1));
      expect(h.controller.error, contains('временно'));
      expect(h.controller.loading, isFalse);
    },
  );

  test('Corrupt local storage does not prevent fetching advice', () async {
    final h = Harness((_) => response({'advice': 'Start again'}));
    addTearDown(h.dispose);
    await h.storage.preferences.setString(
      'advice_collection_v1',
      'broken json',
    );
    await h.controller.initialize();
    expect(h.controller.current!.text, 'Start again');
    expect((await h.storage.load()).history.single.text, 'Start again');
  });

  testWidgets('Favorites search copy theme and history clearing work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final h = Harness((_) => response({'advice': 'Stay curious'}));
    addTearDown(h.dispose);
    await tester.pumpWidget(MainApp(controller: h.controller));
    await tester.pumpAndSettle();
    expect(find.text('Stay curious'), findsOneWidget);
    await tester.tap(find.byTooltip('Добавить в избранное').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Избранное'));
    await tester.pumpAndSettle();
    expect(find.text('Stay curious'), findsOneWidget);
    await tester.enterText(find.byType(SearchBar), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('Таких мыслей пока нет'), findsOneWidget);
    await tester.tap(find.byTooltip('Очистить поиск'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stay curious'));
    await tester.pumpAndSettle();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(find.text('Копировать'));
    await tester.pumpAndSettle();
    expect(copied, 'Stay curious');
    Navigator.of(tester.element(find.text('Мысль для тебя'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Тёмная тема'));
    await tester.pumpAndSettle();
    expect(h.controller.darkMode, isTrue);
    await tester.tap(find.text('История'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Очистить историю'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Очистить'));
    await tester.pumpAndSettle();
    expect(h.controller.history, isEmpty);
    expect(h.controller.favorites.single.text, 'Stay curious');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Small screen with large text supports all tabs', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final h = Harness(
      (_) => response({
        'advice': 'Take your time and enjoy the little things in life',
      }),
    );
    addTearDown(h.dispose);
    await tester.pumpWidget(MainApp(controller: h.controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final tab in ['Избранное', 'История', 'Для тебя']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
