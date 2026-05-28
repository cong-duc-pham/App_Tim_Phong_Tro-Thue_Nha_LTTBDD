// lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
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
  final List<String> tags;
  final Color bgColor;
  final String type; // 'phong-tro' | 'can-ho' | 'o-ghep' | 'nha-nguyen-can'

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
    this.tags = const [],
    required this.bgColor,
    this.type = 'phong-tro',
  });
}

// ─── Dữ liệu mẫu ─────────────────────────────────────────────────────────────

final _allListings = [
  const ListingItem(
    id: '1', title: 'Phòng đẹp full nội thất Bình Thạnh',
    address: 'Bình Thạnh, TP.HCM', price: 3500000, area: 25,
    isVerified: true, isFeatured: true, type: 'phong-tro',
    tags: ['Wifi', 'Điều hòa', 'Ban công'], bgColor: AppColors.illus1,
  ),
  const ListingItem(
    id: '2', title: 'Studio cao cấp Quận 1 view đẹp',
    address: 'Quận 1, TP.HCM', price: 5200000, area: 30,
    isVerified: true, isNew: true, type: 'can-ho',
    tags: ['Thang máy', 'Bảo vệ'], bgColor: AppColors.illus2,
  ),
  const ListingItem(
    id: '3', title: 'Phòng gần ĐH Bách Khoa yên tĩnh',
    address: 'Quận 10, TP.HCM', price: 2800000, area: 20,
    isFeatured: true, type: 'phong-tro',
    tags: ['Wifi', 'Máy giặt'], bgColor: AppColors.illus3,
  ),
  const ListingItem(
    id: '4', title: 'Phòng trọ sinh viên gần RMIT',
    address: 'Quận 7 · 1.2km', price: 2200000, area: 18,
    isVerified: true, status: 'available', type: 'phong-tro',
    bgColor: AppColors.illus4,
  ),
  const ListingItem(
    id: '5', title: 'Căn hộ dịch vụ Tân Bình đầy đủ',
    address: 'Tân Bình · 2.4km', price: 6500000, area: 35,
    isVerified: true, status: 'hot', type: 'can-ho',
    tags: ['Điều hòa', 'Thang máy'], bgColor: AppColors.illus2,
  ),
  const ListingItem(
    id: '6', title: 'Phòng ghép 2 người Thủ Đức',
    address: 'Thủ Đức · 3.1km', price: 1800000, area: 15,
    allowPet: true, status: 'available', type: 'o-ghep',
    bgColor: AppColors.illus3,
  ),
  const ListingItem(
    id: '7', title: 'Nhà nguyên căn Gò Vấp 3 phòng ngủ',
    address: 'Gò Vấp, TP.HCM', price: 12000000, area: 70,
    isVerified: true, type: 'nha-nguyen-can',
    tags: ['Sân vườn', 'Wifi', 'Máy giặt'], bgColor: AppColors.illus1,
  ),
  const ListingItem(
    id: '8', title: 'Ở ghép sinh viên phòng đôi Bình Dương',
    address: 'Bình Dương · 5km', price: 900000, area: 12,
    status: 'available', type: 'o-ghep',
    tags: ['Wifi'], bgColor: AppColors.illus4,
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
  int _navIndex = 0;
  int _activeFilter = 0;
  final List<String> _filters = [
    'Gần đây', 'Theo ngân sách', 'Phòng mới', 'Nuôi thú cưng', 'VIP'
  ];
  final List<String> _savedIds = [];

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  bool _isSearching = false;

  // Filter
  _FilterState _filter = _FilterState();

  @override
  void initState() {
    super.initState();
    // Tự động kích hoạt tìm kiếm nếu có từ khóa truyền từ ngoài vào (qua deep link / router)
    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.trim().isNotEmpty) {
      _searchCtrl.text = widget.initialSearchQuery!;
      _searchQuery = widget.initialSearchQuery!.trim().toLowerCase();
      _isSearching = true;
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cập nhật lại thanh tìm kiếm nếu từ khóa truyền vào widget thay đổi
    if (widget.initialSearchQuery != oldWidget.initialSearchQuery) {
      if (widget.initialSearchQuery != null && widget.initialSearchQuery!.trim().isNotEmpty) {
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

  void _toggleSave(String id) {
    setState(() {
      if (_savedIds.contains(id)) {
        _savedIds.remove(id);
      } else {
        _savedIds.add(id);
      }
    });
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
    return _allListings
        .where((e) =>
            _removeDiacritics(e.title.toLowerCase()).contains(normalized) ||
            _removeDiacritics(e.address.toLowerCase()).contains(normalized) ||
            e.tags.any((t) => _removeDiacritics(t.toLowerCase()).contains(normalized)))
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
                SliverToBoxAdapter(
                    child: _buildSectionHeader('⭐  Tin nổi bật', 'Xem thêm')),
                SliverToBoxAdapter(child: _buildFeaturedCards()),
                SliverToBoxAdapter(
                    child: _buildSectionHeader('🎯  Gợi ý cho bạn', 'Xem thêm')),
                if (_filter.hasActive) ...[
                  SliverToBoxAdapter(child: _buildActiveFilterBanner()),
                ],
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final list = _applyFilter(_suggestedListings);
                      return _buildFullCard(list[i]);
                    },
                    childCount: _applyFilter(_suggestedListings).length,
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 90)),
            ],
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
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
                        const Row(children: [
                          Text('TP. Hồ Chí Minh',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                          SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              size: 18, color: Colors.white),
                        ]),
                      ],
                    ),
                  ),
                  _IconBtn(
                      icon: Icons.notifications_outlined,
                      badge: true,
                      onTap: () {}),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 10),
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
                isDense: true,
                contentPadding: EdgeInsets.zero,
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _filter.hasActive
                        ? AppColors.primary
                        : AppColors.primary,
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.tune_rounded,
                      size: 18, color: Colors.white),
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
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultItem(ListingItem item) {
    final saved = _savedIds.contains(item.id);
    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.fromLTRB(
            AppConstants.paddingH, 0, AppConstants.paddingH, AppConstants.spacingSm),
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
                                text: '/th',
                                style: AppTextStyles.cardPriceSub),
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
        separatorBuilder: (_, __) => const SizedBox(width: AppConstants.spacingSm),
        itemBuilder: (_, i) {
          final active = i == _activeFilter;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = i),
            child: AnimatedContainer(
              duration: AppConstants.animFast,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.white,
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusFull),
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
                          color: active
                              ? Colors.white
                              : AppColors.textSecondary)),
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

  // ── Categories ────────────────────────────────────────────────────────────

  Widget _buildCategories() {
    final cats = [
      {'icon': Icons.home_rounded, 'label': 'Phòng trọ\nSV', 'color': AppColors.catBlue},
      {'icon': Icons.apartment_rounded, 'label': 'Căn hộ\nDV', 'color': AppColors.catIndigo},
      {'icon': Icons.people_rounded, 'label': 'Ở ghép', 'color': AppColors.catCyan},
      {'icon': Icons.house_rounded, 'label': 'Nhà\nnguyên căn', 'color': AppColors.catSky},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppConstants.paddingH, AppConstants.paddingV, AppConstants.paddingH, 0),
      child: Column(
        children: [
          _buildSectionHeader('Loại hình', 'Xem tất cả'),
          const SizedBox(height: AppConstants.spacingSm),
          Row(
            children: cats.map((c) => Expanded(
              child: Column(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: c['color'] as Color,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMd)),
                  alignment: Alignment.center,
                  child: Icon(c['icon'] as IconData,
                      size: AppConstants.iconLg, color: AppColors.primary),
                ),
                const SizedBox(height: 6),
                Text(c['label'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        height: 1.3)),
              ]),
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ── Banner ────────────────────────────────────────────────────────────────

  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppConstants.paddingH, AppConstants.paddingV, AppConstants.paddingH, 0),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSm)),
                    child: const Text('🔥  HOT DEAL',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                  const SizedBox(height: 6),
                  const Text('Phòng VIP giá tốt\ntháng 3/2026',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.3)),
                  const SizedBox(height: 4),
                  Text('Xác thực · Ảnh thực tế · An toàn',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
              alignment: Alignment.center,
              child: const Text('🏠', style: TextStyle(fontSize: 32)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Featured Cards ────────────────────────────────────────────────────────

  Widget _buildFeaturedCards() {
    final list = _applyFilter(_featuredListings);
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: Text('Không có tin nổi bật phù hợp',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 13))),
      );
    }
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
            AppConstants.paddingH, AppConstants.spacingSm, AppConstants.paddingH, 0),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppConstants.spacingMd),
        itemBuilder: (_, i) => _buildRoomCard(list[i]),
      ),
    );
  }

  Widget _buildRoomCard(ListingItem item) {
    final saved = _savedIds.contains(item.id);
    return GestureDetector(
      onTap: () {},
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
                decoration: BoxDecoration(
                    color: item.bgColor,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppConstants.radiusLg))),
                alignment: Alignment.center,
                child: const Text('🛋️', style: TextStyle(fontSize: 36)),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: item.isNew ? AppColors.tagNew : AppColors.tagVip,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusSm)),
                  child: Text(item.isNew ? 'MỚI' : 'VIP',
                      style: AppTextStyles.badge),
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
      onTap: () {},
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
                      Text(item.address, style: AppTextStyles.cardAddress),
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

  Widget _buildSectionHeader(String title, String action) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppConstants.paddingH, AppConstants.paddingV, AppConstants.paddingH, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTextStyles.sectionTitle),
          Text(action, style: AppTextStyles.sectionLink),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.borderLight))),
      padding: EdgeInsets.only(
          top: 10, bottom: MediaQuery.of(context).padding.bottom + 8),
      child: Row(
        children: [
          _NavItem(
              icon: Icons.home_rounded,
              label: 'Trang chủ',
              active: _navIndex == 0,
              onTap: () => setState(() => _navIndex = 0)),
          _NavItem(
              icon: Icons.favorite_border_rounded,
              label: 'Yêu thích',
              active: _navIndex == 1,
              onTap: () {
                setState(() => _navIndex = 1);
                context.go(AppConstants.routeFavorites);
              }),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => context.push('/listing'),
                  child: Container(
                    width: AppConstants.navAddBtnSize,
                    height: AppConstants.navAddBtnSize,
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 26),
                  ),
                ),
                const Text('Đăng tin', style: AppTextStyles.navLabel),
              ],
            ),
          ),
          _NavItem(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Tin nhắn',
              active: _navIndex == 3,
              onTap: () {
                setState(() => _navIndex = 3);
                context.go(AppConstants.routeChat);
              }),
          _NavItem(
            icon: Icons.person_outline_rounded,
            label: 'Cá nhân',
            active: _navIndex == 4,
            onTap: () {
              setState(() => _navIndex = 4);
              context.go(AppConstants.routeProfile);
            },
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
    'Wifi', 'Điều hòa', 'Thang máy', 'Máy giặt',
    'Ban công', 'Bảo vệ', 'Sân vườn', 'Nuôi thú',
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
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXxl)),
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
                            if (active) updated.remove(key); else updated.add(key);
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
                              borderRadius: BorderRadius.circular(
                                  AppConstants.radiusMd),
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
                        overlayColor:
                            AppColors.primary.withValues(alpha: 0.15),
                        rangeThumbShape: const RoundRangeSliderThumbShape(
                            enabledThumbRadius: 10),
                        trackHeight: 4,
                      ),
                      child: RangeSlider(
                        values: _local.priceRange,
                        min: 0,
                        max: 15,
                        divisions: 15,
                        onChanged: (v) =>
                            setState(() => _local = _local.copyWith(priceRange: v)),
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
                        overlayColor:
                            AppColors.primary.withValues(alpha: 0.15),
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 10),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _local.maxArea,
                        min: 10,
                        max: 80,
                        divisions: 7,
                        onChanged: (v) =>
                            setState(() => _local = _local.copyWith(maxArea: v)),
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
                            if (active) updated.remove(a); else updated.add(a);
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
    if (query.isEmpty) return Text(text, style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    // Normalize both for diacritic-insensitive matching
    final normalizedText = _removeDiacritics(text.toLowerCase());
    final normalizedQuery = _removeDiacritics(query.toLowerCase());
    final idx = normalizedText.indexOf(normalizedQuery);
    if (idx == -1) return Text(text, style: style, maxLines: maxLines, overflow: TextOverflow.ellipsis);
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: AppConstants.iconLg,
                color: active ? AppColors.navActive : AppColors.navInactive),
            const SizedBox(height: 3),
            Text(label,
                style: AppTextStyles.navLabel.copyWith(
                    color: active
                        ? AppColors.navActive
                        : AppColors.navInactive)),
          ],
        ),
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
        isRented ? 'Đã thuê' : isHot ? '🔥 Hot' : 'Còn phòng',
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
