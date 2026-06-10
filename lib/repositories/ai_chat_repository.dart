import 'package:dio/dio.dart';

import '../models/ai_chat_message.dart';
import 'base_repository.dart';

class AiChatRepository extends BaseRepository {
  Future<String> sendMessages(List<AiChatMessage> messages) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/ai/chat',
        data: {
          'messages': messages
              .where((message) => message.content.trim().isNotEmpty)
              .map((message) => message.toJson())
              .toList(),
        },
        options: (await getOptionsWithToken()).copyWith(
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      final reply = response.data?['reply']?.toString().trim();
      if (reply == null || reply.isEmpty) {
        throw Exception('AI không trả về nội dung.');
      }
      return reply;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) {
        throw Exception('Bạn cần đăng nhập để sử dụng trợ lý AI.');
      }

      final data = error.response?.data;
      final message =
          data is Map<String, dynamic> ? data['message']?.toString() : null;
      throw Exception(
        message?.isNotEmpty == true
            ? message
            : 'Không thể kết nối với trợ lý AI. Vui lòng thử lại.',
      );
    }
  }
}
