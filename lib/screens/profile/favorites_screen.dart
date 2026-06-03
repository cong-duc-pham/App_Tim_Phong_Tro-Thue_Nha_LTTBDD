// lib/screens/profile/favorites_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/profile_theme.dart';
import '../../models/listing.dart';
import '../../repositories/favorite_repository.dart';
import '../../services/api_service.dart';

// â”€â”€â”€ Model â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class FavoriteListing {
  final String id;
  final String title;
  final String address;
  final double price;
  final double area;
  final String type;
  final bool isVerified;
  final bool isNew;
  final List<String> tags;
  final Color bgColor;
  final String emoji;
  final String? imageUrl;
  final DateTime savedAt;

  const FavoriteListing({
    required this.id,
    required this.title,
    required this.address,
    required this.price,
    required this.area,
    required this.type,
    this.isVerified = false,
    this.isNew = false,
    this.tags = const [],
    required this.bgColor,
    required this.emoji,
    this.imageUrl,
    required this.savedAt,
  });
}

// â”€â”€â”€ Mock data â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/*
final _mockFavorites = [
  FavoriteListing(
    id: '1',
    title: 'PhÃ²ng Ä‘áº¹p full ná»™i tháº¥t BÃ¬nh Tháº¡nh',
    address: 'BÃ¬nh Tháº¡nh, TP.HCM',
    price: 3500000,
    area: 25,
    type: 'PhÃ²ng trá» SV',
    isVerified: true,
    tags: ['Wifi', 'Äiá»u hÃ²a', 'Ban cÃ´ng'],
    bgColor: AppColors.illus1,
    emoji: 'ðŸ›‹ï¸',
    savedAt: DateTime(2026, 5, 10),
  ),
  FavoriteListing(
    id: '2',
    title: 'Studio cao cáº¥p Quáº­n 1 view Ä‘áº¹p',
    address: 'Quáº­n 1, TP.HCM',
    price: 5200000,
    area: 30,
    type: 'CÄƒn há»™ DV',
    isNew: true,
    tags: ['Thang mÃ¡y', 'Báº£o vá»‡'],
    bgColor: AppColors.illus2,
    emoji: 'ðŸ¢',
    savedAt: DateTime(2026, 5, 8),
  ),
  FavoriteListing(
    id: '3',
    title: 'PhÃ²ng gáº§n ÄH BÃ¡ch Khoa yÃªn tÄ©nh',
    address: 'Quáº­n 10, TP.HCM',
    price: 2800000,
    area: 20,
    type: 'PhÃ²ng trá» SV',
    tags: ['Wifi', 'MÃ¡y giáº·t'],
    bgColor: AppColors.illus3,
    emoji: 'ðŸ ',
    savedAt: DateTime(2026, 5, 5),
  ),
  FavoriteListing(
    id: '4',
    title: 'NhÃ  nguyÃªn cÄƒn GÃ² Váº¥p 3 phÃ²ng ngá»§',
    address: 'GÃ² Váº¥p, TP.HCM',
    price: 12000000,
    area: 70,
    type: 'NhÃ  nguyÃªn cÄƒn',
    isVerified: true,
    tags: ['SÃ¢n vÆ°á»n', 'Wifi', 'MÃ¡y giáº·t'],
    bgColor: AppColors.illus4,
    emoji: 'ðŸ¡',
    savedAt: DateTime(2026, 5, 1),
  ),
  FavoriteListing(
    id: '5',
    title: 'CÄƒn há»™ dá»‹ch vá»¥ TÃ¢n BÃ¬nh Ä‘áº§y Ä‘á»§ tiá»‡n nghi',
    address: 'TÃ¢n BÃ¬nh, TP.HCM',
    price: 6500000,
    area: 35,
    type: 'CÄƒn há»™ DV',
    isVerified: true,
    tags: ['Äiá»u hÃ²a', 'Thang mÃ¡y'],
    bgColor: AppColors.illus2,
    emoji: 'ðŸ¢',
    savedAt: DateTime(2026, 4, 28),
  ),
];

// â”€â”€â”€ Sort options â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

*/
enum _SortOption { newest, priceAsc, priceDesc, areaAsc }

extension _SortOptionExt on _SortOption {
  String get label {
    switch (this) {
      case _SortOption.newest:
        return 'favorites_sort_newest'.tr;
      case _SortOption.priceAsc:
        return 'favorites_sort_price_asc'.tr;
      case _SortOption.priceDesc:
        return 'favorites_sort_price_desc'.tr;
      case _SortOption.areaAsc:
        return 'favorites_sort_area'.tr;
    }
  }
}

// â”€â”€â”€ Vietnamese diacritic normalization â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

String _removeDiacritics(String s) {
  const map = {
    'àáâãăắặằẳẵấầẩẫậ': 'a',
    'èéêẹẻẽếềểễệ': 'e',
    'ìíîïỉịĩ': 'i',
    'òóôõọỏốồổỗộớờởỡợ': 'o',
    'ùúûụủứừửữựũ': 'u',
    'ýỳỷỹỵ': 'y',
    'đ': 'd',
  };
  String result = s.toLowerCase();
  map.forEach((chars, replacement) {
    for (final ch in chars.split('')) {
      result = result.replaceAll(ch, replacement);
    }
  });
  return result;
}

// â”€â”€â”€ FavoritesScreen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  final FavoriteRepository _favoriteRepository = FavoriteRepository();
  final List<FavoriteListing> _favorites = [];
  final Set<String> _removingIds = {};
  _SortOption _sort = _SortOption.newest;
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;
  late final AnimationController _emptyAnim;

  @override
  void initState() {
    super.initState();
    _emptyAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _loadFavorites();
  }

  @override
  void dispose() {
    _emptyAnim.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final listings = await _favoriteRepository.getFavorites();
      if (!mounted) return;
      setState(() {
        _favorites
          ..clear()
          ..addAll(listings.map(_toFavoriteListing));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _cleanError(e);
        _isLoading = false;
      });
    }
  }

  FavoriteListing _toFavoriteListing(Listing listing) {
    return FavoriteListing(
      id: listing.listingId.toString(),
      title: listing.title.isNotEmpty
          ? listing.title
          : 'favorites_default_title'.tr,
      address: listing.displayAddress,
      price: listing.price,
      area: listing.area,
      type: listing.typeName.isNotEmpty
          ? listing.typeName
          : 'favorites_default_type'.tr,
      isVerified: listing.isVerified,
      isNew: _isNewListing(listing.createdAt),
      tags: listing.amenityNames.take(4).toList(),
      bgColor: _colorForType(listing.typeId),
      emoji: _emojiForType(listing.typeName),
      imageUrl: _resolveImageUrl(listing.image0),
      savedAt: listing.createdAt ?? DateTime.now(),
    );
  }

  bool _isNewListing(DateTime? date) {
    if (date == null) return false;
    return DateTime.now().difference(date).inDays <= 7;
  }

  Color _colorForType(int typeId) {
    switch (typeId) {
      case 2:
        return AppColors.illus2;
      case 3:
        return AppColors.illus3;
      case 4:
        return AppColors.illus4;
      default:
        return AppColors.illus1;
    }
  }

  String _emojiForType(String type) {
    final normalized = _removeDiacritics(type);
    if (normalized.contains('can ho')) return '🏢';
    if (normalized.contains('nha')) return '🏠';
    if (normalized.contains('ghep')) return '👥';
    return '🛋️';
  }

  String? _resolveImageUrl(String? url) {
    final raw = url?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

    final origin =
        ApiService.defaultBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    final path = raw.startsWith('/') ? raw : '/$raw';
    return '$origin$path';
  }

  String _cleanError(Object e) {
    final message = e.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  List<FavoriteListing> get _filtered {
    var list = List<FavoriteListing>.from(_favorites);
    if (_searchQuery.isNotEmpty) {
      final q = _removeDiacritics(_searchQuery);
      list = list
          .where((e) =>
              _removeDiacritics(e.title).contains(q) ||
              _removeDiacritics(e.address).contains(q) ||
              _removeDiacritics(e.type).contains(q) ||
              e.tags.any((t) => _removeDiacritics(t).contains(q)))
          .toList();
    }
    switch (_sort) {
      case _SortOption.newest:
        list.sort((a, b) => b.savedAt.compareTo(a.savedAt));
        break;
      case _SortOption.priceAsc:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case _SortOption.priceDesc:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case _SortOption.areaAsc:
        list.sort((a, b) => a.area.compareTo(b.area));
        break;
    }
    return list;
  }

  Future<void> _removeFavorite(String id) async {
    final originalIndex = _favorites.indexWhere((e) => e.id == id);
    if (originalIndex == -1) return;
    final removedItem = _favorites[originalIndex];

    setState(() => _removingIds.add(id));
    try {
      final isStillFavorite =
          await _favoriteRepository.toggleFavorite(int.parse(id));
      if (!mounted) return;
      if (isStillFavorite) {
        await _loadFavorites();
        return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _removingIds.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_cleanError(e)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
      ));
      return;
    }
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final currentIndex = _favorites.indexWhere((e) => e.id == id);
      if (currentIndex == -1) return;
      setState(() {
        _favorites.removeAt(currentIndex);
        _removingIds.remove(id);
      });
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.favorite_border_rounded,
              color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text('favorites_removed'.tr),
        ]),
        backgroundColor: AppColors.textDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
        action: SnackBarAction(
          label: 'favorites_undo'.tr,
          textColor: AppColors.primaryLight,
          onPressed: () async {
            setState(() {
              final restoreIndex = originalIndex.clamp(0, _favorites.length);
              _favorites.insert(restoreIndex, removedItem);
            });
            try {
              await _favoriteRepository.toggleFavorite(int.parse(id));
            } catch (e) {
              setState(() {
                _favorites.removeWhere((e) => e.id == id);
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(_cleanError(e)),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                ));
              }
            }
          },
        ),
      ));
    });
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SortSheet(
        current: _sort,
        onSelect: (s) => setState(() => _sort = s),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      final m = price / 1000000;
      return '${m % 1 == 0 ? m.toInt() : m.toStringAsFixed(1)}tr';
    }
    return '${price.toInt()}đ';
  }

  String _formatSavedDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'today'.tr;
    if (diff == 1) return 'yesterday'.tr;
    if (diff < 7) return 'days_ago'.tr.replaceAll('{days}', '$diff');
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Scaffold(
      backgroundColor: context.profileBg,
      body: Column(children: [
        _buildHeader(list.length),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _errorMessage != null
                  ? _buildErrorState()
                  : _favorites.isEmpty
                      ? _buildEmptyState()
                      : Column(children: [
                          _buildSearchAndSort(),
                          Expanded(
                            child: list.isEmpty
                                ? _buildNoResult()
                                : _buildList(list),
                          ),
                        ]),
        ),
      ]),
    );
  }

  // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildHeader(int count) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.go('/home'),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Text('favorites_title'.tr,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
              const Spacer(),
              if (_favorites.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusFull),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.favorite_rounded,
                        size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('$count',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        )),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 20),
          Container(
            height: 20,
            decoration: BoxDecoration(
              color: context.profileBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
        ]),
      ),
    );
  }

  // â”€â”€ Search & Sort bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildSearchAndSort() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(children: [
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: context.profileInputFill,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: context.profileBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Icon(Icons.search_rounded,
                  size: 18, color: context.profileTextMuted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  style: TextStyle(fontSize: 13, color: context.profileText),
                  decoration: InputDecoration(
                    hintText: 'favorites_search_hint'.tr,
                    hintStyle: TextStyle(
                        fontSize: 13, color: context.profileTextMuted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _showSortSheet,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.profileInputFill,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: context.profileBorder),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.sort_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(_sort.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  )),
            ]),
          ),
        ),
      ]),
    );
  }

  // â”€â”€ List â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildList(List<FavoriteListing> list) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final item = list[i];
        final removing = _removingIds.contains(item.id);
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: removing ? 0.0 : 1.0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 300),
            offset: removing ? const Offset(0.3, 0) : Offset.zero,
            child: _FavoriteCard(
              item: item,
              savedLabel: _formatSavedDate(item.savedAt),
              priceLabel: _formatPrice(item.price),
              onRemove: () {
                _removeFavorite(item.id);
              },
            ),
          ),
        );
      },
    );
  }

  // â”€â”€ Empty states â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingH),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.errorBg,
              borderRadius: BorderRadius.circular(AppConstants.radiusXxl),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.error,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'favorites_load_error'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.profileText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'favorites_retry_desc'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: context.profileTextMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadFavorites,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('favorites_retry'.tr),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingH),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _emptyAnim,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, -6 * _emptyAnim.value),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(AppConstants.radiusXxl),
                ),
                alignment: Alignment.center,
                child: const Text('ðŸ’”', style: TextStyle(fontSize: 44)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('favorites_empty_title'.tr,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.profileText,
              )),
          const SizedBox(height: 8),
          Text(
            'favorites_empty_desc'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: context.profileTextMuted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: Text('favorites_find_now'.tr),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildNoResult() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppConstants.radiusXl),
          ),
          alignment: Alignment.center,
          child: const Text('ðŸ”', style: TextStyle(fontSize: 32)),
        ),
        const SizedBox(height: 16),
        Text('favorites_no_result'.tr,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.profileText,
            )),
        const SizedBox(height: 6),
        Text('favorites_try_other'.tr,
            style: TextStyle(fontSize: 13, color: context.profileTextMuted)),
      ]),
    );
  }
}

// â”€â”€â”€ Favorite Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _FavoriteCard extends StatelessWidget {
  final FavoriteListing item;
  final String savedLabel;
  final String priceLabel;
  final VoidCallback onRemove;

  const _FavoriteCard({
    required this.item,
    required this.savedLabel,
    required this.priceLabel,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/listing/${item.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.profileCard,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(color: context.profileBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image section
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppConstants.radiusLg),
              ),
              child: Container(
                height: 150,
                width: double.infinity,
                color: item.bgColor,
                alignment: Alignment.center,
                child: item.imageUrl == null
                    ? Text(item.emoji, style: const TextStyle(fontSize: 52))
                    : Image.network(
                        item.imageUrl!,
                        width: double.infinity,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Text(
                            item.emoji,
                            style: const TextStyle(fontSize: 52),
                          );
                        },
                      ),
              ),
            ),
            // Type badge
            Positioned(
              top: 10,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Text(item.type,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    )),
              ),
            ),
            // NEW badge
            if (item.isNew)
              Positioned(
                top: 10,
                left: item.type.isNotEmpty ? null : 12,
                right: 48,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.tagNew,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: Text('favorites_new_badge'.tr,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                ),
              ),
            // Remove button
            Positioned(
              top: 10,
              right: 12,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.favorite_rounded,
                      size: 17, color: AppColors.error),
                ),
              ),
            ),
            // Saved date bottom-left
            Positioned(
              bottom: 10,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.bookmark_rounded,
                      size: 11, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('${'favorites_saved_time'.tr} $savedLabel',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      )),
                ]),
              ),
            ),
          ]),

          // Info section
          Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.profileText,
                    height: 1.3,
                  )),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.location_on_rounded,
                    size: 13, color: context.profileTextMuted),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(item.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.profileTextSecondary,
                      )),
                ),
              ]),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Price + area
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(children: [
                            TextSpan(
                                text: priceLabel,
                                style: AppTextStyles.cardPrice),
                            TextSpan(
                                text: 'favorites_month_suffix'.tr,
                                style: AppTextStyles.cardPriceSub.copyWith(
                                  color: context.profileTextMuted,
                                )),
                          ]),
                        ),
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.straighten_rounded,
                              size: 12, color: context.profileTextMuted),
                          const SizedBox(width: 3),
                          Text('${item.area.toInt()} m²',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.profileTextMuted,
                              )),
                        ]),
                      ]),
                  // Verified + Contact
                  Row(children: [
                    if (item.isVerified) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusSm),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.verified_rounded,
                              size: 12, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Text('favorites_verified'.tr,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              )),
                        ]),
                      ),
                      const SizedBox(width: 8),
                    ],
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusMd),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.phone_rounded,
                              size: 13, color: Colors.white),
                          const SizedBox(width: 5),
                          Text('favorites_contact'.tr,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              )),
                        ]),
                      ),
                    ),
                  ]),
                ],
              ),
              // Tags
              if (item.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Divider(height: 1, color: context.profileBorder),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: item.tags
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.infoBg,
                              borderRadius:
                                  BorderRadius.circular(AppConstants.radiusSm),
                              border: Border.all(
                                  color: AppColors.info.withValues(alpha: 0.2)),
                            ),
                            child: Text(t,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.info,
                                )),
                          ))
                      .toList(),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// â”€â”€â”€ Sort Sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SortSheet extends StatelessWidget {
  final _SortOption current;
  final ValueChanged<_SortOption> onSelect;

  const _SortSheet({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXxl)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.profileBorder,
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('favorites_sort_by'.tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.profileText,
                  )),
            ),
          ),
          ..._SortOption.values.map((opt) {
            final selected = opt == current;
            return InkWell(
              onTap: () {
                onSelect(opt);
                Navigator.pop(context);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(children: [
                  Expanded(
                    child: Text(opt.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w400,
                          color: selected
                              ? AppColors.primary
                              : context.profileText,
                        )),
                  ),
                  if (selected)
                    const Icon(Icons.check_rounded,
                        size: 18, color: AppColors.primary),
                ]),
              ),
            );
          }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
