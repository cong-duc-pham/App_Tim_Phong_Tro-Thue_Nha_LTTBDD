import 'package:dio/dio.dart';

class ApiService {
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Máy ảo Android (Emulator):
    defaultValue: 'http://10.0.2.2:61795/api',
    // Thiết bị thật (Wi-Fi LAN):
    // defaultValue: 'http://172.24.5.214:61795/api',
  );

  ApiService({String baseUrl = defaultBaseUrl})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 10),
            headers: const {'Accept': 'application/json'},
          ),
        );

  final Dio dio;
}
