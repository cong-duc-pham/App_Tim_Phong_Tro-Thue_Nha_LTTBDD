import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../core/constants/app_constants.dart';
import 'base_repository.dart';

class ListingRealtimeRepository extends BaseRepository {
  ListingRealtimeRepository({super.apiService});

  HubConnection? _hubConnection;
  bool _isConnecting = false;

  bool get isConnected =>
      _hubConnection?.state == HubConnectionState.Connected;

  Future<void> connect({
    required void Function(Map<String, dynamic> event) onListingsChanged,
  }) async {
    if (isConnected) return;
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyUserToken) ?? '';
      final hubUrl = dio.options.baseUrl.replaceAll('/api', '/hubs/listings');

      _hubConnection = HubConnectionBuilder()
          .withUrl(
            hubUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () async => token,
              transport: HttpTransportType.WebSockets,
            ),
          )
          .withAutomaticReconnect()
          .build();

      _hubConnection!.on('ListingsChanged', (arguments) {
        if (arguments == null || arguments.isEmpty) return;
        final raw = arguments.first;
        if (raw is Map<String, dynamic>) {
          onListingsChanged(raw);
        } else if (raw is Map) {
          onListingsChanged(Map<String, dynamic>.from(raw));
        }
      });

      await _hubConnection!.start();
    } catch (_) {
      _hubConnection = null;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> disconnect() async {
    final connection = _hubConnection;
    _hubConnection = null;
    if (connection != null) {
      await connection.stop();
    }
  }
}
