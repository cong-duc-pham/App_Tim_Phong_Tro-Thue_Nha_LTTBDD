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
      // gọi song song để giảm thời gian chờ
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

    // cập nhật UI ngay không cần chờ API (optimistic update)
    final wasLiked = current.isFavorite;
    emit(current.copyWith(isFavorite: !wasLiked, isFavoriteLoading: true));

    try {
      final newState = await _favoriteRepo.toggleFavorite(event.listingId);
      emit(current.copyWith(isFavorite: newState, isFavoriteLoading: false));
    } catch (_) {
      // API lỗi thì roll back lại trạng thái cũ
      emit(current.copyWith(isFavorite: wasLiked, isFavoriteLoading: false));
    }
  }
}
