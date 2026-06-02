// lib/blocs/listing/listing_event.dart

import 'package:equatable/equatable.dart';

abstract class ListingDetailEvent extends Equatable {
  const ListingDetailEvent();

  @override
  List<Object?> get props => [];
}

class LoadListingDetail extends ListingDetailEvent {
  final int listingId;
  const LoadListingDetail(this.listingId);

  @override
  List<Object?> get props => [listingId];
}

class ToggleListingFavorite extends ListingDetailEvent {
  final int listingId;
  const ToggleListingFavorite(this.listingId);

  @override
  List<Object?> get props => [listingId];
}

class SubmitListingReview extends ListingDetailEvent {
  final int listingId;
  final int rating;
  final String comment;

  const SubmitListingReview({
    required this.listingId,
    required this.rating,
    required this.comment,
  });

  @override
  List<Object?> get props => [listingId, rating, comment];
}
