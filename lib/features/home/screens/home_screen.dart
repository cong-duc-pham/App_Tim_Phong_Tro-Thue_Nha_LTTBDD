// lib/features/home/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';

// ─── Model tạm ───────────────────────────────────────────────────────────────

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
  });
}

// ─── Dữ liệu mẫu ─────────────────────────────────────────────────────────────

final _featuredListings = [
  const ListingItem(
    id: '1', title: 'Phòng đẹp full nội thất Bình Thạnh',
    address: 'Bình Thạnh, TP.HCM', price: 3500000, area: 25,
    isVerified: true, isFeatured: true,
    tags: ['Wifi', 'Điều hòa', 'Ban công'], bgColor: AppColors.illus1,
  ),
  const ListingItem(
    id: '2', title: 'Studio cao cấp Quận 1 view đẹp',
    address: 'Quận 1, TP.HCM', price: 5200000, area: 30,
    isVerified: true, isNew: true,
    tags: ['Thang máy', 'Bảo vệ'], bgColor: AppColors.illus2,
  ),
  const ListingItem(
    id: '3', title: 'Phòng gần ĐH Bách Khoa yên tĩnh',
    address: 'Quận 10, TP.HCM', price: 2800000, area: 20,
    isFeatured: true, tags: ['Wifi', 'Máy giặt'], bgColor: AppColors.illus3,
  ),
];

final _suggestedListings = [
  const ListingItem(
    id: '4', title: 'Phòng trọ sinh viên gần RMIT',
    address: 'Quận 7 · 1.2km', price: 2200000, area: 18,
    isVerified: true, status: 'available', bgColor: AppColors.illus4,
  ),
  const ListingItem(
    id: '5', title: 'Căn hộ dịch vụ Tân Bình đầy đủ',
    address: 'Tân Bình · 2.4km', price: 6500000, area: 35,
    isVerified: true, status: 'hot', bgColor: AppColors.illus2,
  ),
  const ListingItem(
    id: '6', title: 'Phòng ghép 2 người Thủ Đức',
    address: 'Thủ Đức · 3.1km', price: 1800000, area: 15,
    allowPet: true, status: 'available', bgColor: AppColors.illus3,
  ),
];

// ─── HomeScreen ───────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  int _activeFilter = 0;
  final List<String> _filters = ['Gần đây', 'Theo ngân sách', 'Phòng mới', 'Nuôi thú cưng', 'VIP'];
  final List<String> _savedIds = [];

  void _toggleSave(String id) {
    setState(() {
      if (_savedIds.contains(id)) { _savedIds.remove(id); } else { _savedIds.add(id); }
    });
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
              SliverToBoxAdapter(child: _buildFilterChips()),
              SliverToBoxAdapter(child: _buildCategories()),
              SliverToBoxAdapter(child: _buildBanner()),
              SliverToBoxAdapter(child: _buildSectionHeader('⭐  Tin nổi bật', 'Xem thêm')),
              SliverToBoxAdapter(child: _buildFeaturedCards()),
              SliverToBoxAdapter(child: _buildSectionHeader('🎯  Gợi ý cho bạn', 'Xem thêm')),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (_, i) => _buildFullCard(_suggestedListings[i]),
                  childCount: _suggestedListings.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 90)),
            ],
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppConstants.paddingH, 4, AppConstants.paddingH, 24),
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
                          const Icon(Icons.location_on_rounded, size: 13, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text('Vị trí của bạn', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75))),
                        ]),
                        const SizedBox(height: 2),
                        const Row(children: [
                          Text('TP. Hồ Chí Minh', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                          SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Colors.white),
                        ]),
                      ],
                    ),
                  ),
                  _IconBtn(icon: Icons.notifications_outlined, badge: true, onTap: () {}),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => context.go(AppConstants.routeLogin),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.25)),
                      alignment: Alignment.center,
                      child: const Text('A', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Xin chào 👋', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
              const SizedBox(height: 2),
              const Text('Bạn muốn tìm phòng nào?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Tên đường, quận, trường học...', style: AppTextStyles.inputHint)),
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppConstants.radiusSm)),
                      alignment: Alignment.center,
                      child: const Icon(Icons.tune_rounded, size: 16, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(AppConstants.paddingH, 10, AppConstants.paddingH, 0),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppConstants.spacingSm),
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
                border: Border.all(color: active ? AppColors.primary : AppColors.border, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (i == 0) ...[
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: active ? AppColors.primaryLight : AppColors.success),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(_filters[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? Colors.white : AppColors.textSecondary)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategories() {
    final cats = [
      {'icon': Icons.home_rounded,      'label': 'Phòng trọ\nSV',  'color': AppColors.catBlue},
      {'icon': Icons.apartment_rounded, 'label': 'Căn hộ\nDV',     'color': AppColors.catIndigo},
      {'icon': Icons.people_rounded,    'label': 'Ở ghép',          'color': AppColors.catCyan},
      {'icon': Icons.house_rounded,     'label': 'Nhà\nnguyên căn', 'color': AppColors.catSky},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppConstants.paddingH, AppConstants.paddingV, AppConstants.paddingH, 0),
      child: Column(
        children: [
          _buildSectionHeader('Loại hình', 'Xem tất cả'),
          const SizedBox(height: AppConstants.spacingSm),
          Row(
            children: cats.map((c) => Expanded(
              child: Column(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(color: c['color'] as Color, borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
                  alignment: Alignment.center,
                  child: Icon(c['icon'] as IconData, size: AppConstants.iconLg, color: AppColors.primary),
                ),
                const SizedBox(height: 6),
                Text(c['label'] as String, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary, height: 1.3)),
              ]),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppConstants.paddingH, AppConstants.paddingV, AppConstants.paddingH, 0),
      child: Container(
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
        padding: const EdgeInsets.all(AppConstants.spacingLg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppConstants.radiusSm)),
                    child: const Text('🔥  HOT DEAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  const SizedBox(height: 6),
                  const Text('Phòng VIP giá tốt\ntháng 3/2026',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, height: 1.3)),
                  const SizedBox(height: 4),
                  Text('Xác thực · Ảnh thực tế · An toàn',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
              alignment: Alignment.center,
              child: const Text('🏠', style: TextStyle(fontSize: 32)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCards() {
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(AppConstants.paddingH, AppConstants.spacingSm, AppConstants.paddingH, 0),
        itemCount: _featuredListings.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppConstants.spacingMd),
        itemBuilder: (_, i) => _buildRoomCard(_featuredListings[i]),
      ),
    );
  }

  Widget _buildRoomCard(ListingItem item) {
    final saved = _savedIds.contains(item.id);
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: AppConstants.cardWidth,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppConstants.radiusLg), border: Border.all(color: AppColors.borderLight)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              Container(
                height: AppConstants.cardImgHeight,
                decoration: BoxDecoration(color: item.bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(AppConstants.radiusLg))),
                alignment: Alignment.center,
                child: const Text('🛋️', style: TextStyle(fontSize: 36)),
              ),
              Positioned(top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: item.isNew ? AppColors.tagNew : AppColors.tagVip, borderRadius: BorderRadius.circular(AppConstants.radiusSm)),
                  child: Text(item.isNew ? 'MỚI' : 'VIP', style: AppTextStyles.badge),
                ),
              ),
              Positioned(top: 8, right: 8,
                child: GestureDetector(
                  onTap: () => _toggleSave(item.id),
                  child: Container(
                    width: 28, height: 28,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Icon(saved ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 15, color: AppColors.error),
                  ),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(text: TextSpan(children: [
                    TextSpan(text: _formatPrice(item.price), style: AppTextStyles.cardPrice),
                    const TextSpan(text: '/tháng', style: AppTextStyles.cardPriceSub),
                  ])),
                  const SizedBox(height: 2),
                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.cardTitle),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_rounded, size: 11, color: AppColors.textMuted),
                    const SizedBox(width: 2),
                    Expanded(child: Text(item.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.cardAddress)),
                  ]),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4, runSpacing: 4,
                    children: item.tags.take(3).map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(AppConstants.radiusSm)),
                      child: Text(t, style: AppTextStyles.cardTag),
                    )).toList(),
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
        margin: const EdgeInsets.fromLTRB(AppConstants.paddingH, 0, AppConstants.paddingH, AppConstants.spacingSm),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppConstants.radiusLg), border: Border.all(color: AppColors.borderLight)),
        child: Row(
          children: [
            Container(
              width: AppConstants.cardFullImgW, height: 100,
              decoration: BoxDecoration(color: item.bgColor, borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppConstants.radiusLg))),
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
                        Expanded(child: Text(item.title, style: AppTextStyles.cardTitleLarge)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _toggleSave(item.id),
                          child: Icon(saved ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 18, color: AppColors.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    RichText(text: TextSpan(children: [
                      TextSpan(text: _formatPrice(item.price), style: AppTextStyles.cardPrice),
                      const TextSpan(text: '/th', style: AppTextStyles.cardPriceSub),
                    ])),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.location_on_rounded, size: 11, color: AppColors.textMuted),
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
                            Icon(Icons.verified_rounded, size: 12, color: AppColors.primary),
                            SizedBox(width: 3),
                            Text('Đã xác thực', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.fromLTRB(AppConstants.paddingH, AppConstants.paddingV, AppConstants.paddingH, 0),
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
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.borderLight))),
      padding: EdgeInsets.only(top: 10, bottom: MediaQuery.of(context).padding.bottom + 8),
      child: Row(
        children: [
          _NavItem(icon: Icons.home_rounded, label: 'Trang chủ', active: _navIndex == 0, onTap: () => setState(() => _navIndex = 0)),
          _NavItem(icon: Icons.favorite_border_rounded, label: 'Yêu thích', active: _navIndex == 1, onTap: () => setState(() => _navIndex = 1)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: AppConstants.navAddBtnSize, height: AppConstants.navAddBtnSize,
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
                  ),
                ),
                const Text('Đăng tin', style: AppTextStyles.navLabel),
              ],
            ),
          ),
          _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Tin nhắn', active: _navIndex == 3, onTap: () => setState(() => _navIndex = 3)),
          _NavItem(
            icon: Icons.person_outline_rounded, label: 'Cá nhân', active: _navIndex == 4,
            onTap: () { setState(() => _navIndex = 4); context.go(AppConstants.routeLogin); },
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

// ─── Reusable widgets ─────────────────────────────────────────────────────────

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
            width: 36, height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.18)),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          if (badge)
            Positioned(top: 6, right: 6,
              child: Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: AppColors.notifDot, shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 1.5)),
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
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppConstants.iconLg, color: active ? AppColors.navActive : AppColors.navInactive),
            const SizedBox(height: 3),
            Text(label, style: AppTextStyles.navLabel.copyWith(color: active ? AppColors.navActive : AppColors.navInactive)),
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
        color: isRented ? AppColors.bgCardLight : isHot ? AppColors.warningBg : AppColors.successBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Text(
        isRented ? 'Đã thuê' : isHot ? '🔥 Hot' : 'Còn phòng',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: isRented ? AppColors.textMuted : isHot ? AppColors.warningText : AppColors.successText),
      ),
    );
  }
}