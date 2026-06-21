import '../models/location_option.dart';
import '../services/api_service.dart';

class LocationRepository {
  LocationRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<List<LocationOption>> getProvinces() => _getLocations(
        '/locations/provinces',
        idKey: 'provinceId',
        nameKey: 'provinceName',
      );

  Future<List<LocationOption>> getDistricts(int provinceId) => _getLocations(
        '/locations/districts/$provinceId',
        idKey: 'districtId',
        nameKey: 'districtName',
        parentIdKey: 'provinceId',
      );

  Future<List<LocationOption>> getWards(int districtId) => _getLocations(
        '/locations/wards/$districtId',
        idKey: 'wardId',
        nameKey: 'wardName',
        parentIdKey: 'districtId',
      );

  Future<List<LocationOption>> _getLocations(
    String path, {
    required String idKey,
    required String nameKey,
    String? parentIdKey,
  }) async {
    final response = await _apiService.dio.get<Map<String, dynamic>>(path);
    final body = response.data ?? const <String, dynamic>{};
    final data = body['data'] ?? body['Data'];
    if (data is! List) return const [];

    return data
        .whereType<Map>()
        .map((item) => LocationOption.fromJson(
              Map<String, dynamic>.from(item),
              idKey: idKey,
              nameKey: nameKey,
              parentIdKey: parentIdKey,
            ))
        .where((item) => item.id > 0 && item.name.isNotEmpty)
        .toList();
  }
}
