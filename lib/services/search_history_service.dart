import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  // Key lưu trữ lịch sử trong SharedPreferences
  static const String _keySearchHistory = 'search_history_list';

  // Lấy danh sách lịch sử tìm kiếm
  static Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keySearchHistory) ?? [];
  }

  // Thêm một từ khóa mới vào lịch sử
  static Future<void> addHistory(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keySearchHistory) ?? [];

    // Nếu từ khóa đã có, xóa đi để đưa lên đầu danh sách (gần đây nhất)
    list.remove(cleanQuery);
    list.insert(0, cleanQuery);

    // Chỉ giữ lại tối đa 15 từ khóa gần nhất để tối ưu bộ nhớ
    if (list.length > 15) {
      list.removeRange(15, list.length);
    }

    await prefs.setStringList(_keySearchHistory, list);
  }

  // Xóa một từ khóa khỏi lịch sử
  static Future<void> removeHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keySearchHistory) ?? [];
    list.remove(query);
    await prefs.setStringList(_keySearchHistory, list);
  }

  // Xóa toàn bộ lịch sử tìm kiếm
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySearchHistory);
  }
}
