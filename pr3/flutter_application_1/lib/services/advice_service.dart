import 'package:dio/dio.dart';

import '../models/advice.dart';

class AdviceFailure implements Exception {
  const AdviceFailure(this.message);
  final String message;
}

class AdviceService {
  AdviceService(this.dio);
  final Dio dio;

  Future<Advice> fetch({CancelToken? cancelToken}) async {
    try {
      final response = await dio.get<dynamic>(
        'advice',
        cancelToken: cancelToken,
      );
      final data = response.data;
      if (data is! Map || data['advice'] is! String) {
        throw const AdviceFailure(
          'Сервер прислал непонятный ответ, попробуй ещё',
        );
      }
      final text = (data['advice'] as String).trim();
      if (text.isEmpty) {
        throw const AdviceFailure('Пришёл пустой совет, попробуй ещё');
      }
      return Advice(text: text, receivedAt: DateTime.now());
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      final message = switch (error.response?.statusCode) {
        401 => 'Ключ API не принят, проверь его и попробуй ещё',
        403 => 'API отклонил доступ, проверь ключ и тариф аккаунта',
        429 => 'Лимит запросов исчерпан, попробуй позже',
        final int code when code >= 500 =>
          'Сервис советов временно недоступен, попробуй позже',
        _ => switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout =>
            'Сервис долго не отвечает, попробуй ещё',
          DioExceptionType.connectionError =>
            'Не удалось подключиться, проверь интернет',
          DioExceptionType.badCertificate =>
            'Не удалось установить защищённое соединение',
          _ => 'Не удалось получить совет, попробуй ещё',
        },
      };
      throw AdviceFailure(message);
    }
  }
}
