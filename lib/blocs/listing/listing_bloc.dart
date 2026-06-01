// lib/blocs/listing/listing_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repositories/favorite_repository.dart';
import '../../repositories/listing_repository.dart';
import '../../repositories/review_repository.dart';
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
  }

  Future<void> _onLoad(
    LoadListingDetail event,
    Emitter<ListingDetailState> emit,
  ) async {
    emit(const ListingDetailLoading());

    try {
      // Tải chi tiết listing + reviews song song để nhanh hơn
      final results = await Future.wait([
        _listingRepo.getListingById(event.listingId),
        _reviewRepo.getReviews(event.listingId),
      ]);

      final listing = results[0] as dynamic;
      final reviewData = results[1] as ({
        List<ReviewItem> reviews,
        double averageRating,
        int count,
      });

      // Tăng lượt xem (fire-and-forget, không block UI)
      _listingRepo.incrementView(event.listingId);

      // Kiểm tra trạng thái yêu thích — fail silently nếu chưa đăng nhập
      bool isFavorite = false;
      try {
        final favorites = await _favoriteRepo.getFavorites();
        isFavorite = favorites.any((f) => f.listingId == event.listingId);
      } catch (_) {
        // Người dùng chưa đăng nhập → mặc định không yêu thích
      }

      emit(ListingDetailLoaded(
        listing: listing,
        isFavorite: isFavorite,
        reviews: reviewData.reviews,
        averageRating: reviewData.averageRating,
        reviewCount: reviewData.count,
      ));
    } catch (e) {
      final msg = e.toString();
      emit(ListingDetailError(
        msg.startsWith('Exception: ') ? msg.substring('Exception: '.length) : msg,
      ));
    }
  }

  Future<void> _onToggleFavorite(
    ToggleListingFavorite event,
    Emitter<ListingDetailState> emit,
  ) async {
    final current = state;
    if (current is! ListingDetailLoaded) return;

    // Optimistic update: đổi trạng thái ngay trên UI
    final wasLiked = current.isFavorite;
    emit(current.copyWith(
      isFavorite: !wasLiked,
      isFavoriteLoading: true,
    ));

    try {
      final newState = await _favoriteRepo.toggleFavorite(event.listingId);
      emit(current.copyWith(
        isFavorite: newState,
        isFavoriteLoading: false,
      ));
    } catch (_) {
      // Rollback về trạng thái cũ nếu API lỗi
      emit(current.copyWith(
        isFavorite: wasLiked,
        isFavoriteLoading: false,
      ));
    }
  }
}
