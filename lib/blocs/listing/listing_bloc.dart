// lib/blocs/listing/listing_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repositories/favorite_repository.dart';
import '../../repositories/listing_repository.dart';
import '../../repositories/review_repository.dart';
import '../../models/listing.dart';
import 'listing_event.dart';
import 'listing_state.dart';

class ListingDetailBloc extends Bloc<ListingDetailEvent, ListingDetailState> {
  final ListingRepository _listingRepo;
  final ReviewRepository _reviewRepo;
  final FavoriteRepository _favoriteRepo;

  ListingDetailBloc({
    ListingRepository? listingRepo,
    ReviewRepository? reviewRepo,
    FavoriteRepository? favoriteRepo,
  })  : _listingRepo = listingRepo ?? ListingRepository(),
        _reviewRepo = reviewRepo ?? ReviewRepository(),
        _favoriteRepo = favoriteRepo ?? FavoriteRepository(),
        super(const ListingDetailInitial()) {
    on<LoadListingDetail>(_onLoad);
    on<ToggleListingFavorite>(_onToggleFavorite);
    on<SubmitListingReview>(_onSubmitReview);
    on<ToggleReviewLike>(_onToggleReviewLike);
    on<ReplyListingReview>(_onReplyReview);
  }

  Future<void> _onLoad(
    LoadListingDetail event,
    Emitter<ListingDetailState> emit,
  ) async {
    emit(const ListingDetailLoading());

    try {
      // gọi song song để giảm thời gian chờ
      late Listing listing;
      try {
        listing = await _listingRepo.getListingById(event.listingId);
      } catch (_) {
        final fallback = event.initialListing;
        if (fallback == null) rethrow;
        listing = fallback;
      }

      final targetLanguage = event.targetLanguage;
      if (targetLanguage != null &&
          targetLanguage.toLowerCase().startsWith('en')) {
        listing = await _listingRepo.translateListing(
          listing,
          targetLanguage: 'English',
        );
      }

      var reviews = <ReviewItem>[];
      var averageRating = listing.averageRating;
      var reviewCount = listing.reviewCount;
      try {
        final reviewData = await _reviewRepo.getReviews(event.listingId);
        reviews = reviewData.reviews;
        averageRating = reviewData.averageRating;
        reviewCount = reviewData.count;
      } catch (_) {
        // Vẫn hiển thị chi tiết tin nếu endpoint review chưa có dữ liệu.
      }

      // tăng view không cần chờ kết quả
      _listingRepo.incrementView(event.listingId);

      // kiểm tra đã lưu yêu thích chưa, người chưa đăng nhập thì bỏ qua
      bool isFavorite = false;
      try {
        final favorites = await _favoriteRepo.getFavorites();
        isFavorite = favorites.any((f) => f.listingId == event.listingId);
      } catch (_) {
        // chưa đăng nhập thì isFavorite giữ false
      }

      emit(ListingDetailLoaded(
        listing: listing,
        isFavorite: isFavorite,
        reviews: reviews,
        averageRating: averageRating,
        reviewCount: reviewCount,
      ));
    } catch (e) {
      final msg = e.toString();
      emit(ListingDetailError(
        msg.startsWith('Exception: ')
            ? msg.substring('Exception: '.length)
            : msg,
      ));
    }
  }

  Future<void> _onToggleFavorite(
    ToggleListingFavorite event,
    Emitter<ListingDetailState> emit,
  ) async {
    final current = state;
    if (current is! ListingDetailLoaded) return;

    // cập nhật UI ngay không cần chờ API (optimistic update)
    final wasLiked = current.isFavorite;
    emit(current.copyWith(isFavorite: !wasLiked, isFavoriteLoading: true));

    try {
      final newState = await _favoriteRepo.toggleFavorite(event.listingId);
      emit(current.copyWith(
          isFavorite: newState, isFavoriteLoading: false, favoriteError: null));
    } catch (e) {
      // API lỗi thì roll back lại trạng thái cũ và gán thông điệp lỗi
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      emit(current.copyWith(
        isFavorite: wasLiked,
        isFavoriteLoading: false,
        favoriteError: errorMsg,
      ));
    }
  }

  Future<void> _onSubmitReview(
    SubmitListingReview event,
    Emitter<ListingDetailState> emit,
  ) async {
    final current = state;
    if (current is! ListingDetailLoaded || current.isReviewSubmitting) return;

    emit(current.copyWith(isReviewSubmitting: true));

    try {
      await _reviewRepo.createReview(
        listingId: event.listingId,
        rating: event.rating,
        comment: event.comment,
      );
      final reviewData = await _reviewRepo.getReviews(event.listingId);

      emit(current.copyWith(
        reviews: reviewData.reviews,
        averageRating: reviewData.averageRating,
        reviewCount: reviewData.count,
        isReviewSubmitting: false,
        reviewSubmitSuccess: true,
      ));
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      emit(current.copyWith(
        isReviewSubmitting: false,
        reviewSubmitError: errorMsg,
      ));
    }
  }

  Future<void> _onToggleReviewLike(
    ToggleReviewLike event,
    Emitter<ListingDetailState> emit,
  ) async {
    final current = state;
    if (current is! ListingDetailLoaded ||
        current.likingReviewIds.contains(event.reviewId)) {
      return;
    }

    emit(current.copyWith(
      likingReviewIds: {...current.likingReviewIds, event.reviewId},
    ));

    try {
      await _reviewRepo.toggleLike(event.reviewId);
      final reviewData = await _reviewRepo.getReviews(event.listingId);
      emit(current.copyWith(
        reviews: reviewData.reviews,
        averageRating: reviewData.averageRating,
        reviewCount: reviewData.count,
        likingReviewIds: const {},
      ));
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      emit(current.copyWith(
        likingReviewIds: const {},
        reviewActionError: errorMsg,
      ));
    }
  }

  Future<void> _onReplyReview(
    ReplyListingReview event,
    Emitter<ListingDetailState> emit,
  ) async {
    final current = state;
    if (current is! ListingDetailLoaded || current.replyingReviewId != null) {
      return;
    }

    emit(current.copyWith(replyingReviewId: event.reviewId));

    try {
      await _reviewRepo.replyReview(
        reviewId: event.reviewId,
        replyContent: event.reply,
      );
      final reviewData = await _reviewRepo.getReviews(event.listingId);
      emit(current.copyWith(
        reviews: reviewData.reviews,
        averageRating: reviewData.averageRating,
        reviewCount: reviewData.count,
        replyingReviewId: null,
      ));
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      emit(current.copyWith(
        replyingReviewId: null,
        reviewActionError: errorMsg,
      ));
    }
  }
}
