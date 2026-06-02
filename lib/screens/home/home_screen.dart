// lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/listing.dart';
import '../../repositories/favorite_repository.dart';
import '../../repositories/listing_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../services/api_service.dart';
import '../../services/search_history_service.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class ListingItem {
  final String id;
  final String title;
  final String address;
  final double price;
  final double area;
  final bool isVerified;
  final bool isFeatured;
  final bool isNew;
  final bool allowPet;
  final String status;
  final String? badgeLabel;
  final Color? badgeColor;
  final bool allowBanner;
  final List<String> tags;
  final Color bgColor;
  final String type; // 'phong-tro' | 'can-ho' | 'o-ghep' | 'nha-nguyen-can'
  final String? imageUrl;
  final String? provinceName;

  const ListingItem({
    required this.id,
    required this.title,
    required this.address,
    required this.price,
    required this.area,
    this.isVerified = false,
    this.isFeatured = false,
    this.isNew = false,
    this.allowPet = false,
    this.status = 'available',
    this.badgeLabel,
    this.badgeColor,
    this.allowBanner = false,
    this.tags = const [],
    required this.bgColor,
    this.type = 'phong-tro',
    this.imageUrl,
    this.provinceName,
  });
}

// ─── Dữ liệu mẫu ─────────────────────────────────────────────────────────────

final _allListings = [
  const ListingItem(
    id: '1',
    title: 'Phòng đẹp full nội thất Bình Thạnh',
    address: 'Bình Thạnh, TP.HCM',
    price: 3500000,
    area: 25,
    isVerified: true,
    isFeatured: true,
    type: 'phong-tro',
    tags: ['Wifi', 'Điều hòa', 'Ban công'],
    bgColor: AppColors.illus1,
  ),
  const ListingItem(
    id: '2',
    title: 'Studio cao cấp Quận 1 view đẹp',
    address: 'Quận 1, TP.HCM',
    price: 5200000,
    area: 30,
    isVerified: true,
    isNew: true,
    type: 'can-ho',
    tags: ['Thang máy', 'Bảo vệ'],
    bgColor: AppColors.illus2,
  ),
  const ListingItem(
    id: '3',
    title: 'Phòng gần ĐH Bách Khoa yên tĩnh',
    address: 'Quận 10, TP.HCM',
    price: 2800000,
    area: 20,
    isFeatured: true,
    type: 'phong-tro',
    tags: ['Wifi', 'Máy giặt'],
    bgColor: AppColors.illus3,
  ),
  const ListingItem(
    id: '4',
    title: 'Phòng trọ sinh viên gần RMIT',
    address: 'Quận 7 · 1.2km',
    price: 2200000,
    area: 18,
    isVerified: true,
    status: 'available',
    type: 'phong-tro',
    bgColor: AppColors.illus4,
  ),
  const ListingItem(
    id: '5',
    title: 'Căn hộ dịch vụ Tân Bình đầy đủ',
    address: 'Tân Bình · 2.4km',
    price: 6500000,
    area: 35,
    isVerified: true,
    status: 'hot',
    type: 'can-ho',
    tags: ['Điều hòa', 'Thang máy'],
    bgColor: AppColors.illus2,
  ),
  const ListingItem(
    id: '6',
    title: 'Phòng ghép 2 người Thủ Đức',
    address: 'Thủ Đức · 3.1km',
    price: 1800000,
    area: 15,
    allowPet: true,
    status: 'available',
    type: 'o-ghep',
    bgColor: AppColors.illus3,
  ),
  const ListingItem(
    id: '7',
    title: 'Nhà nguyên căn Gò Vấp 3 phòng ngủ',
    address: 'Gò Vấp, TP.HCM',
    price: 12000000,
    area: 70,
    isVerified: true,
    type: 'nha-nguyen-can',
    tags: ['Sân vườn', 'Wifi', 'Máy giặt'],
    bgColor: AppColors.illus1,
  ),
  const ListingItem(
    id: '8',
    title: 'Ở ghép sinh viên phòng đôi Bình Dương',
    address: 'Bình Dương · 5km',
    price: 900000,
    area: 12,
    status: 'available',
    type: 'o-ghep',
    tags: ['Wifi'],
    bgColor: AppColors.illus4,
  ),
];

List<ListingItem> get _featuredListings =>
    _allListings.where((e) => e.isFeatured || e.isNew).toList();
List<ListingItem> get _suggestedListings =>
    _allListings.where((e) => !e.isFeatured && !e.isNew).toList();

// ─── Filter Model ─────────────────────────────────────────────────────────────

class _FilterState {
  Set<String> types;
  RangeValues priceRange;
  double maxArea;
  Set<String> amenities;

  _FilterState({
    Set<String>? types,
    RangeValues? priceRange,
    double? maxArea,
    Set<String>? amenities,
  })  : types = types ?? {},
        priceRange = priceRange ?? const RangeValues(0, 15),
        maxArea = maxArea ?? 80,
        amenities = amenities ?? {};

  bool get hasActive =>
      types.isNotEmpty ||
      priceRange.start > 0 ||
      priceRange.end < 15 ||
      maxArea < 80 ||
      amenities.isNotEmpty;

  _FilterState copyWith({
    Set<String>? types,
    RangeValues? priceRange,
    double? maxArea,
    Set<String>? amenities,
  }) =>
      _FilterState(
        types: types ?? Set.from(this.types),
        priceRange: priceRange ?? this.priceRange,
        maxArea: maxArea ?? this.maxArea,
        amenities: amenities ?? Set.from(this.amenities),
      );
}

// ─── Vietnamese diacritic normalization ─────────────────────────────────────

String _removeDiacritics(String s) {
  final map = {
    RegExp(r'[àáâãăắặằẳẵấầẩẫậ]'): 'a',
    RegExp(r'[èéêẹẻẽếềểễệ]'): 'e',
    RegExp(r'[ìíîïỉịĩ]'): 'i',
    RegExp(r'[òóôõọỏốồổỗộớờởỡợ]'): 'o',
    RegExp(r'[ùúûụủứừửữựũ]'): 'u',
    RegExp(r'[ýỳỷỹỵ]'): 'y',
    RegExp(r'[đ]'): 'd',
  };
  String result = s;
  map.forEach((regex, rep) => result = result.replaceAll(regex, rep));
  return result;
}

// ─── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final String? initialSearchQuery;
  const HomeScreen({super.key, this.initialSearchQuery});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ListingRepository _listingRepository = ListingRepository();
  final FavoriteRepository _favoriteRepository = FavoriteRepository();
  final NotificationRepository _notificationRepository =
      NotificationRepository();
  int _activeFilter = 0;
  final List<String> _filters = [
    'Gần đây',
    'Theo ngân sách',
    'Phòng mới',
    'Nuôi thú cưng',
    'VIP'
  ];
  final List<String> _savedIds = [];

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  bool _isSearching = false;

  // Filter
  _FilterState _filter = _FilterState();
  List<ListingItem> _sqlListings = [];
  bool _isLoadingListings = false;
  String? _listingLoadError;
  int _unreadNotificationCount = 0;
  String _selectedLocation = 'TP. Hồ Chí Minh';
  Set<String> _preferredTypes = {};
  Set<String> _preferredAreas = {};
  Set<String> _preferredAmenities = {};
  double? _preferredMaxBudget;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadSelectedLocation();
    _loadListingsFromSql();
    _loadFavoriteIds();
    _loadUnreadNotificationCount();
    // Tự động kích hoạt tìm kiếm nếu có từ khóa truyền từ ngoài vào (qua deep link / router)
    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery!.trim().isNotEmpty) {
      _searchCtrl.text = widget.initialSearchQuery!;
      _searchQuery = widget.initialSearchQuery!.trim().toLowerCase();
      _isSearching = true;
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _preferredTypes =
          prefs.getStringList(AppConstants.keyPreferenceTypes)?.toSet() ?? {};
      _preferredAreas =
          prefs.getStringList(AppConstants.keyPreferenceAreas)?.toSet() ?? {};
      _preferredAmenities =
          prefs.getStringList(AppConstants.keyPreferenceAmenities)?.toSet() ??
              {};
      _preferredMaxBudget =
          prefs.getDouble(AppConstants.keyPreferenceMaxBudget);
    });
  }

  Future<void> _loadSelectedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.keySelectedHomeLocation);
    if (!mounted) return;
    if (saved != null && saved.trim().isNotEmpty) {
      setState(() => _selectedLocation = saved);
    }
  }

  Future<void> _loadListingsFromSql() async {
    setState(() {
      _isLoadingListings = true;
      _listingLoadError = null;
    });

    try {
      final listings = await _listingRepository.getListings(pageSize: 30);
      if (!mounted) return;
      setState(() {
        _sqlListings = listings.map(_mapSqlListingToHomeItem).toList();
        _isLoadingListings = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listingLoadError = e.toString();
        _isLoadingListings = false;
      });
    }
  }

  Future<void> _loadFavoriteIds() async {
    try {
      final favorites = await _favoriteRepository.getFavorites();
      if (!mounted) return;
      setState(() {
        _savedIds
          ..clear()
          ..addAll(favorites.map((item) => item.listingId.toString()));
      });
    } catch (_) {
      // Người dùng chưa đăng nhập vẫn có thể xem danh sách phòng.
    }
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final count = await _notificationRepository.getUnreadCount();
      if (!mounted) return;
      setState(() => _unreadNotificationCount = count);
    } catch (_) {
      if (mounted) setState(() => _unreadNotificationCount = 0);
    }
  }

  List<ListingItem> get _listingsForUi {
    final source = _sqlListings.isEmpty ? _allListings : _sqlListings;
    if (_selectedLocation == 'Tất cả khu vực') return source;

    final selected = _normalizeLocation(_selectedLocation);
    return source.where((item) {
      final province = _normalizeLocation(item.provinceName ?? '');
      final address = _normalizeLocation(item.address);
      return _matchesLocation(province, selected) ||
          _matchesLocation(address, selected);
    }).toList();
  }

  bool _matchesLocation(String value, String selected) {
    if (selected == 'ho chi minh') {
      return value.contains('ho chi minh') ||
          value.contains('hcm') ||
          value.contains('sai gon');
    }
    return value == selected || value.contains(selected);
  }

  List<String> get _locationOptions {
    final values = <String>{
      'Tất cả khu vực',
      'TP. Hồ Chí Minh',
      'Hà Nội',
      'Đà Nẵng',
      'Cần Thơ',
      'Bình Dương',
    };

    for (final item in _sqlListings) {
      final province = item.provinceName?.trim();
      if (province != null && province.isNotEmpty) {
        values.add(province);
      }
    }

    return values.toList();
  }

  String _normalizeLocation(String value) {
    var result = _removeDiacritics(value.toLowerCase())
        .replaceAll('tp.', '')
        .replaceAll('thanh pho', '')
        .replaceAll('tinh', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (result == 'tp hcm' || result == 'hcm' || result == 'sai gon') {
      result = 'ho chi minh';
    }
    return result;
  }

  List<ListingItem> get _featuredListingsForUi {
    final featured =
        _listingsForUi.where((e) => e.isFeatured || e.isNew).toList();
    return featured.isEmpty ? _listingsForUi.take(4).toList() : featured;
  }

  List<ListingItem> get _bannerListingsForUi {
    final banner = _listingsForUi.where((e) => e.allowBanner).toList();
    return banner.isEmpty ? _featuredListingsForUi : banner;
  }

  List<ListingItem> get _suggestedListingsForUi {
    final suggested =
        _listingsForUi.where((e) => !e.isFeatured && !e.isNew).toList();
    return suggested.isEmpty ? _listingsForUi : suggested;
  }

  ListingItem _mapSqlListingToHomeItem(Listing listing) {
    final createdAt = listing.createdAt;
    final isNew = createdAt != null &&
        DateTime.now().difference(createdAt.toLocal()).inDays <= 7;
    final type = _typeKeyFromSqlListing(listing);
    final packageInfo = listing.packageInfo;
    final badgeType = _packageString(packageInfo, 'badgeType', 'BadgeType');
    final isHighlighted =
        _packageBool(packageInfo, 'isHighlighted', 'IsHighlighted');
    final allowBanner =
        _packageBool(packageInfo, 'allowBanner', 'AllowBanner');
    final hasPackage = packageInfo != null;
    final status = hasPackage ? 'hot' : 'available';
    final badgeLabel = isHighlighted || badgeType == 'featured'
        ? 'NỔI BẬT'
        : hasPackage
            ? 'VIP'
            : null;
    final badgeColor = isHighlighted || badgeType == 'featured'
        ? AppColors.tagHot
        : hasPackage
            ? AppColors.tagVip
            : null;

    return ListingItem(
      id: listing.listingId.toString(),
      title: listing.title,
      address: listing.displayAddress,
      price: listing.price,
      area: listing.area,
      isVerified: listing.isVerified,
      isFeatured: listing.isFeatured || hasPackage,
      isNew: isNew,
      allowPet: listing.allowPet,
      status: status,
      badgeLabel: badgeLabel,
      badgeColor: badgeColor,
      allowBanner: allowBanner,
      tags: listing.amenityNames,
      bgColor: _colorForType(type),
      type: type,
      imageUrl: _resolveImageUrl(listing.image0),
      provinceName: listing.provinceName,
    );
  }

  String? _packageString(
    Map<String, dynamic>? packageInfo,
    String camel,
    String pascal,
  ) {
    final value = packageInfo?[camel] ?? packageInfo?[pascal];
    return value?.toString();
  }

  bool _packageBool(
    Map<String, dynamic>? packageInfo,
    String camel,
    String pascal,
  ) {
    final value = packageInfo?[camel] ?? packageInfo?[pascal];
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString().toLowerCase() == 'true';
  }

  String? _resolveImageUrl(String? rawUrl) {
    final value = rawUrl?.trim();
    if (value == null || value.isEmpty) return null;

    final apiUri = Uri.parse(ApiService.defaultBaseUrl);
    final origin = '${apiUri.scheme}://${apiUri.authority}';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      final imageUri = Uri.tryParse(value);
      if (imageUri != null &&
          imageUri.path.startsWith('/uploads/') &&
          imageUri.port == apiUri.port) {
        return '$origin${imageUri.path}';
      }
      return value;
    }
    if (!value.startsWith('/')) return value;

    return '$origin$value';
  }

  String _typeKeyFromSqlListing(Listing listing) {
    final name = _removeDiacritics(listing.typeName.toLowerCase());
    if (name.contains('can ho') || listing.typeId == 2) return 'can-ho';
    if (name.contains('ghep') || listing.typeId == 3) return 'o-ghep';
    if (name.contains('nha') || listing.typeId == 4) return 'nha-nguyen-can';
    return 'phong-tro';
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'can-ho':
        return AppColors.illus2;
      case 'o-ghep':
        return AppColors.illus3;
      case 'nha-nguyen-can':
        return AppColors.illus4;
      default:
        return AppColors.illus1;
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cập nhật lại thanh tìm kiếm nếu từ khóa truyền vào widget thay đổi
    if (widget.initialSearchQuery != oldWidget.initialSearchQuery) {
      if (widget.initialSearchQuery != null &&
          widget.initialSearchQuery!.trim().isNotEmpty) {
        setState(() {
          _searchCtrl.text = widget.initialSearchQuery!;
          _searchQuery = widget.initialSearchQuery!.trim().toLowerCase();
          _isSearching = true;
        });
      } else if (widget.initialSearchQuery == null) {
        // Làm trống thanh tìm kiếm nếu query param bị xóa
        setState(() {
          _searchCtrl.clear();
          _searchQuery = '';
          _isSearching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _toggleSave(String id) async {
    final wasSaved = _savedIds.contains(id);
    setState(() {
      if (wasSaved) {
        _savedIds.remove(id);
      } else {
        _savedIds.add(id);
      }
    });

    try {
      final isFavorite =
          await _favoriteRepository.toggleFavorite(int.parse(id));
      if (!mounted) return;
      setState(() {
        if (isFavorite) {
          if (!_savedIds.contains(id)) _savedIds.add(id);
        } else {
          _savedIds.remove(id);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasSaved) {
          if (!_savedIds.contains(id)) _savedIds.add(id);
        } else {
          _savedIds.remove(id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_cleanBackendError(e)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
      ));
    }
  }

  String _cleanBackendError(Object e) {
    final message = e.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  Future<void> _selectLocation(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keySelectedHomeLocation, value);
    if (!mounted) return;
    setState(() => _selectedLocation = value);
  }

  void _showLocationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppConstants.radiusXxl)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusFull),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Chọn khu vực',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                ..._locationOptions.map((location) {
                  final selected = location == _selectedLocation;
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _selectLocation(location);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Icon(
                            location == 'Tất cả khu vực'
                                ? Icons.public_rounded
                                : Icons.location_on_outlined,
                            size: 20,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_rounded,
                                size: 20, color: AppColors.primary),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val.trim().toLowerCase();
      _isSearching = _searchQuery.isNotEmpty;
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _searchFocus.unfocus();
    setState(() {
      _searchQuery = '';
      _isSearching = false;
    });
  }

  List<ListingItem> get _searchResults {
    if (_searchQuery.isEmpty) return [];
    final normalized = _removeDiacritics(_searchQuery.toLowerCase());
    return _listingsForUi
        .where((e) =>
            _removeDiacritics(e.title.toLowerCase()).contains(normalized) ||
            _removeDiacritics(e.address.toLowerCase()).contains(normalized) ||
            e.tags.any(
                (t) => _removeDiacritics(t.toLowerCase()).contains(normalized)))
        .toList();
  }

  List<ListingItem> _applyFilter(List<ListingItem> src) {
    if (!_filter.hasActive) return src;
    return src.where((e) {
      if (_filter.types.isNotEmpty && !_filter.types.contains(e.type)) {
        return false;
      }
      final priceMillion = e.price / 1000000;
      if (priceMillion < _filter.priceRange.start ||
          priceMillion > _filter.priceRange.end) {
        return false;
      }
      if (e.area > _filter.maxArea) return false;
      if (_filter.amenities.isNotEmpty &&
          !_filter.amenities.any((a) => e.tags.contains(a))) {
        return false;
      }
      return true;
    }).toList();
  }

  List<ListingItem> get _personalizedSuggestedListings {
    final list = List<ListingItem>.from(_suggestedListingsForUi);
    if (!_hasSavedPreferences) return list;

    list.sort((a, b) {
      final scoreB = _preferenceScore(b);
      final scoreA = _preferenceScore(a);
      if (scoreB != scoreA) return scoreB.compareTo(scoreA);
      return a.price.compareTo(b.price);
    });
    return list;
  }

  bool get _hasSavedPreferences =>
      _preferredTypes.isNotEmpty ||
      _preferredAreas.isNotEmpty ||
      _preferredAmenities.isNotEmpty ||
      _preferredMaxBudget != null;

  int _preferenceScore(ListingItem item) {
    var score = 0;
    if (_preferredTypes.contains(item.type)) score += 5;
    if (_preferredMaxBudget != null && item.price <= _preferredMaxBudget!) {
      score += 4;
    }
    if (_preferredAreas.any((area) => item.address.contains(area))) {
      score += 3;
    }
    score += item.tags.where(_preferredAmenities.contains).length * 2;
    if (item.isVerified) score += 1;
    if (item.status == 'available') score += 1;
    return score;
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterBottomSheet(
        initial: _filter,
        onApply: (f) => setState(() => _filter = f),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              if (_isSearching) ...[
                SliverToBoxAdapter(child: _buildSearchResults()),
              ] else ...[
                SliverToBoxAdapter(child: _buildFilterChips()),
                SliverToBoxAdapter(child: _buildCategories()),
                SliverToBoxAdapter(child: _buildBanner()),
                if (_isLoadingListings) ...[
                  SliverToBoxAdapter(child: _buildListingLoading()),
                ],
                if (_listingLoadError != null && _sqlListings.isEmpty) ...[
                  SliverToBoxAdapter(child: _buildListingFallbackNotice()),
                ],
                SliverToBoxAdapter(
                    child: _buildSectionHeader('⭐  Tin nổi bật', 'Xem thêm')),
                SliverToBoxAdapter(child: _buildFeaturedCards()),
                SliverToBoxAdapter(
                    child:
                        _buildSectionHeader('🎯  Gợi ý cho bạn', 'Xem thêm')),
                if (_hasSavedPreferences) ...[
                  SliverToBoxAdapter(child: _buildPreferenceBanner()),
                ],
                if (_filter.hasActive) ...[
                  SliverToBoxAdapter(child: _buildActiveFilterBanner()),
                ],
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final list = _applyFilter(_personalizedSuggestedListings);
                      return _buildFullCard(list[i]);
                    },
                    childCount:
                        _applyFilter(_personalizedSuggestedListings).length,
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 90)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppConstants.paddingH, 4, AppConstants.paddingH, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.location_on_rounded,
                              size: 13, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text('Vị trí của bạn',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.75))),
                        ]),
                        const SizedBox(height: 2),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _showLocationSheet,
                          child: Row(children: [
                            Flexible(
                              child: Text(_selectedLocation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 18, color: Colors.white),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  _IconBtn(
                      icon: Icons.notifications_outlined,
                      badge: _unreadNotificationCount > 0,
                      onTap: () => context.go(AppConstants.routeNotifications)),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => context.go(AppConstants.routeProfile),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.25)),
                      alignment: Alignment.center,
                      child: const Text('A',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Xin chào 👋',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.85))),
              const SizedBox(height: 2),
              const Text('Bạn muốn tìm phòng nào?',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 14),
              _buildSearchBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.search_rounded,
              color: AppColors.textMuted, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              onSubmitted: (val) {
                // Lưu từ khóa tìm kiếm khi người dùng nhấn Enter/Tìm kiếm trên bàn phím
                if (val.trim().isNotEmpty) {
                  SearchHistoryService.addHistory(val.trim());
                }
              },
              style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                hintText: 'Tên đường, quận, trường học...',
                hintStyle: AppTextStyles.inputHint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          if (_isSearching) ...[
            GestureDetector(
              onTap: _clearSearch,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                    color: AppColors.textMuted, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.close, size: 13, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
          ],
          GestureDetector(
            onTap: _showFilterSheet,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: AppConstants.animFast,
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _filter.hasActive
                        ? AppColors.primary
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.tune_rounded,
                      size: 20, color: Colors.white),
                ),
                if (_filter.hasActive)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.notifDot,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Results ────────────────────────────────────────────────────────

  Widget _buildSearchResults() {
    final results = _searchResults;
    return AnimatedSwitcher(
      duration: AppConstants.animNormal,
      child: results.isEmpty
          ? _buildSearchEmpty()
          : Column(
              key: ValueKey(_searchQuery),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppConstants.paddingH, 16, AppConstants.paddingH, 8),
                  child: Text(
                    '${results.length} kết quả cho "$_searchQuery"',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                ...results.map((item) => _buildSearchResultItem(item)),
              ],
            ),
    );
  }

  Widget _buildSearchEmpty() {
    return Padding(
      key: const ValueKey('empty'),
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              ),
              alignment: Alignment.center,
              child: const Text('🔍', style: TextStyle(fontSize: 32)),
            ),
            const SizedBox(height: 16),
            const Text('Không tìm thấy kết quả',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Thử tìm với từ khóa khác\nhoặc điều chỉnh bộ lọc',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultItem(ListingItem item) {
    final saved = _savedIds.contains(item.id);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/listing/${item.id}');
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(AppConstants.paddingH, 0,
            AppConstants.paddingH, AppConstants.spacingSm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              foregroundDecoration: item.imageUrl == null
                  ? null
                  : BoxDecoration(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(AppConstants.radiusLg),
                      ),
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(item.imageUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
              decoration: BoxDecoration(
                color: item.bgColor,
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppConstants.radiusLg)),
              ),
              alignment: Alignment.center,
              child: const Text('🏠', style: TextStyle(fontSize: 26)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HighlightText(
                      text: item.title,
                      query: _searchQuery,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.location_on_rounded,
                          size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 2),
                      Expanded(
                        child: _HighlightText(
                          text: item.address,
                          query: _searchQuery,
                          style: AppTextStyles.cardAddress,
                          maxLines: 1,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(children: [
                            TextSpan(
                                text: _formatPrice(item.price),
                                style: AppTextStyles.cardPrice),
                            const TextSpan(
                                text: '/th', style: AppTextStyles.cardPriceSub),
                          ]),
                        ),
                        GestureDetector(
                          onTap: () => _toggleSave(item.id),
                          child: Icon(
                            saved
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter chips ngang ────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
            AppConstants.paddingH, 10, AppConstants.paddingH, 0),
        itemCount: _filters.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: AppConstants.spacingSm),
        itemBuilder: (_, i) {
          final active = i == _activeFilter;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = i),
            child: AnimatedContainer(
              duration: AppConstants.animFast,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                border: Border.all(
                    color: active ? AppColors.primary : AppColors.border,
                    width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (i == 0) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active
                              ? AppColors.primaryLight
                              : AppColors.success),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(_filters[i],
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color:
                              active ? Colors.white : AppColors.textSecondary)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Active filter banner ──────────────────────────────────────────────────

  Widget _buildActiveFilterBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppConstants.paddingH, 12, AppConstants.paddingH, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.filter_list_rounded,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Đang áp dụng bộ lọc',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _filter = _FilterState()),
              child: const Text(
                'Xóa lọc',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceBanner() {
    final chips = <String>[
      ..._preferredTypes.map(_typeLabel),
      ..._preferredAreas,
      if (_preferredMaxBudget != null)
        'Dưới ${(_preferredMaxBudget! / 1000000).toStringAsFixed(0)}tr',
    ].where((e) => e.isNotEmpty).take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppConstants.paddingH, 10, AppConstants.paddingH, 0),
      child: GestureDetector(
        onTap: () async {
          HapticFeedback.lightImpact();
          await context.push('${AppConstants.routePreference}?from=home');
          _loadPreferences(); // Reload preferences when user returns!
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 17, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  chips.isEmpty
                      ? 'Gợi ý đang được cá nhân hóa theo khảo sát của bạn'
                      : 'Ưu tiên: ${chips.join(' · ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Sửa',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 10,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'phong-tro':
        return 'Phòng trọ';
      case 'can-ho':
        return 'Căn hộ';
      case 'o-ghep':
        return 'Ở ghép';
      case 'nha-nguyen-can':
        return 'Nhà nguyên căn';
      default:
        return '';
    }
  }

  // ── Categories ────────────────────────────────────────────────────────────

  Widget _buildCategories() {
    final cats = [
      {
        'type': 'phong-tro',
        'icon': Icons.home_rounded,
        'label': 'Phòng trọ\nSV',
        'color': AppColors.catBlue
      },
      {
        'type': 'can-ho',
        'icon': Icons.apartment_rounded,
        'label': 'Căn hộ\nDV',
        'color': AppColors.catIndigo
      },
      {
        'type': 'o-ghep',
        'icon': Icons.people_rounded,
        'label': 'Ở ghép',
        'color': AppColors.catCyan
      },
      {
        'type': 'nha-nguyen-can',
        'icon': Icons.house_rounded,
        'label': 'Nhà\nnguyên căn',
        'color': AppColors.catSky
      },
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppConstants.paddingH,
          AppConstants.paddingV, AppConstants.paddingH, 0),
      child: Column(
        children: [
          _buildSectionHeader(
            'Loại hình',
            'Xem tất cả',
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                final updated = Set<String>.from(_filter.types)..clear();
                _filter = _filter.copyWith(types: updated);
              });
            },
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Row(
            children: cats.map((c) {
              final typeKey = c['type'] as String;
              final isSelected = _filter.types.contains(typeKey);
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      final updated = Set<String>.from(_filter.types);
                      if (isSelected) {
                        updated.remove(typeKey);
                      } else {
                        updated.clear(); // Chọn duy nhất loại này
                        updated.add(typeKey);
                      }
                      _filter = _filter.copyWith(types: updated);
                    });
                  },
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: AppConstants.animFast,
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : (c['color'] as Color),
                          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                          border: isSelected
                              ? Border.all(color: AppColors.primary, width: 2)
                              : Border.all(color: Colors.transparent, width: 2),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          c['icon'] as IconData,
                          size: AppConstants.iconLg,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c['label'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Banner ────────────────────────────────────────────────────────────────

  Widget _buildBanner() {
    final bannerItems = _applyFilter(_bannerListingsForUi);
    final bannerItem = bannerItems.isNotEmpty ? bannerItems.first : null;
    final bannerTitle = bannerItem?.title ?? 'Phong VIP gia tot';
    final bannerSubtitle = bannerItem == null
        ? 'Xac thuc - Anh thuc te - An toan'
        : '${_formatPrice(bannerItem.price)}/thang - ${bannerItem.area.toStringAsFixed(0)} m2';

    final dynamicBanner = Padding(
      padding: const EdgeInsets.fromLTRB(AppConstants.paddingH,
          AppConstants.paddingV, AppConstants.paddingH, 0),
      child: GestureDetector(
        onTap: bannerItem == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                context.push('/listing/${bannerItem.id}');
              },
        child: Container(
          decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusSm)),
                      child: const Text('HOT DEAL',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                    const SizedBox(height: 6),
                    Text(bannerTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.3)),
                    const SizedBox(height: 4),
                    Text(bannerSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ),
              _buildListingImage(
                bannerItem ??
                    const ListingItem(
                      id: 'banner-placeholder',
                      title: '',
                      address: '',
                      price: 0,
                      area: 0,
                      type: 'room',
                      bgColor: AppColors.primary,
                    ),
                width: 70,
                height: 70,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                fallbackIcon: 'home',
                fallbackIconSize: 20,
              ),
            ],
          ),
        ),
      ),
    );

    return dynamicBanner;
  }

  // ── Featured Cards ────────────────────────────────────────────────────────

  Widget _buildListingLoading() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppConstants.paddingH,
        AppConstants.spacingMd,
        AppConstants.paddingH,
        0,
      ),
      child: LinearProgressIndicator(minHeight: 2),
    );
  }

  Widget _buildListingFallbackNotice() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingH,
        AppConstants.spacingMd,
        AppConstants.paddingH,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
        ),
        child: const Text(
          'Chưa kết nối được SQL, đang hiển thị dữ liệu mẫu.',
          style: TextStyle(
            color: AppColors.warningText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedCards() {
    final list = _applyFilter(_featuredListingsForUi);
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: Text('Không có tin nổi bật phù hợp',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
      );
    }
    return SizedBox(
      height: 235,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(AppConstants.paddingH,
            AppConstants.spacingSm, AppConstants.paddingH, 6),
        itemCount: list.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: AppConstants.spacingMd),
        itemBuilder: (_, i) => _buildRoomCard(list[i]),
      ),
    );
  }

  Widget _buildListingImage(
    ListingItem item, {
    required double width,
    required double height,
    required BorderRadius borderRadius,
    required String fallbackIcon,
    double fallbackIconSize = 28,
  }) {
    final imageUrl = item.imageUrl;
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: item.bgColor),
          errorWidget: (_, __, ___) => _buildListingImageFallback(
            item,
            width: width,
            height: height,
            borderRadius: borderRadius,
            fallbackIcon: fallbackIcon,
            fallbackIconSize: fallbackIconSize,
          ),
        ),
      );
    }

    return _buildListingImageFallback(
      item,
      width: width,
      height: height,
      borderRadius: borderRadius,
      fallbackIcon: fallbackIcon,
      fallbackIconSize: fallbackIconSize,
    );
  }

  Widget _buildListingImageFallback(
    ListingItem item, {
    required double width,
    required double height,
    required BorderRadius borderRadius,
    required String fallbackIcon,
    required double fallbackIconSize,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: item.bgColor,
        borderRadius: borderRadius,
      ),
      alignment: Alignment.center,
      child: Text(fallbackIcon, style: TextStyle(fontSize: fallbackIconSize)),
    );
  }

  Widget _buildRoomCard(ListingItem item) {
    final saved = _savedIds.contains(item.id);
    final showBadge = item.isNew || item.badgeLabel != null;
    final badgeText = item.isNew ? 'MỚI' : (item.badgeLabel ?? 'VIP');
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/listing/${item.id}');
      },
      child: Container(
        width: AppConstants.cardWidth,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(color: AppColors.borderLight)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              Container(
                height: AppConstants.cardImgHeight,
                foregroundDecoration: item.imageUrl == null
                    ? null
                    : BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppConstants.radiusLg),
                        ),
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(item.imageUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                decoration: BoxDecoration(
                    color: item.bgColor,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppConstants.radiusLg))),
                alignment: Alignment.center,
                child: const Text('🛋️', style: TextStyle(fontSize: 36)),
              ),
              if (showBadge)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: item.isNew
                            ? AppColors.tagNew
                            : (item.badgeColor ?? AppColors.tagVip),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSm)),
                    child: Text(badgeText, style: AppTextStyles.badge),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _toggleSave(item.id),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Icon(
                        saved
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 15,
                        color: AppColors.error),
                  ),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                      text: TextSpan(children: [
                    TextSpan(
                        text: _formatPrice(item.price),
                        style: AppTextStyles.cardPrice),
                    const TextSpan(
                        text: '/tháng', style: AppTextStyles.cardPriceSub),
                  ])),
                  const SizedBox(height: 2),
                  Text(item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardTitle),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_rounded,
                        size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 2),
                    Expanded(
                        child: Text(item.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.cardAddress)),
                  ]),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: item.tags
                        .take(3)
                        .map((t) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: AppColors.infoBg,
                                  borderRadius: BorderRadius.circular(
                                      AppConstants.radiusSm)),
                              child: Text(t, style: AppTextStyles.cardTag),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullCard(ListingItem item) {
    final saved = _savedIds.contains(item.id);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/listing/${item.id}');
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(AppConstants.paddingH, 0,
            AppConstants.paddingH, AppConstants.spacingSm),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(color: AppColors.borderLight)),
        child: Row(
          children: [
            Container(
              width: AppConstants.cardFullImgW,
              height: 100,
              foregroundDecoration: item.imageUrl == null
                  ? null
                  : BoxDecoration(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(AppConstants.radiusLg),
                      ),
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(item.imageUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
              decoration: BoxDecoration(
                  color: item.bgColor,
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppConstants.radiusLg))),
              alignment: Alignment.center,
              child: const Text('🏠', style: TextStyle(fontSize: 28)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: Text(item.title,
                                style: AppTextStyles.cardTitleLarge)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _toggleSave(item.id),
                          child: Icon(
                              saved
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                              color: AppColors.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    RichText(
                        text: TextSpan(children: [
                      TextSpan(
                          text: _formatPrice(item.price),
                          style: AppTextStyles.cardPrice),
                      const TextSpan(
                          text: '/th', style: AppTextStyles.cardPriceSub),
                    ])),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on_rounded,
                          size: 11, color: AppColors.textMuted),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          item.address,
                          style: AppTextStyles.cardAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatusBadge(status: item.status),
                        if (item.isVerified)
                          const Row(children: [
                            Icon(Icons.verified_rounded,
                                size: 12, color: AppColors.primary),
                            SizedBox(width: 3),
                            Text('Đã xác thực',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600)),
                          ]),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String action, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppConstants.paddingH,
          AppConstants.paddingV, AppConstants.paddingH, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.sectionTitle),
          GestureDetector(
            onTap: onTap,
            child: Text(action, style: AppTextStyles.sectionLink),
          ),
        ],
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
}

// ─── Filter Bottom Sheet ──────────────────────────────────────────────────────

class _FilterBottomSheet extends StatefulWidget {
  final _FilterState initial;
  final ValueChanged<_FilterState> onApply;
  const _FilterBottomSheet({required this.initial, required this.onApply});

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late _FilterState _local;

  static const _typeOptions = [
    {'key': 'phong-tro', 'label': 'Phòng trọ SV', 'icon': '🏠'},
    {'key': 'can-ho', 'label': 'Căn hộ DV', 'icon': '🏢'},
    {'key': 'o-ghep', 'label': 'Ở ghép', 'icon': '👥'},
    {'key': 'nha-nguyen-can', 'label': 'Nhà nguyên căn', 'icon': '🏡'},
  ];

  static const _amenityOptions = [
    'Wifi',
    'Điều hòa',
    'Thang máy',
    'Máy giặt',
    'Ban công',
    'Bảo vệ',
    'Sân vườn',
    'Nuôi thú',
  ];

  @override
  void initState() {
    super.initState();
    _local = widget.initial.copyWith();
  }

  void _reset() => setState(() => _local = _FilterState());

  void _apply() {
    widget.onApply(_local);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXxl)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppConstants.paddingH, 8, AppConstants.paddingH, 0),
              child: Row(
                children: [
                  const Text('Bộ lọc tìm kiếm',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _reset,
                    child: const Text('Đặt lại',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const Divider(height: 20, color: AppColors.borderLight),
            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppConstants.paddingH, 0, AppConstants.paddingH, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel('Loại hình'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _typeOptions.map((opt) {
                        final key = opt['key'] as String;
                        final active = _local.types.contains(key);
                        return GestureDetector(
                          onTap: () => setState(() {
                            final updated = Set<String>.from(_local.types);
                            if (active)
                              updated.remove(key);
                            else
                              updated.add(key);
                            _local = _local.copyWith(types: updated);
                          }),
                          child: AnimatedContainer(
                            duration: AppConstants.animFast,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primary
                                  : AppColors.bgCardLight,
                              borderRadius:
                                  BorderRadius.circular(AppConstants.radiusMd),
                              border: Border.all(
                                color: active
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(opt['icon'] as String,
                                    style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(opt['label'] as String,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: active
                                            ? Colors.white
                                            : AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionLabel('Khoảng giá (triệu/tháng)'),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _local.priceRange.start == 0
                              ? 'Không giới hạn'
                              : '${_local.priceRange.start.toStringAsFixed(0)}tr',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _local.priceRange.end >= 15
                              ? '15tr+'
                              : '${_local.priceRange.end.toStringAsFixed(0)}tr',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: AppColors.primaryLight,
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withValues(alpha: 0.15),
                        rangeThumbShape: const RoundRangeSliderThumbShape(
                            enabledThumbRadius: 10),
                        trackHeight: 4,
                      ),
                      child: RangeSlider(
                        values: _local.priceRange,
                        min: 0,
                        max: 15,
                        divisions: 15,
                        onChanged: (v) => setState(
                            () => _local = _local.copyWith(priceRange: v)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionLabel(
                        'Diện tích tối đa: ${_local.maxArea >= 80 ? "80m²+" : "${_local.maxArea.toInt()}m²"}'),
                    const SizedBox(height: 4),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor: AppColors.primaryLight,
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withValues(alpha: 0.15),
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 10),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _local.maxArea,
                        min: 10,
                        max: 80,
                        divisions: 7,
                        onChanged: (v) => setState(
                            () => _local = _local.copyWith(maxArea: v)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionLabel('Tiện nghi'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _amenityOptions.map((a) {
                        final active = _local.amenities.contains(a);
                        return GestureDetector(
                          onTap: () => setState(() {
                            final updated = Set<String>.from(_local.amenities);
                            if (active)
                              updated.remove(a);
                            else
                              updated.add(a);
                            _local = _local.copyWith(amenities: updated);
                          }),
                          child: AnimatedContainer(
                            duration: AppConstants.animFast,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primaryLight
                                  : AppColors.bgCardLight,
                              borderRadius: BorderRadius.circular(
                                  AppConstants.radiusFull),
                              border: Border.all(
                                color: active
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(a,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: active
                                        ? AppColors.primary
                                        : AppColors.textSecondary)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _apply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusLg),
                          ),
                        ),
                        child: const Text('Áp dụng bộ lọc',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(label,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary));
  }
}

// ─── Highlight Text ───────────────────────────────────────────────────────────

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final int maxLines;

  const _HighlightText({
    required this.text,
    required this.query,
    required this.style,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty)
      return Text(text,
          style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    // Normalize both for diacritic-insensitive matching
    final normalizedText = _removeDiacritics(text.toLowerCase());
    final normalizedQuery = _removeDiacritics(query.toLowerCase());
    final idx = normalizedText.indexOf(normalizedQuery);
    if (idx == -1)
      return Text(text,
          style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    // Indices in normalized text map 1:1 to original (each VN char → 1 ASCII char)
    final matchLen = normalizedQuery.length;
    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: [
          TextSpan(text: text.substring(0, idx), style: style),
          TextSpan(
            text: text.substring(idx, idx + matchLen),
            style: style.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              backgroundColor: AppColors.primaryLight,
            ),
          ),
          TextSpan(text: text.substring(idx + matchLen), style: style),
        ],
      ),
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool badge;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, this.badge = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18)),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          if (badge)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: AppColors.notifDot,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 1.5)),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isHot = status == 'hot';
    final isRented = status == 'rented';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isRented
            ? AppColors.bgCardLight
            : isHot
                ? AppColors.warningBg
                : AppColors.successBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Text(
        isRented
            ? 'Đã thuê'
            : isHot
                ? '🔥 Hot'
                : 'Còn phòng',
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isRented
                ? AppColors.textMuted
                : isHot
                    ? AppColors.warningText
                    : AppColors.successText),
      ),
    );
  }
}
