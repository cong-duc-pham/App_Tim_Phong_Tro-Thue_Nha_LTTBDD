// lib/screens/listing/listing_detail_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../../blocs/listing/listing_bloc.dart';
import '../../blocs/listing/listing_event.dart';
import '../../blocs/listing/listing_state.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/listing.dart';
import '../../repositories/conversation_repository.dart';
import '../../repositories/review_repository.dart';

class ListingDetailScreen extends StatefulWidget {
  final int listingId;
  final bool scrollToReviews;

  const ListingDetailScreen({
    super.key,
    required this.listingId,
    this.scrollToReviews = false,
  });

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final PageController _imagePageCtrl = PageController();
  final ScrollController _scrollCtrl = ScrollController();
  final GlobalKey _reviewsSectionKey = GlobalKey();
  final TextEditingController _reviewCommentCtrl = TextEditingController();
  final ConversationRepository _conversationRepository =
      ConversationRepository();
  bool _isDescExpanded = false;
  bool _isStartingChat = false;
  bool _didScrollToReviews = false;
  double _reviewRating = 5;

  @override
  void dispose() {
    _imagePageCtrl.dispose();
    _scrollCtrl.dispose();
    _reviewCommentCtrl.dispose();
    super.dispose();
  }

  void _scheduleScrollToReviews() {
    if (!widget.scrollToReviews || _didScrollToReviews) return;
    _didScrollToReviews = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _reviewsSectionKey.currentContext;
      if (!mounted || targetContext == null) return;

      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  void _submitReview(
    BuildContext blocContext,
    Listing listing,
    ListingDetailLoaded state,
  ) {
    final comment = _reviewCommentCtrl.text.trim();
    if (state.isReviewSubmitting) return;
    if (comment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập nội dung đánh giá.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    blocContext.read<ListingDetailBloc>().add(
          SubmitListingReview(
            listingId: listing.listingId,
            rating: _reviewRating.round(),
            comment: comment,
          ),
        );
  }

  // Định dạng hiển thị tiền tệ thân thiện (ví dụ: 3.5tr hoặc 800k)
  String _formatPrice(double price) {
    if (price >= 1000000) {
      final m = price / 1000000;
      return '${m % 1 == 0 ? m.toInt() : m.toStringAsFixed(1)} triệu';
    }
    if (price >= 1000) {
      final k = price / 1000;
      return '${k.toInt()}k';
    }
    return '${price.toInt()}đ';
  }

  // Thực hiện cuộc gọi đến số điện thoại của chủ nhà
  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Không thể gọi số này';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể thực hiện cuộc gọi: $e. Sđt: $phone'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Mở ứng dụng bản đồ bên ngoài
  Future<void> _openMap(Listing listing) async {
    if (!listing.hasLocation) return;
    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      {
        'api': '1',
        'query': '${listing.latitude},${listing.longitude}',
      },
    );

    try {
      final openedExternal = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (openedExternal) return;

      final openedDefault = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
      if (openedDefault) return;

      throw 'Không tìm thấy ứng dụng hoặc trình duyệt để mở bản đồ';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể mở bản đồ (Lỗi: $e)'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Bắt đầu chat với chủ trọ
  Future<void> _startChat(Listing listing) async {
    if (listing.landlordId == null || _isStartingChat) return;

    setState(() => _isStartingChat = true);
    try {
      final conv = await _conversationRepository.createConversation(
        listingId: listing.listingId,
        landlordId: listing.landlordId!,
      );
      if (!mounted) return;
      context.push('/chat/detail', extra: conv);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().startsWith('Exception: ')
          ? e.toString().substring('Exception: '.length)
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isStartingChat = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ListingDetailBloc()..add(LoadListingDetail(widget.listingId)),
      child: Scaffold(
        backgroundColor: AppColors.bgPage,
        body: BlocListener<ListingDetailBloc, ListingDetailState>(
          listenWhen: (previous, current) =>
              previous is ListingDetailLoaded &&
              current is ListingDetailLoaded &&
              ((current.favoriteError != previous.favoriteError &&
                      current.favoriteError != null) ||
                  (current.reviewSubmitError != previous.reviewSubmitError &&
                      current.reviewSubmitError != null) ||
                  (current.reviewSubmitSuccess &&
                      current.reviewSubmitSuccess !=
                          previous.reviewSubmitSuccess)),
          listener: (context, state) {
            if (state is ListingDetailLoaded && state.favoriteError != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.favoriteError!),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            if (state is ListingDetailLoaded &&
                state.reviewSubmitError != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.reviewSubmitError!),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            if (state is ListingDetailLoaded && state.reviewSubmitSuccess) {
              _reviewCommentCtrl.clear();
              setState(() => _reviewRating = 5);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã gửi đánh giá thành công.'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          child: BlocBuilder<ListingDetailBloc, ListingDetailState>(
            builder: (context, state) {
              if (state is ListingDetailLoading) {
                return _buildShimmerLoading();
              }
              if (state is ListingDetailError) {
                return _buildErrorState(context, state.message);
              }
              if (state is ListingDetailLoaded) {
                _scheduleScrollToReviews();
                return _buildContent(context, state);
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  // Màn hình chi tiết chính
  Widget _buildContent(BuildContext context, ListingDetailLoaded state) {
    final listing = state.listing;

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(context, state),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMainInfoSection(listing),
                  _buildQuickStatsSection(listing, state),
                  _buildUtilitiesSection(listing),
                  _buildRoomInfoSection(listing),
                  _buildAmenitiesSection(listing),
                  _buildDescriptionSection(listing),
                  _buildLandlordSection(context, listing),
                  _buildReviewsSection(context, listing, state),
                  const SizedBox(height: 100), // Khoảng trống cho bottom bar
                ],
              ),
            ),
          ],
        ),
        _buildBottomActionBar(context, state),
      ],
    );
  }

  // Sliver App Bar hiển thị gallery ảnh
  Widget _buildAppBar(BuildContext context, ListingDetailLoaded state) {
    final listing = state.listing;
    final images = listing.allImages;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.4),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      actions: [
        CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.4),
          child: IconButton(
            icon:
                const Icon(Icons.share_rounded, color: Colors.white, size: 18),
            onPressed: () async {
              final formattedPrice = _formatPrice(listing.price);
              final shareContent = '🏠 ${listing.title}\n💵 Giá: $formattedPrice/tháng\n📍 Địa chỉ: ${listing.displayAddress}\n👉 Xem chi tiết tại ứng dụng: swinghouse://listing/${listing.listingId}\nHoặc truy cập website: https://swinghouse.vn/listing/${listing.listingId}';
              
              try {
                await Share.share(shareContent);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Không thể chia sẻ tin đăng: $e'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.4),
          child: IconButton(
            icon: state.isFavorite
                ? const Icon(Icons.favorite_rounded,
                    color: AppColors.error, size: 20)
                : const Icon(Icons.favorite_border_rounded,
                    color: Colors.white, size: 20),
            onPressed: () {
              context
                  .read<ListingDetailBloc>()
                  .add(ToggleListingFavorite(listing.listingId));
            },
          ),
        ),
        const SizedBox(width: 16),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: images.isEmpty
            ? Container(
                color: AppColors.illus1,
                alignment: Alignment.center,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🏠', style: TextStyle(fontSize: 64)),
                    SizedBox(height: 8),
                    Text(
                      'Không có hình ảnh phòng trọ',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            : Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  PageView.builder(
                    controller: _imagePageCtrl,
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return CachedNetworkImage(
                        imageUrl: images[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          color: AppColors.bgCardLight,
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.illus1,
                          alignment: Alignment.center,
                          child: const Text('⚠️ Lỗi tải ảnh',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusFull),
                      ),
                      child: SmoothPageIndicator(
                        controller: _imagePageCtrl,
                        count: images.length,
                        effect: const ScrollingDotsEffect(
                          activeDotColor: Colors.white,
                          dotColor: Colors.white54,
                          dotHeight: 6,
                          dotWidth: 6,
                          activeDotScale: 1.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // Tên phòng, giá, diện tích, địa chỉ
  Widget _buildMainInfoSection(Listing listing) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(AppConstants.paddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Text(
                  listing.typeName,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (listing.isVerified) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_rounded,
                          size: 10, color: AppColors.success),
                      SizedBox(width: 2),
                      Text(
                        'ĐÃ XÁC THỰC',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.successText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            listing.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatPrice(listing.price),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.error,
                ),
              ),
              const Text(
                '/tháng',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Icon(Icons.square_foot_rounded,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${listing.area.toStringAsFixed(0)} m²',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.borderLight),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.displayAddress,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    if (listing.hasLocation) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _openMap(listing),
                        child: const Text(
                          'Xem trên bản đồ Google Maps',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Thống kê nhanh: Lượt xem, lượt lưu, đánh giá
  Widget _buildQuickStatsSection(Listing listing, ListingDetailLoaded state) {
    return Container(
      key: _reviewsSectionKey,
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      padding: const EdgeInsets.all(AppConstants.paddingH),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickStatItem(
            icon: Icons.remove_red_eye_outlined,
            value: '${listing.viewCount ?? 0}',
            label: 'Lượt xem',
          ),
          _buildQuickStatItem(
            icon: Icons.bookmark_border_rounded,
            value: '${listing.saveCount ?? 0}',
            label: 'Đã lưu',
          ),
          _buildQuickStatItem(
            icon: Icons.star_rounded,
            iconColor: AppColors.warning,
            value: state.averageRating > 0
                ? state.averageRating.toStringAsFixed(1)
                : 'Chưa có',
            label: state.reviewCount > 0
                ? '${state.reviewCount} đánh giá'
                : 'Đánh giá',
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatItem({
    required IconData icon,
    Color iconColor = AppColors.textSecondary,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  // Giá dịch vụ (Điện, Nước, Internet, Gửi xe)
  Widget _buildUtilitiesSection(Listing listing) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      padding: const EdgeInsets.all(AppConstants.paddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chi phí dịch vụ', style: AppTextStyles.h3),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 12,
            children: [
              _buildUtilityItem(
                icon: Icons.flash_on_rounded,
                iconColor: AppColors.warning,
                label: 'Giá điện',
                value: listing.electricPrice != null
                    ? '${_formatPrice(listing.electricPrice!)}/kWh'
                    : 'Theo EVN',
              ),
              _buildUtilityItem(
                icon: Icons.water_drop_rounded,
                iconColor: AppColors.info,
                label: 'Giá nước',
                value: listing.waterPrice != null
                    ? '${_formatPrice(listing.waterPrice!)}/khối'
                    : 'Theo UBND',
              ),
              _buildUtilityItem(
                icon: Icons.wifi_rounded,
                iconColor: AppColors.primary,
                label: 'Internet',
                value:
                    listing.internetPrice != null && listing.internetPrice! > 0
                        ? '${_formatPrice(listing.internetPrice!)}/tháng'
                        : 'Miễn phí',
              ),
              _buildUtilityItem(
                icon: Icons.directions_bike_rounded,
                iconColor: AppColors.success,
                label: 'Gửi xe',
                value: listing.parkingPrice != null && listing.parkingPrice! > 0
                    ? '${_formatPrice(listing.parkingPrice!)}/tháng'
                    : 'Miễn phí/Không có',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Thông tin bổ sung phòng (Tầng, Số người ở tối đa, thú cưng...)
  Widget _buildRoomInfoSection(Listing listing) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        color: Colors.white,
        padding: const EdgeInsets.all(AppConstants.paddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thông tin phòng', style: AppTextStyles.h3),
            const SizedBox(height: 14),
            _buildInfoRow(
                Icons.layers_rounded,
                'Tầng số',
                listing.floor != null
                    ? '${listing.floor}/${listing.totalFloors ?? "?"}'
                    : 'Chưa cập nhật'),
            _buildInfoRow(
                Icons.people_alt_rounded,
                'Số người ở tối đa',
                listing.maxOccupants != null
                    ? '${listing.maxOccupants} người'
                    : 'Không giới hạn'),
            _buildInfoRow(Icons.pets_rounded, 'Cho phép nuôi thú cưng',
                listing.allowPet ? 'Có' : 'Không'),
            _buildInfoRow(
              Icons.calendar_month_rounded,
              'Sẵn sàng từ ngày',
              listing.availableFrom != null
                  ? '${listing.availableFrom!.day}/${listing.availableFrom!.month}/${listing.availableFrom!.year}'
                  : 'Ở ngay',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // Danh sách tiện ích (amenityNames)
  Widget _buildAmenitiesSection(Listing listing) {
    if (listing.amenityNames.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        color: Colors.white,
        padding: const EdgeInsets.all(AppConstants.paddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tiện ích phòng trọ', style: AppTextStyles.h3),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: listing.amenityNames.map((name) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _getAmenityIcon(name),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getAmenityIcon(String name) {
    final lower = name.toLowerCase();
    IconData icon = Icons.check_circle_outline_rounded;
    Color color = AppColors.success;

    if (lower.contains('wifi') || lower.contains('internet')) {
      icon = Icons.wifi_rounded;
      color = AppColors.primary;
    } else if (lower.contains('điều hòa') || lower.contains('máy lạnh')) {
      icon = Icons.ac_unit_rounded;
      color = Colors.lightBlue;
    } else if (lower.contains('tủ lạnh')) {
      icon = Icons.kitchen_rounded;
      color = Colors.teal;
    } else if (lower.contains('máy giặt')) {
      icon = Icons.local_laundry_service_rounded;
      color = Colors.deepPurple;
    } else if (lower.contains('giường') || lower.contains('tủ')) {
      icon = Icons.bed_rounded;
      color = Colors.brown;
    } else if (lower.contains('nóng lạnh') || lower.contains('bình nóng')) {
      icon = Icons.hot_tub_rounded;
      color = Colors.orange;
    } else if (lower.contains('bếp') || lower.contains('nấu ăn')) {
      icon = Icons.restaurant_rounded;
      color = Colors.redAccent;
    } else if (lower.contains('an ninh') || lower.contains('bảo vệ')) {
      icon = Icons.security_rounded;
      color = Colors.green;
    } else if (lower.contains('đỗ xe') || lower.contains('xe máy')) {
      icon = Icons.motorcycle_rounded;
      color = Colors.blueGrey;
    }

    return Icon(icon, size: 16, color: color);
  }

  // Mô tả chi tiết (collapsible)
  Widget _buildDescriptionSection(Listing listing) {
    final desc = listing.description?.trim() ??
        'Không có mô tả chi tiết cho phòng trọ này.';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      padding: const EdgeInsets.all(AppConstants.paddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mô tả chi tiết', style: AppTextStyles.h3),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: AppConstants.animFast,
            alignment: Alignment.topCenter,
            child: Text(
              desc,
              maxLines: _isDescExpanded ? null : 4,
              overflow: _isDescExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
          ),
          if (desc.length > 150) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () {
                setState(() {
                  _isDescExpanded = !_isDescExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isDescExpanded ? 'Thu gọn' : 'Đọc thêm',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _isDescExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Thông tin chủ trọ
  Widget _buildLandlordSection(BuildContext context, Listing listing) {
    final name = listing.landlordName ?? 'Chủ nhà';
    final avatar = listing.landlordAvatar;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      padding: const EdgeInsets.all(AppConstants.paddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thông tin người cho thuê', style: AppTextStyles.h3),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: avatar != null && avatar.trim().isNotEmpty
                    ? CachedNetworkImageProvider(avatar)
                    : null,
                child: avatar == null || avatar.trim().isEmpty
                    ? Text(
                        name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.verified_user_rounded,
                            size: 12, color: AppColors.success),
                        SizedBox(width: 4),
                        Text(
                          'Đối tác đã xác thực',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (listing.landlordPhone != null) ...[
                IconButton(
                  onPressed: () => _makePhoneCall(listing.landlordPhone!),
                  icon: const Icon(Icons.phone_in_talk_rounded,
                      color: AppColors.success),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.successBg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isStartingChat ? null : () => _startChat(listing),
                  icon: _isStartingChat
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: AppColors.primary,
                        ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Danh sách đánh giá (Reviews)
  Widget _buildReviewsSection(
    BuildContext blocContext,
    Listing listing,
    ListingDetailLoaded state,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: Colors.white,
      padding: const EdgeInsets.all(AppConstants.paddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Đánh giá phòng (${state.reviewCount})',
                  style: AppTextStyles.h3),
              const Spacer(),
              if (state.reviews.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: AppColors.warning, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      state.averageRating.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          _buildReviewComposer(blocContext, listing, state),
          const SizedBox(height: 18),
          if (state.reviews.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              width: double.infinity,
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Text('⭐', style: TextStyle(fontSize: 28)),
                  SizedBox(height: 8),
                  Text(
                    'Chưa có lượt đánh giá nào cho phòng này',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          else ...[
            ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.reviews.length > 3 ? 3 : state.reviews.length,
              itemBuilder: (context, index) {
                final rev = state.reviews[index];
                return _buildReviewTile(rev);
              },
            ),
            if (state.reviews.length > 3) ...[
              const Divider(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () {
                    // Xem tất cả đánh giá
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Tính năng hiển thị tất cả đánh giá đang được bổ sung'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text(
                    'Xem tất cả đánh giá',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildReviewComposer(
    BuildContext blocContext,
    Listing listing,
    ListingDetailLoaded state,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Viết đánh giá của bạn',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              RatingBar.builder(
                initialRating: _reviewRating,
                minRating: 1,
                maxRating: 5,
                itemCount: 5,
                allowHalfRating: false,
                itemSize: 28,
                unratedColor: AppColors.border,
                itemBuilder: (context, index) => const Icon(
                  Icons.star_rounded,
                  color: AppColors.warning,
                ),
                onRatingUpdate: (rating) {
                  setState(() => _reviewRating = rating);
                },
              ),
              const SizedBox(width: 10),
              Text(
                '${_reviewRating.round()}/5',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reviewCommentCtrl,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText:
                  'Chia sẻ trải nghiệm về phòng, vị trí, giá và chủ nhà...',
              hintStyle: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: Colors.white,
              counterStyle: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.isReviewSubmitting
                  ? null
                  : () => _submitReview(blocContext, listing, state),
              icon: state.isReviewSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.rate_review_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
              label: Text(
                state.isReviewSubmitting ? 'Đang gửi...' : 'Gửi đánh giá',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.textMuted,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTile(ReviewItem review) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.bgPage,
                backgroundImage: review.reviewerAvatar != null &&
                        review.reviewerAvatar!.trim().isNotEmpty
                    ? CachedNetworkImageProvider(review.reviewerAvatar!)
                    : null,
                child: review.reviewerAvatar == null ||
                        review.reviewerAvatar!.trim().isEmpty
                    ? Text(
                        review.reviewerName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewerName,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              RatingBarIndicator(
                rating: review.rating,
                itemBuilder: (context, index) =>
                    const Icon(Icons.star_rounded, color: AppColors.warning),
                itemCount: 5,
                itemSize: 13,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 40.0),
            child: Text(
              review.content,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary, height: 1.45),
            ),
          ),
          if (review.replyContent != null &&
              review.replyContent!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(left: 40.0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.reply_rounded,
                          size: 14, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Phản hồi từ chủ nhà',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    review.replyContent!,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Floating Bottom Action Bar (Lưu & Liên hệ)
  Widget _buildBottomActionBar(
      BuildContext context, ListingDetailLoaded state) {
    final listing = state.listing;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: state.isFavoriteLoading
                    ? null
                    : () {
                        context
                            .read<ListingDetailBloc>()
                            .add(ToggleListingFavorite(listing.listingId));
                      },
                icon: state.isFavoriteLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.textSecondary),
                      )
                    : Icon(
                        state.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: state.isFavorite
                            ? AppColors.error
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                label: Text(
                  state.isFavorite ? 'Đã lưu' : 'Lưu tin',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: state.isFavorite
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                      color: state.isFavorite
                          ? AppColors.error.withValues(alpha: 0.5)
                          : AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMd)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: listing.landlordId != null && !_isStartingChat
                    ? () => _startChat(listing)
                    : null,
                icon: _isStartingChat
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.chat_bubble_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                label: const Text(
                  'Nhắn tin ngay',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMd)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Shimmer skeleton loader
  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 280, color: Colors.white),
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 18, width: 80, color: Colors.white),
                  const SizedBox(height: 12),
                  Container(
                      height: 22, width: double.infinity, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(height: 22, width: 220, color: Colors.white),
                  const SizedBox(height: 16),
                  Container(height: 24, width: 140, color: Colors.white),
                  const SizedBox(height: 16),
                  const Divider(height: 24, color: AppColors.borderLight),
                  Row(
                    children: [
                      Container(height: 16, width: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Container(height: 16, width: 240, color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 8),
              height: 72,
              color: Colors.white,
            ),
            Container(
              margin: const EdgeInsets.only(top: 8),
              height: 200,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  // Màn hình báo lỗi tải dữ liệu
  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingH),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.errorBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Lỗi tải thông tin phòng trọ',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Quay lại'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMd)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    context
                        .read<ListingDetailBloc>()
                        .add(LoadListingDetail(widget.listingId));
                  },
                  icon: const Icon(Icons.refresh_rounded,
                      size: 18, color: Colors.white),
                  label: const Text('Thử lại',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMd)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
