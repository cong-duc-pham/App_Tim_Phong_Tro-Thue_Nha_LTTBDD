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
