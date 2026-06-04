// lib/repositories/package_repository.dart

import 'package:dio/dio.dart';
import 'base_repository.dart';
import '../models/post_package.dart';
import '../models/payment.dart';

class PayOsSyncUnavailableException implements Exception {
  const PayOsSyncUnavailableException();
}

class PackageRepository extends BaseRepository {
  PackageRepository({super.apiService});

  /// Lấy danh sách các gói tin đăng VIP.
  Future<List<PostPackage>> getPackages() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/packages',
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! List) {
        return const [];
      }

      final packages = data
          .whereType<Map>()
          .map((item) => PostPackage.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      packages.sort((a, b) => a.price.compareTo(b.price));
      return packages;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw const PayOsSyncUnavailableException();
      }
      throw Exception(_readBackendMessage(e));
    }
  }

  /// Thực hiện mua gói VIP cho một tin đăng (tạo hóa đơn chờ thanh toán).
  Future<Invoice> purchasePackage({
    required int listingId,
    required int packageId,
  }) async {
    try {
      final options = await getOptionsWithToken();
      final response = await dio.post<Map<String, dynamic>>(
        '/packages/purchase',
        data: {
          'listingId': listingId,
          'packageId': packageId,
        },
        options: options,
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! Map) {
        throw Exception('Không thể tạo hóa đơn mua gói VIP.');
      }

      return Invoice.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  /// Mô phỏng thanh toán Momo (dùng trong môi trường Dev/Test)
  Future<void> simulateMomoPayment(String invoiceCode) async {
    try {
      final options = await getOptionsWithToken();
      await dio.post<Map<String, dynamic>>(
        '/packages/simulate-momo-payment',
        data: {'invoiceCode': invoiceCode},
        options: options,
      );
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  /// Lấy danh sách các hóa đơn mua gói VIP của tôi.
  Future<List<Invoice>> getMyInvoices() async {
    try {
      final options = await getOptionsWithToken();
      final response = await dio.get<Map<String, dynamic>>(
        '/packages/my-invoices',
        options: options,
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! List) {
        return const [];
      }

      final invoices = data
          .whereType<Map>()
          .map((item) => Invoice.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      return _syncPendingPayOsInvoices(invoices);
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<List<Invoice>> _syncPendingPayOsInvoices(
      List<Invoice> invoices) async {
    if (invoices.isEmpty) return invoices;

    final result = <Invoice>[];
    for (final invoice in invoices) {
      if (_shouldSyncPayOs(invoice)) {
        try {
          result.add(await syncPayOsInvoice(invoice.invoiceCode));
          continue;
        } catch (_) {
          // Keep the cached invoice if PayOS is temporarily unreachable.
        }
      }
      result.add(invoice);
    }
    return result;
  }

  bool _shouldSyncPayOs(Invoice invoice) {
    final method = invoice.paymentMethod?.toLowerCase().trim();
    return invoice.statusId == 1 &&
        (method == 'payos' ||
            invoice.paymentUrl?.isNotEmpty == true ||
            invoice.paymentQrCode?.isNotEmpty == true);
  }

  Future<Invoice> syncPayOsInvoice(String invoiceCode) async {
    try {
      final options = await getOptionsWithToken();
      final response = await dio.post<Map<String, dynamic>>(
        '/packages/invoices/$invoiceCode/sync-payos',
        options: options,
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! Map) {
        throw Exception('Không thể đồng bộ trạng thái thanh toán PayOS.');
      }

      return Invoice.fromJson(Map<String, dynamic>.from(data));
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
