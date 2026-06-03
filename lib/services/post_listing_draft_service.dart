import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PostListingDraftService {
  PostListingDraftService._();

  static const String _keyDraft = 'post_listing_draft';
  static final ValueNotifier<bool> hasDraft = ValueNotifier<bool>(false);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    hasDraft.value = prefs.containsKey(_keyDraft);
  }

  static void markDirty() {
    if (!hasDraft.value) hasDraft.value = true;
  }

  static Future<void> saveDraft(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDraft, jsonEncode(data));
    markDirty();
  }

  static Future<Map<String, dynamic>?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyDraft);
    if (jsonStr == null) return null;
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDraft);
    if (hasDraft.value) hasDraft.value = false;
  }
}

