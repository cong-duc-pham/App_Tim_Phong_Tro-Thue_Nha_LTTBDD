import 'package:dio/dio.dart';

import 'base_repository.dart';

class ReportRepository extends BaseRepository {
  Future<void> createIssueReport({
    required String reason,
    required String description,
  }) async {
    try {
      await dio.post<Map<String, dynamic>>(
        '/reports',
        data: {
          'reason': reason,
          'description': description,
        },
        options: await getOptionsWithToken(),
      );
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  String _readBackendMessage(DioException e) {
    if (e.response?.statusCode == 404) {
      return 'Backend chưa có endpoint báo cáo. Hãy restart backend rồi gửi lại.';
    }

    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'] ?? data['Message'];
      if (message != null) return message.toString();
    }
    if (data is String && data.trim().isNotEmpty) {
      return data;
    }
    return e.message ?? 'Không kết nối được backend.';
  }
}
