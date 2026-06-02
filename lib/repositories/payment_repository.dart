// lib/repositories/payment_repository.dart

import 'package:dio/dio.dart';
import 'base_repository.dart';

class PaymentRepository extends BaseRepository {
  PaymentRepository({super.apiService});

  /// Kiểm tra trạng thái thanh toán của hóa đơn.
  Future<String> checkPaymentStatus(int invoiceId) async {
    try {
      final options = await getOptionsWithToken();
      final response = await dio.get<Map<String, dynamic>>(
        '/packages/my-invoices',
        options: options,
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is List) {
        for (var item in data) {
          if (item['id'] == invoiceId || item['Id'] == invoiceId) {
            return item['paymentStatus'] ?? item['PaymentStatus'] ?? 'Pending';
          }
        }
      }
      return 'Pending';
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  /// Trực tiếp kích hoạt thanh toán thành công thông qua webhook/callback thủ công trong môi trường Dev/Test.
  Future<void> simulatePaymentCallback({
    required String transactionRef,
    required String gateway, // momo or vnpay
  }) async {
    try {
      await dio.get<Map<String, dynamic>>(
        '/payment/$gateway/callback',
        queryParameters: {
          'transactionRef': transactionRef,
        },
      );
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  String _readBackendMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'] ?? data['Message'];
      if (message != null) return message.toString();
    }
    if (data is String && data.trim().isNotEmpty) {
      return data;
    }
    return e.message ?? 'Lỗi kết nối máy chủ.';
  }
}
