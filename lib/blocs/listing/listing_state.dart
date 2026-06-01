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
  // Khi đang xử lý toggle favorite (hiển thị loading trên nút)
  final bool isFavoriteLoading;

  const ListingDetailLoaded({
    required this.listing,
    required this.isFavorite,
    required this.reviews,
    required this.averageRating,
    required this.reviewCount,
    this.isFavoriteLoading = false,
  });

  ListingDetailLoaded copyWith({
    Listing? listing,
    bool? isFavorite,
    List<ReviewItem>? reviews,
    double? averageRating,
    int? reviewCount,
    bool? isFavoriteLoading,
  }) {
    return ListingDetailLoaded(
      listing: listing ?? this.listing,
      isFavorite: isFavorite ?? this.isFavorite,
      reviews: reviews ?? this.reviews,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      isFavoriteLoading: isFavoriteLoading ?? this.isFavoriteLoading,
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
      ];
}

class ListingDetailError extends ListingDetailState {
  final String message;
  const ListingDetailError(this.message);

  @override
  List<Object?> get props => [message];
}
