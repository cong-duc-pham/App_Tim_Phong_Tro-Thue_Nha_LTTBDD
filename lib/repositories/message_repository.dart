// lib/repositories/message_repository.dart

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../core/constants/app_constants.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import 'base_repository.dart';

class MessageRepository extends BaseRepository {
  MessageRepository({super.apiService});

  HubConnection? _hubConnection;
  bool _isConnecting = false;

  /// Lấy danh sách hội thoại của user hiện tại.
  Future<List<Conversation>> getConversations() async {
    try {
      final options = await getOptionsWithToken();
      final response = await dio.get<Map<String, dynamic>>(
        '/conversations',
        options: options,
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! List) {
        return const [];
      }

      return data
          .whereType<Map>()
          .map((item) => Conversation.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  /// Tạo hoặc lấy conversation đã tồn tại giữa tenant và landlord cho một tin đăng.
  Future<Conversation> createConversation({
    required int landlordId,
    required int listingId,
  }) async {
    try {
      final options = await getOptionsWithToken();
      final response = await dio.post<Map<String, dynamic>>(
        '/conversations',
        data: {
          'landlordId': landlordId,
          'listingId': listingId,
        },
        options: options,
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! Map) {
        throw Exception('Không tìm thấy dữ liệu cuộc hội thoại.');
      }

      return Conversation.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  /// Lấy lịch sử tin nhắn của cuộc hội thoại (có phân trang).
  Future<List<Message>> getMessages(int convId, {int page = 1}) async {
    try {
      final options = await getOptionsWithToken();
      final response = await dio.get<Map<String, dynamic>>(
        '/conversations/$convId/messages',
        queryParameters: {'page': page},
        options: options,
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! List) {
        return const [];
      }

      return data
          .whereType<Map>()
          .map((item) => Message.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  /// Trả về trạng thái kết nối hiện tại của SignalR Hub.
  bool get isConnected => _hubConnection?.state == HubConnectionState.Connected;

  /// Kết nối đến SignalR Chat Hub (/hubs/chat).
  Future<void> connectToChatHub({
    required void Function(Message message) onMessageReceived,
    required void Function(Message message) onMessageSentConfirm,
    required void Function(int convId) onMessagesReadByOther,
    void Function(bool isConnected)? onConnectionStateChanged,
  }) async {
    if (_hubConnection != null &&
        _hubConnection!.state == HubConnectionState.Connected) {
      onConnectionStateChanged?.call(true);
      return;
    }
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyUserToken) ?? '';
      if (token.isEmpty) {
        _isConnecting = false;
        onConnectionStateChanged?.call(false);
        return;
      }

      // Tạo hub url dựa vào baseUrl của ApiService (loại bỏ phần /api)
      String hubUrl = dio.options.baseUrl.replaceAll('/api', '/hubs/chat');

      // Khởi tạo hub connection
      // Dùng cả WebSockets lẫn LongPolling để hỗ trợ Azure App Service
      _hubConnection = HubConnectionBuilder()
          .withUrl(
            hubUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () async => token,
              transport: HttpTransportType.LongPolling,
            ),
          )
          .withAutomaticReconnect()
          .build();

      _hubConnection!.onreconnecting(({error}) {
        onConnectionStateChanged?.call(false);
      });

      _hubConnection!.onreconnected(({connectionId}) {
        onConnectionStateChanged?.call(true);
      });

      // Đăng ký các sự kiện callback từ Hub
      _hubConnection!.on("ReceiveMessage", (arguments) {
        if (arguments != null && arguments.isNotEmpty) {
          final rawMsg = arguments[0];
          if (rawMsg is Map) {
            onMessageReceived(
              Message.fromJson(Map<String, dynamic>.from(rawMsg)),
            );
          }
        }
      });

      _hubConnection!.on("MessageSent", (arguments) {
        if (arguments != null && arguments.isNotEmpty) {
          final rawMsg = arguments[0];
          if (rawMsg is Map) {
            onMessageSentConfirm(
              Message.fromJson(Map<String, dynamic>.from(rawMsg)),
            );
          }
        }
      });

      _hubConnection!.on("MessagesRead", (arguments) {
        if (arguments != null && arguments.isNotEmpty) {
          final convId = (arguments[0] as num?)?.toInt();
          if (convId != null) {
            onMessagesReadByOther(convId);
          }
        }
      });

      _hubConnection!.onclose(({error}) {
        _isConnecting = false;
        onConnectionStateChanged?.call(false);
      });

      await _hubConnection!.start();
      onConnectionStateChanged?.call(true);
    } catch (e) {
      _hubConnection = null;
      onConnectionStateChanged?.call(false);
    } finally {
      _isConnecting = false;
    }
  }

  /// Gửi tin nhắn real-time thông qua SignalR Hub.
  Future<void> sendMessage({
    required int convId,
    required String content,
    String msgType = "text",
    String? fileUrl,
  }) async {
    if (_hubConnection == null ||
        _hubConnection!.state != HubConnectionState.Connected) {
      throw Exception(
          'Không có kết nối mạng thời gian thực. Vui lòng thử lại sau.');
    }

    try {
      await _hubConnection!.invoke(
        "SendMessage",
        args: <Object>[convId, content, msgType, fileUrl ?? ""],
      );
    } catch (e) {
      throw Exception('Không gửi được tin nhắn: $e');
    }
  }

  /// Đánh dấu đã đọc toàn bộ tin nhắn trong cuộc hội thoại.
  Future<void> markAsRead(int convId) async {
    if (_hubConnection == null ||
        _hubConnection!.state != HubConnectionState.Connected) {
      return;
    }

    try {
      await _hubConnection!.invoke(
        "MarkAsRead",
        args: [convId],
      );
    } catch (_) {
      // Bỏ qua lỗi khi đánh dấu đã đọc
    }
  }

  /// Ngắt kết nối SignalR Hub.
  Future<void> disconnectFromChatHub() async {
    if (_hubConnection != null) {
      await _hubConnection!.stop();
      _hubConnection = null;
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
