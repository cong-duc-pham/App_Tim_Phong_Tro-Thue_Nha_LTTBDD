import 'package:flutter/foundation.dart';

class PostListingDraftService {
  PostListingDraftService._();

  static final ValueNotifier<bool> hasDraft = ValueNotifier<bool>(false);

  static void markDirty() {
    if (!hasDraft.value) hasDraft.value = true;
  }

  static void clear() {
    if (hasDraft.value) hasDraft.value = false;
  }
}
