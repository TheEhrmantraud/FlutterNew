import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'controllers/advice_controller.dart';
import 'interceptors/api_key_interceptor.dart';
import 'services/advice_service.dart';
import 'storage/advice_storage.dart';

const apiKey = String.fromEnvironment('API_NINJAS_KEY');
final services = GetIt.instance;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  runApp(MainApp(controller: services<AdviceController>()));
}

void configureDependencies() {
  services.registerLazySingleton<Dio>(createDio);
  services.registerLazySingleton<AdviceService>(
    () => AdviceService(services<Dio>()),
  );
  services.registerLazySingleton<AdviceStorage>(
    () => AdviceStorage(SharedPreferencesAsync()),
  );
  services.registerLazySingleton<AdviceController>(
    () =>
        AdviceController(services<AdviceService>(), services<AdviceStorage>()),
  );
}

Dio createDio() {
  return Dio(
      BaseOptions(
        baseUrl: 'https://api.api-ninjas.com/v1/',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json'},
      ),
    )
    ..interceptors.addAll([
      ApiKeyInterceptor(apiKey),
      PrettyDioLogger(
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: true,
        error: true,
        compact: true,
        enabled: kDebugMode,
      ),
    ]);
}
