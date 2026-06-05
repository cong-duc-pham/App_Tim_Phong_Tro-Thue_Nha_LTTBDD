import '../../services/api_service.dart';

class UrlHelper {
  /// Chuẩn hóa URL ảnh/file từ backend.
  /// Nếu URL trỏ về localhost hoặc IP máy ảo (10.0.2.2) nhưng ứng dụng đang dùng production/Azure,
  /// hàm sẽ tự động đổi phần domain cục bộ thành địa chỉ Azure đang hoạt động.
  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    
    // Lấy domain chính từ defaultBaseUrl (loại bỏ phần /api ở cuối)
    final host = ApiService.defaultBaseUrl.replaceAll('/api', '');

    // Nếu là URL tuyệt đối cục bộ (do lưu từ lúc chạy local)
    if (url.startsWith('http://10.0.2.2:61795') || url.startsWith('http://localhost:61795')) {
      return url
          .replaceAll('http://10.0.2.2:61795', host)
          .replaceAll('http://localhost:61795', host);
    }
    
    // Nếu là URL tương đối (ví dụ: /uploads/...)
    if (url.startsWith('/uploads')) {
      return '$host$url';
    }
    
    return url;
  }
}
