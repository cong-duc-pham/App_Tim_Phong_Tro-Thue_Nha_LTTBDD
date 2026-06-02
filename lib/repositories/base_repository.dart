// lib/repositories/base_repository.dart

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../services/api_service.dart';

abstract class BaseRepository {
  final ApiService apiService;

  BaseRepository({ApiService? apiService})
      : apiService = apiService ?? ApiService();

  Dio get dio => apiService.dio;

  /// Lấy cấu hình Options có kèm theo JWT Bearer Token để xác thực với Backend.
  Future<Options> getOptionsWithToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyUserToken);
    
    if (token != null && token.isNotEmpty) {
      return Options(
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
    }
    
    return Options(
      headers: {
        'Accept': 'application/json',
      },
    );
  }
}
