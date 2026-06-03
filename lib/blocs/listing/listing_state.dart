// lib/blocs/listing/listing_state.dart

import 'package:equatable/equatable.dart';

import '../../models/listing.dart';
import '../../repositories/review_repository.dart';

abstract class ListingDetailState extends Equatable {
  const ListingDetailState();

  @override
  List<Object?> get props => [];
}

class ListingDetailInitial extends ListingDetailState {
  const ListingDetailInitial();
}

class ListingDetailLoading extends ListingDetailState {
  const ListingDetailLoading();
}

class ListingDetailLoaded extends ListingDetailState {
  final Listing listing;
  final bool isFavorite;
  final List<ReviewItem> reviews;
  final double averageRating;
  final int reviewCount;
  // true khi đang gọi API toggle, tránh người dùng nhấn nhiều lần
  final bool isFavoriteLoading;
  final String? favoriteError;
  final bool isReviewSubmitting;
  final String? reviewSubmitError;
  final bool reviewSubmitSuccess;
  final Set<int> likingReviewIds;
  final int? replyingReviewId;
  final String? reviewActionError;

  const ListingDetailLoaded({
    required this.listing,
    required this.isFavorite,
    required this.reviews,
    required this.averageRating,
    required this.reviewCount,
    this.isFavoriteLoading = false,
    this.favoriteError,
    this.isReviewSubmitting = false,
    this.reviewSubmitError,
    this.reviewSubmitSuccess = false,
    this.likingReviewIds = const {},
    this.replyingReviewId,
    this.reviewActionError,
  });

  ListingDetailLoaded copyWith({
    Listing? listing,
    bool? isFavorite,
    List<ReviewItem>? reviews,
    double? averageRating,
    int? reviewCount,
    bool? isFavoriteLoading,
    String? favoriteError,
    bool? isReviewSubmitting,
    String? reviewSubmitError,
    bool? reviewSubmitSuccess,
    Set<int>? likingReviewIds,
    int? replyingReviewId,
    String? reviewActionError,
  }) {
    return ListingDetailLoaded(
      listing: listing ?? this.listing,
      isFavorite: isFavorite ?? this.isFavorite,
      reviews: reviews ?? this.reviews,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      isFavoriteLoading: isFavoriteLoading ?? this.isFavoriteLoading,
      favoriteError: favoriteError,
      isReviewSubmitting: isReviewSubmitting ?? this.isReviewSubmitting,
      reviewSubmitError: reviewSubmitError,
      reviewSubmitSuccess: reviewSubmitSuccess ?? false,
      likingReviewIds: likingReviewIds ?? this.likingReviewIds,
      replyingReviewId: replyingReviewId,
      reviewActionError: reviewActionError,
    );
  }

  @override
  List<Object?> get props => [
        listing,
        isFavorite,
        reviews,
        averageRating,
        reviewCount,
        isFavoriteLoading,
        favoriteError,
        isReviewSubmitting,
        reviewSubmitError,
        reviewSubmitSuccess,
        likingReviewIds,
        replyingReviewId,
        reviewActionError,
      ];
}

class ListingDetailError extends ListingDetailState {
  final String message;
  const ListingDetailError(this.message);

  @override
  List<Object?> get props => [message];
}
