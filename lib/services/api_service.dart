import 'package:dio/dio.dart';

class ApiService {
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://phongtro-api-2026-beb6dzdja8cvg4hz.southeastasia-01.azurewebsites.net/api',
  );

  ApiService({String baseUrl = defaultBaseUrl})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: const {'Accept': 'application/json'},
          ),
        );

  final Dio dio;
}
