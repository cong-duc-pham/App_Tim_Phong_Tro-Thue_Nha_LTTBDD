import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/post_package.dart';
import '../../models/amenity.dart';
import '../../models/listing.dart';
import '../../repositories/listing_repository.dart';
import '../../repositories/package_repository.dart';
import '../../screens/payment/package_screen.dart';
import '../../services/post_listing_draft_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/profile_theme.dart';

// ─────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────
class RoomType {
  final int id;
  final String name;
  final IconData icon;
  const RoomType({required this.id, required this.name, required this.icon});
}

/// slot_index 0 = ảnh bìa, 1-5 = ảnh phụ
class ImageSlot {
  final int slotIndex;
  File? file;
  String? networkUrl;
  ImageSlot({required this.slotIndex, this.file, this.networkUrl});
  bool get isEmpty => file == null && networkUrl == null;
  bool get isCover => slotIndex == 0;
}

class VideoSlot {
  final int slotIndex;
  File? file;
  VideoSlot({required this.slotIndex, this.file});
  bool get isEmpty => file == null;
  String get fileName =>
      file == null ? '' : file!.path.split(RegExp(r'[\\/]')).last;
}

class _OsmSearchResult {
  final String displayName;
  final LatLng point;

  const _OsmSearchResult({
    required this.displayName,
    required this.point,
  });

  factory _OsmSearchResult.fromJson(Map<String, dynamic> json) {
    return _OsmSearchResult(
      displayName: json['display_name']?.toString() ?? '',
      point: LatLng(
        double.tryParse(json['lat']?.toString() ?? '') ??
            AppConstants.defaultLat,
        double.tryParse(json['lon']?.toString() ?? '') ??
            AppConstants.defaultLng,
      ),
    );
  }
}

const _mapTileUrlTemplate =
    'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────
class PostListingScreen extends StatefulWidget {
  final Listing? initialListing;

  const PostListingScreen({super.key, this.initialListing});

  bool get isEditing => initialListing != null;

  @override
  State<PostListingScreen> createState() => _PostListingScreenState();
}

class _PostListingScreenState extends State<PostListingScreen> {
  final ListingRepository _listingRepository = ListingRepository();
  final PackageRepository _packageRepository = PackageRepository();
  final ImagePicker _imagePicker = ImagePicker();
  int _currentStep = 0;
  static const int _totalSteps = 5;
  bool _isSubmitting = false;
  int? _createdListingIdForVip;

  // 6 slot ảnh cố định (slot_index 0-5)
  final List<ImageSlot> _slots =
      List.generate(6, (i) => ImageSlot(slotIndex: i));
  final List<VideoSlot> _videoSlots =
      List.generate(3, (i) => VideoSlot(slotIndex: i));

  // Form controllers
  RoomType? _selectedType;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _totalFloorsCtrl = TextEditingController();
  final _maxOccupantsCtrl = TextEditingController(text: '1');
  final _streetCtrl = TextEditingController();
  final _electricCtrl = TextEditingController();
  final _waterCtrl = TextEditingController();
  final _internetCtrl = TextEditingController();
  final _parkingCtrl = TextEditingController();

  bool _allowPet = false;
  DateTime? _availableFrom;
  List<PostPackage> _packages = [];
  PostPackage? _selectedPackage;
  bool _isLoadingPackages = false;
  String? _packageError;

  List<Amenity> _allAmenities = [];
  List<int> _selectedAmenityIds = [];
  bool _isLoadingAmenities = false;

  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedWard;
  double? _selectedLatitude;
  double? _selectedLongitude;
  bool _isResolvingAddress = false;

  bool get _isEditing => widget.isEditing;
  int? get _editingListingId => widget.initialListing?.listingId;

  final _roomTypes = const [
    RoomType(id: 1, name: 'Phòng trọ SV', icon: Icons.bed_outlined),
    RoomType(id: 2, name: 'Căn hộ DV', icon: Icons.apartment_outlined),
    RoomType(id: 3, name: 'Ở ghép', icon: Icons.people_outline),
    RoomType(id: 4, name: 'Nhà nguyên căn', icon: Icons.home_outlined),
  ];

  final _provinces = ['TP. Hồ Chí Minh', 'Hà Nội', 'Đà Nẵng', 'Cần Thơ'];
  final _districts = [
    'Quận 1',
    'Quận 2',
    'Quận 3',
    'Bình Thạnh',
    'Gò Vấp',
    'Tân Bình'
  ];
  final _wards = [
    'Phường 1',
    'Phường 2',
    'Phường 3',
    'Phường Bến Nghé',
    'Phường Đa Kao'
  ];

  List<String> get _localizedStepTitles => [
        'post_step_title_1'.tr,
        'post_step_title_2'.tr,
        'post_step_title_3'.tr,
        'post_step_title_4'.tr,
        'post_step_title_5'.tr,
      ];

  String _localizedRoomTypeName(int id) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    switch (id) {
      case 1:
        return isVi ? 'Phòng trọ SV' : 'Student Room';
      case 2:
        return isVi ? 'Căn hộ DV' : 'Service Apt';
      case 3:
        return isVi ? 'Ở ghép' : 'Shared Room';
      case 4:
        return isVi ? 'Nhà nguyên căn' : 'Whole House';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPackages();
    _loadAmenities();
    for (final c in [
      _titleCtrl,
      _descCtrl,
      _priceCtrl,
      _areaCtrl,
      _floorCtrl,
      _totalFloorsCtrl,
      _maxOccupantsCtrl,
      _streetCtrl,
      _electricCtrl,
      _waterCtrl,
      _internetCtrl,
      _parkingCtrl,
    ]) {
      c.addListener(_markDraftChanged);
    }
    if (_isEditing && widget.initialListing != null) {
      _applyInitialListing(widget.initialListing!);
    } else {
      _loadDraftFromDisk();
    }
  }

  Future<void> _loadAmenities() async {
    setState(() {
      _isLoadingAmenities = true;
    });

    try {
      final amenities = await _listingRepository.getAmenities();
      if (!mounted) return;
      setState(() {
        _allAmenities = amenities;
        if (_isEditing) {
          _syncAmenitiesFromInitialListing();
        }
        _isLoadingAmenities = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAmenities = false;
      });
      debugPrint('Lỗi tải danh sách tiện ích: $e');
    }
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _descCtrl,
      _priceCtrl,
      _areaCtrl,
      _floorCtrl,
      _totalFloorsCtrl,
      _maxOccupantsCtrl,
      _streetCtrl,
      _electricCtrl,
      _waterCtrl,
      _internetCtrl,
      _parkingCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _goTo(int s) => setState(() => _currentStep = s);
  void _next() {
    if (!_validateStepAndNotify(_currentStep)) return;
    if (_currentStep < _totalSteps - 1) _goTo(_currentStep + 1);
  }

  void _prev() {
    if (_currentStep > 0) _goTo(_currentStep - 1);
  }

  void _markDraftChanged() {
    if (_isEditing) return;
    PostListingDraftService.markDirty();
    _saveDraftToDisk();
  }

  Future<void> _saveDraftToDisk() async {
    if (_isEditing) return;
    final Map<String, dynamic> data = {
      'currentStep': _currentStep,
      'selectedTypeId': _selectedType?.id,
      'title': _titleCtrl.text,
      'desc': _descCtrl.text,
      'price': _priceCtrl.text,
      'area': _areaCtrl.text,
      'floor': _floorCtrl.text,
      'totalFloors': _totalFloorsCtrl.text,
      'maxOccupants': _maxOccupantsCtrl.text,
      'street': _streetCtrl.text,
      'electric': _electricCtrl.text,
      'water': _waterCtrl.text,
      'internet': _internetCtrl.text,
      'parking': _parkingCtrl.text,
      'allowPet': _allowPet,
      'availableFrom': _availableFrom?.toIso8601String(),
      'selectedProvince': _selectedProvince,
      'selectedDistrict': _selectedDistrict,
      'selectedWard': _selectedWard,
      'selectedLatitude': _selectedLatitude,
      'selectedLongitude': _selectedLongitude,
      'imagePaths': _slots.map((s) => s.file?.path ?? '').toList(),
      'videoPaths': _videoSlots.map((vs) => vs.file?.path ?? '').toList(),
      'selectedAmenityIds': _selectedAmenityIds,
    };
    await PostListingDraftService.saveDraft(data);
  }

  Future<void> _loadDraftFromDisk() async {
    if (_isEditing) return;
    final data = await PostListingDraftService.loadDraft();
    if (data == null) return;
    if (!mounted) return;
    setState(() {
      _currentStep = data['currentStep'] ?? 0;
      final typeId = data['selectedTypeId'];
      if (typeId != null) {
        _selectedType = _roomTypes.firstWhere((t) => t.id == typeId,
            orElse: () => _roomTypes.first);
      }
      _titleCtrl.text = data['title'] ?? '';
      _descCtrl.text = data['desc'] ?? '';
      _priceCtrl.text = data['price'] ?? '';
      _areaCtrl.text = data['area'] ?? '';
      _floorCtrl.text = data['floor'] ?? '';
      _totalFloorsCtrl.text = data['totalFloors'] ?? '';
      _maxOccupantsCtrl.text = data['maxOccupants'] ?? '1';
      _streetCtrl.text = data['street'] ?? '';
      _electricCtrl.text = data['electric'] ?? '';
      _waterCtrl.text = data['water'] ?? '';
      _internetCtrl.text = data['internet'] ?? '';
      _parkingCtrl.text = data['parking'] ?? '';
      _allowPet = data['allowPet'] ?? false;
      final avFrom = data['availableFrom'];
      if (avFrom != null) {
        _availableFrom = DateTime.tryParse(avFrom);
      }
      _selectedProvince = data['selectedProvince'];
      _selectedDistrict = data['selectedDistrict'];
      _selectedWard = data['selectedWard'];
      _selectedLatitude = data['selectedLatitude'];
      _selectedLongitude = data['selectedLongitude'];

      final List<dynamic>? amIds = data['selectedAmenityIds'];
      if (amIds != null) {
        _selectedAmenityIds = amIds.cast<int>().toList();
      }

      final List<dynamic>? imgPaths = data['imagePaths'];
      if (imgPaths != null) {
        for (int i = 0; i < imgPaths.length && i < _slots.length; i++) {
          final path = imgPaths[i] as String;
          if (path.isNotEmpty) {
            final f = File(path);
            if (f.existsSync()) {
              _slots[i].file = f;
            }
          }
        }
      }

      final List<dynamic>? vidPaths = data['videoPaths'];
      if (vidPaths != null) {
        for (int i = 0; i < vidPaths.length && i < _videoSlots.length; i++) {
          final path = vidPaths[i] as String;
          if (path.isNotEmpty) {
            final f = File(path);
            if (f.existsSync()) {
              _videoSlots[i].file = f;
            }
          }
        }
      }
    });
  }

  void _applyInitialListing(Listing listing) {
    final packageInfo = listing.packageInfo;
    if (packageInfo is Map<String, dynamic>) {
      _selectedPackage =
          PostPackage.fromJson(Map<String, dynamic>.from(packageInfo));
    }

    _selectedType = _roomTypes.firstWhere(
      (t) => t.id == listing.typeId,
      orElse: () => _roomTypes.first,
    );
    _titleCtrl.text = listing.title;
    _descCtrl.text = listing.description ?? '';
    _priceCtrl.text = listing.price.toStringAsFixed(0);
    _areaCtrl.text = listing.area.toStringAsFixed(0);
    _floorCtrl.text = listing.floor?.toString() ?? '';
    _totalFloorsCtrl.text = listing.totalFloors?.toString() ?? '';
    _maxOccupantsCtrl.text = listing.maxOccupants?.toString() ?? '1';
    _streetCtrl.text = listing.streetAddress;
    _electricCtrl.text = listing.electricPrice?.toStringAsFixed(0) ?? '';
    _waterCtrl.text = listing.waterPrice?.toStringAsFixed(0) ?? '';
    _internetCtrl.text = listing.internetPrice?.toStringAsFixed(0) ?? '';
    _parkingCtrl.text = listing.parkingPrice?.toStringAsFixed(0) ?? '';
    _allowPet = listing.allowPet;
    _availableFrom = listing.availableFrom;
    // Tin cũ có thể dùng địa danh không nằm trong bộ lựa chọn mẫu.
    // Giữ lại và thêm nó vào dropdown để form không làm mất địa chỉ khi sửa.
    _selectedProvince =
        _putAndSelect(_provinces, _normalizeProvince(listing.provinceName));
    _selectedDistrict = _putAndSelect(_districts, listing.districtName);
    _selectedWard = _putAndSelect(_wards, listing.wardName);
    _selectedLatitude = listing.latitude;
    _selectedLongitude = listing.longitude;
    _slots[0].networkUrl = listing.image0;
    _slots[1].networkUrl = listing.image1;
    _slots[2].networkUrl = listing.image2;
    _slots[3].networkUrl = listing.image3;
    _slots[4].networkUrl = listing.image4;
    _slots[5].networkUrl = listing.image5;
  }

  void _syncAmenitiesFromInitialListing() {
    final listing = widget.initialListing;
    if (listing == null || _allAmenities.isEmpty) return;

    final targetNames = listing.amenityNames.map(_addressKey).toSet();
    _selectedAmenityIds = _allAmenities
        .where((amenity) => targetNames.contains(_addressKey(amenity.name)))
        .map((amenity) => amenity.amenityId)
        .toList();
  }

  Future<void> _pickImage(int idx) async {
    if (idx >= _maxSelectableImages) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'post_img_limit_reached'
              .tr
              .replaceAll('{package}',
                  _effectivePackage?.packageName ?? 'post_package_current'.tr)
              .replaceAll('{max}', '$_maxSelectableImages'),
        ),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (picked == null) return;

    setState(() {
      _slots[idx].file = File(picked.path);
      _slots[idx].networkUrl = null;
    });
    _markDraftChanged();
  }

  void _removeImage(int idx) => setState(() {
        _slots[idx].file = null;
        _slots[idx].networkUrl = null;
        _markDraftChanged();
      });

  Future<void> _pickVideo(int idx) async {
    if (idx >= _maxSelectableVideos) return;

    final picked = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );

    if (picked == null) return;

    setState(() {
      _videoSlots[idx].file = File(picked.path);
    });
    _markDraftChanged();
  }

  void _removeVideo(int idx) => setState(() {
        _videoSlots[idx].file = null;
        _markDraftChanged();
      });

  void _swapSlots(int a, int b) => setState(() {
        final tf = _slots[a].file;
        final tu = _slots[a].networkUrl;
        _slots[a].file = _slots[b].file;
        _slots[a].networkUrl = _slots[b].networkUrl;
        _slots[b].file = tf;
        _slots[b].networkUrl = tu;
        _markDraftChanged();
      });

  int get _filledCount => _slots.where((s) => !s.isEmpty).length;
  int get _filledVideoCount => _videoSlots.where((s) => !s.isEmpty).length;
  PostPackage? get _effectivePackage =>
      _selectedPackage ??
      (_packages.where((package) => package.isFree).isNotEmpty
          ? _packages.firstWhere((package) => package.isFree)
          : null);
  bool get _shouldBuyPackage =>
      _effectivePackage != null && !_effectivePackage!.isFree;
  int get _maxSelectableImages {
    final configuredLimit = _effectivePackage?.maxImages ?? 1;
    return math.max(1, math.min(configuredLimit, _slots.length));
  }

  int get _maxSelectableVideos {
    final configuredLimit = _effectivePackage?.maxVideos ?? 0;
    return math.max(0, math.min(configuredLimit, _videoSlots.length));
  }

  Future<void> _loadPackages() async {
    setState(() {
      _isLoadingPackages = true;
      _packageError = null;
    });

    try {
      final packages = await _packageRepository.getPackages();
      if (!mounted) return;
      setState(() {
        _packages = packages;
        _selectedPackage ??=
            packages.where((package) => package.isFree).isNotEmpty
                ? packages.firstWhere((package) => package.isFree)
                : (packages.isNotEmpty ? packages.first : null);
        _isLoadingPackages = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _packageError = _cleanError(e);
        _isLoadingPackages = false;
      });
    }
  }

  void _selectPackage(PostPackage package) {
    setState(() {
      _selectedPackage = package;
      _trimImagesToPackageLimit(package);
      _markDraftChanged();
    });
  }

  void _trimImagesToPackageLimit(PostPackage package) {
    final maxImages = math.max(1, math.min(package.maxImages, _slots.length));
    for (var i = maxImages; i < _slots.length; i++) {
      _slots[i].file = null;
      _slots[i].networkUrl = null;
    }
    final maxVideos =
        math.max(0, math.min(package.maxVideos, _videoSlots.length));
    for (var i = maxVideos; i < _videoSlots.length; i++) {
      _videoSlots[i].file = null;
    }
  }

  String _cleanError(Object e) {
    final message = e.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  List<String> _helpTipsForStep(int step) {
    switch (step) {
      case 0:
        return [
          'post_help_step1_tip1'.tr,
          'post_help_step1_tip2'.tr,
          'post_help_step1_tip3'.tr,
        ];
      case 1:
        return [
          'post_help_step2_tip1'.tr,
          'post_help_step2_tip2'.tr,
          'post_help_step2_tip3'.tr,
        ];
      case 2:
        return [
          'post_help_step3_tip1'.tr,
          'post_help_step3_tip2'.tr,
          'post_help_step3_tip3'.tr,
        ];
      case 3:
        return [
          'post_help_step4_tip1'.tr,
          'post_help_step4_tip2'.tr,
          'post_help_step4_tip3'.tr,
        ];
      case 4:
        return [
          'post_help_step5_tip1'.tr,
          'post_help_step5_tip2'.tr,
          'post_help_step5_tip3'.tr,
        ];
      default:
        return const [];
    }
  }

  void _showPostHelpSheet() {
    HapticFeedback.lightImpact();
    final tips = _helpTipsForStep(_currentStep);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: sheetContext.profileCard,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppConstants.radiusXxl),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: sheetContext.profileBorder,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusFull),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.55),
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusMd),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.help_outline_rounded,
                            color: AppColors.primary, size: 21),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'post_help_sheet_title'.tr,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: sheetContext.profileText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'post_help_sheet_subtitle'.tr.replaceAll(
                                  '{title}',
                                  _localizedStepTitles[_currentStep]),
                              style: TextStyle(
                                fontSize: 12,
                                color: sheetContext.profileTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ...tips.map(
                    (tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tip,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: sheetContext.profileText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            context.push(AppConstants.routeSupportCenter);
                          },
                          icon:
                              const Icon(Icons.support_agent_rounded, size: 18),
                          label: Text('post_help_open_support'.tr),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            context.push(AppConstants.routeReportIssue);
                          },
                          icon: const Icon(Icons.bug_report_rounded, size: 18),
                          label: Text('post_help_report_issue'.tr),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatPackagePrice(double price) {
    if (price <= 0) return 'post_package_free'.tr;
    final raw = price.toInt().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buffer.write('.');
      buffer.write(raw[i]);
    }
    return '${buffer.toString()}đ';
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final validationMessage = _validateBeforeSubmit();
    if (validationMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(validationMessage),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = _buildSubmitPayload();
      final isEditing = _isEditing && _editingListingId != null;
      final created = isEditing
          ? await _listingRepository.updateListing(_editingListingId!, payload)
          : await _listingRepository.createListing(payload);
      if (!isEditing) {
        await _markCurrentUserAsLandlord();
      }

      final imageUploadMessage = await _tryUploadImages(created.listingId);
      final videoUploadMessage =
          isEditing ? null : await _tryUploadVideos(created.listingId);
      if (!mounted) return;

      if (!isEditing) {
        PostListingDraftService.clear();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(isEditing
                ? 'Cập nhật tin thành công!'
                : 'Đăng tin thành công! Đang chờ xét duyệt.'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      if (imageUploadMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(imageUploadMessage),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      if (videoUploadMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(videoUploadMessage),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      if (!isEditing && _shouldBuyPackage) {
        setState(() => _createdListingIdForVip = created.listingId);
      } else if (isEditing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.go(AppConstants.routeMyListings);
        });
      } else {
        _goAfterCurrentFrame(AppConstants.routeHome);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Đăng tin thất bại: ${e.toString()}'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _goAfterCurrentFrame(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(route);
    });
  }

  Future<void> _markCurrentUserAsLandlord() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUserRole, 'landlord');
  }

  Future<String?> _tryUploadImages(int listingId) async {
    try {
      final imageUrls = await _uploadSelectedImages(listingId).timeout(
        const Duration(seconds: 45),
      );
      if (imageUrls.isEmpty) return null;

      await _listingRepository.updateListing(listingId, {
        'image0': imageUrls.isNotEmpty ? imageUrls[0] : null,
        'image1': imageUrls.length > 1 ? imageUrls[1] : null,
        'image2': imageUrls.length > 2 ? imageUrls[2] : null,
        'image3': imageUrls.length > 3 ? imageUrls[3] : null,
        'image4': imageUrls.length > 4 ? imageUrls[4] : null,
        'image5': imageUrls.length > 5 ? imageUrls[5] : null,
      }).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      return 'post_img_upload_timeout'.tr;
    } catch (_) {
      return 'post_img_upload_failed'.tr;
    }

    return null;
  }

  Future<String?> _tryUploadVideos(int listingId) async {
    if (_maxSelectableVideos <= 0 || _filledVideoCount == 0) return null;

    try {
      await _uploadSelectedVideos(listingId).timeout(
        const Duration(seconds: 90),
      );
    } on TimeoutException {
      return 'post_video_upload_timeout'.tr;
    } catch (_) {
      return 'post_video_upload_failed'.tr;
    }

    return null;
  }

  String? _validateBeforeSubmit() {
    for (var step = 0; step < _totalSteps; step++) {
      final message = _validateStep(step);
      if (message != null) return message;
    }
    return null;
  }

  String? _validateStep(int step) {
    switch (step) {
      case 0:
        if (_selectedType == null) return 'post_validation_type'.tr;
        if (_titleCtrl.text.trim().isEmpty) {
          return 'post_validation_title'.tr;
        }
        return null;
      case 1:
        if (_slots[0].file == null && _slots[0].networkUrl == null) {
          return 'post_validation_cover'.tr;
        }
        if (_filledCount > _maxSelectableImages) {
          return 'post_validation_image_limit'
              .tr
              .replaceAll('{max}', '$_maxSelectableImages');
        }
        if (_filledVideoCount > _maxSelectableVideos) {
          return 'post_validation_video_limit'
              .tr
              .replaceAll('{max}', '$_maxSelectableVideos');
        }
        return null;
      case 2:
        if (_selectedProvince == null) return 'post_validation_province'.tr;
        if (_selectedDistrict == null) return 'post_validation_district'.tr;
        if (_selectedWard == null) return 'post_validation_ward'.tr;
        if (_streetCtrl.text.trim().isEmpty) {
          return 'post_validation_street'.tr;
        }
        return null;
      case 3:
        final area = _parseDecimal(_areaCtrl.text);
        if (area == null || area <= 0) return 'post_validation_area'.tr;
        final maxOccupants = _parseInt(_maxOccupantsCtrl.text);
        if (maxOccupants == null || maxOccupants <= 0) {
          return 'post_validation_occupants'.tr;
        }
        return null;
      case 4:
        final price = _parseDecimal(_priceCtrl.text);
        if (price == null || price <= 0) return 'post_validation_price'.tr;
        return null;
    }
    return null;
  }

  bool _validateStepAndNotify(int step) {
    final message = _validateStep(step);
    if (message == null) return true;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    return false;
  }

  Future<bool> _confirmDiscardDraft() async {
    if (_isEditing) return true;
    if (!PostListingDraftService.hasDraft.value) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('post_discard_draft_title'.tr),
        content: Text('post_discard_draft_desc'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('post_draft_stay'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('post_draft_leave'.tr),
          ),
        ],
      ),
    );

    if (shouldDiscard == true) PostListingDraftService.clear();
    return shouldDiscard == true;
  }

  Future<void> _handleBack() async {
    if (_currentStep > 0) {
      _prev();
      return;
    }
    if (_isEditing) {
      // Dùng pop() vì đã vào màn hình sửa bằng push()
      if (mounted) context.pop();
      return;
    }
    final router = GoRouter.of(context);
    if (await _confirmDiscardDraft() && mounted) {
      router.go(AppConstants.routeHome);
    }
  }

  Map<String, dynamic> _buildSubmitPayload() {
    return {
      'title': _titleCtrl.text.trim(),
      'description':
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'price': _parseDecimal(_priceCtrl.text)!,
      'area': _parseDecimal(_areaCtrl.text)!,
      'typeId': _selectedType!.id,
      'streetAddress': _fullStreetAddress(),
      'provinceId': null,
      'districtId': null,
      'wardId': null,
      'latitude': _selectedLatitude,
      'longitude': _selectedLongitude,
      'floor': _parseInt(_floorCtrl.text),
      'totalFloors': _parseInt(_totalFloorsCtrl.text),
      'maxOccupants': _parseInt(_maxOccupantsCtrl.text),
      'electricPrice': _parseDecimal(_electricCtrl.text),
      'waterPrice': _parseDecimal(_waterCtrl.text),
      'internetPrice': _parseDecimal(_internetCtrl.text),
      'parkingPrice': _parseDecimal(_parkingCtrl.text),
      'allowPet': _allowPet,
      'availableFrom': _availableFrom?.toIso8601String().split('T').first,
      'amenityIds': _selectedAmenityIds,
      'image0': _maxSelectableImages > 0 ? _slots[0].networkUrl : null,
      'image1': _maxSelectableImages > 1 ? _slots[1].networkUrl : null,
      'image2': _maxSelectableImages > 2 ? _slots[2].networkUrl : null,
      'image3': _maxSelectableImages > 3 ? _slots[3].networkUrl : null,
      'image4': _maxSelectableImages > 4 ? _slots[4].networkUrl : null,
      'image5': _maxSelectableImages > 5 ? _slots[5].networkUrl : null,
    };
  }

  Future<List<String>> _uploadSelectedImages(int listingId) async {
    final urls = <String>[];

    for (final slot in _slots.take(_maxSelectableImages)) {
      if (slot.file == null) {
        if (slot.networkUrl != null) {
          urls.add(slot.networkUrl!);
        }
        continue;
      }

      final url = await _listingRepository.uploadListingImage(
        listingId: listingId,
        filePath: slot.file!.path,
        isCover: slot.slotIndex == 0,
      );
      slot.networkUrl = url;
      urls.add(url);
    }

    return urls;
  }

  Future<List<String>> _uploadSelectedVideos(int listingId) async {
    final urls = <String>[];

    for (final slot in _videoSlots.take(_maxSelectableVideos)) {
      if (slot.file == null) continue;
      final url = await _listingRepository.uploadListingVideo(
        listingId: listingId,
        filePath: slot.file!.path,
      );
      urls.add(url);
    }

    return urls;
  }

  double? _parseDecimal(String value) {
    final normalized = value.replaceAll('.', '').replaceAll(',', '').trim();
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  int? _parseInt(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    return int.tryParse(normalized);
  }

  String _fullStreetAddress() {
    return [
      _streetCtrl.text.trim(),
      if (_selectedWard?.trim().isNotEmpty == true) _selectedWard!.trim(),
      if (_selectedDistrict?.trim().isNotEmpty == true)
        _selectedDistrict!.trim(),
      if (_selectedProvince?.trim().isNotEmpty == true)
        _selectedProvince!.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
  }

  Future<void> _openLocationPicker() async {
    final initialPoint = _selectedLatitude != null && _selectedLongitude != null
        ? LatLng(_selectedLatitude!, _selectedLongitude!)
        : const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);

    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _LocationPickerScreen(initialPoint: initialPoint),
      ),
    );

    if (picked == null || !mounted) return;

    // Kiểm tra xem vị trí có thực sự thay đổi không (sai lệch > 0.00001 độ ~1m)
    final locationChanged = _selectedLatitude == null ||
        _selectedLongitude == null ||
        (picked.latitude - _selectedLatitude!).abs() > 0.00001 ||
        (picked.longitude - _selectedLongitude!).abs() > 0.00001;

    setState(() {
      _selectedLatitude = picked.latitude;
      _selectedLongitude = picked.longitude;
      _markDraftChanged();
    });
    if (!locationChanged) return;
    await _fillAddressFromCoordinates(picked);
  }

  Future<void> _fillAddressFromCoordinates(LatLng point) async {
    setState(() => _isResolvingAddress = true);

    try {
      final response = await Dio().get<Map<String, dynamic>>(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'jsonv2',
          'lat': point.latitude,
          'lon': point.longitude,
          'addressdetails': 1,
          'accept-language': 'vi',
        },
        options: Options(headers: {
          'User-Agent': 'SwingsHouse/1.0 (development)',
        }),
      );

      final body = response.data ?? {};
      final addressRaw = body['address'];
      if (addressRaw is! Map) return;
      final address = Map<String, dynamic>.from(addressRaw);

      final province = _normalizeProvince(_firstNonEmpty([
        address['state'],
        address['province'],
        address['city'],
      ]));
      final district = _firstNonEmpty([
        address['city_district'],
        address['city'],
        address['district'],
        address['county'],
        address['suburb'],
      ]);
      final ward = _firstNonEmpty([
        address['quarter'],
        address['neighbourhood'],
        address['suburb'],
        address['village'],
      ]);
      final street = _composeStreetAddress(address);

      if (!mounted) return;
      setState(() {
        _selectedProvince = _putAndSelect(_provinces, province);
        _selectedDistrict = _putAndSelect(_districts, district);
        _selectedWard = _putAndSelect(_wards, ward);
        if (street.isNotEmpty) _streetCtrl.text = street;
        _markDraftChanged();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('post_address_resolve_error'.tr),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResolvingAddress = false);
    }
  }

  String? _putAndSelect(List<String> items, String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;

    final existing = items.where(
      (item) => _addressKey(item) == _addressKey(normalized),
    );
    if (existing.isNotEmpty) return existing.first;

    items.add(normalized);
    return normalized;
  }

  String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  String _normalizeProvince(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return '';
    final key = _addressKey(text);
    if (key.contains('ho chi minh') || key.contains('sai gon')) {
      return 'TP. Hồ Chí Minh';
    }
    if (key.contains('ha noi')) return 'Hà Nội';
    if (key.contains('da nang')) return 'Đà Nẵng';
    if (key.contains('can tho')) return 'Cần Thơ';
    return text;
  }

  String _composeStreetAddress(Map<String, dynamic> address) {
    final houseNumber = address['house_number']?.toString().trim();
    final road = address['road']?.toString().trim();
    final parts = [
      if (houseNumber != null && houseNumber.isNotEmpty) houseNumber,
      if (road != null && road.isNotEmpty) road,
    ];
    return parts.join(' ');
  }

  String _addressKey(String value) {
    const from =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const to =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    var result = value.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      result = result.replaceAll(from[i], to[i]);
    }
    return result.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final vipListingId = _createdListingIdForVip;
    if (vipListingId != null) {
      return PackageScreen(
        listingId: vipListingId,
        initialPackageId: _effectivePackage?.packageId,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: context.profileBg,
        body: Column(children: [
          _Header(
            step: _currentStep,
            total: _totalSteps,
            title: _localizedStepTitles[_currentStep],
            onBack: _handleBack,
            onHelp: _showPostHelpSheet,
            isEditing: _isEditing,
          ),
          _StepBar(current: _currentStep, total: _totalSteps),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_currentStep),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: [
                    _buildStep1(),
                    _buildStepImages(),
                    _buildStep3(),
                    _buildStep4(),
                    _buildStep5(),
                  ][_currentStep],
                ),
              ),
            ),
          ),
          _BottomNav(
            currentStep: _currentStep,
            totalSteps: _totalSteps,
            isSubmitting: _isSubmitting,
            isEditing: _isEditing,
            onNext: _next,
            onPrev: _prev,
            onSubmit: () {
              _submit();
            },
          ),
        ]),
      ),
    );
  }

  // ── Step 1: Loại hình & Tiêu đề ──────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'post_room_type_section'.tr,
          icon: Icons.category_outlined,
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.5,
            children: _roomTypes.map((t) {
              final sel = _selectedType?.id == t.id;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedType = t;
                  _markDraftChanged();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : context.profileCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? AppColors.primary : context.profileBorder,
                      width: sel ? 2 : 1,
                    ),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(t.icon,
                          color: sel ? Colors.white : AppColors.primary,
                          size: 20),
                      const SizedBox(width: 8),
                      Text(_localizedRoomTypeName(t.id),
                          style: TextStyle(
                            color: sel ? Colors.white : context.profileText,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'post_basic_info_section'.tr,
          icon: Icons.edit_outlined,
          child: Column(children: [
            _InputField(
              ctrl: _titleCtrl,
              label: 'post_title_label'.tr,
              hint: 'post_title_hint'.tr,
              maxLength: 200,
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            _InputField(
              ctrl: _descCtrl,
              label: 'post_desc_label'.tr,
              hint: 'post_desc_hint'.tr,
              maxLines: 4,
              maxLength: 2000,
            ),
          ]),
        ),
        const SizedBox(height: 14),
        _buildPackageSelector(),
      ],
    );
  }

  Widget _buildPackageSelector() {
    if (_isLoadingPackages) {
      return _SectionCard(
        title: 'post_package_section'.tr,
        icon: Icons.workspace_premium_outlined,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    if (_packageError != null) {
      return _SectionCard(
        title: 'post_package_section'.tr,
        icon: Icons.workspace_premium_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _packageError!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loadPackages,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('post_package_reload'.tr),
            ),
          ],
        ),
      );
    }

    return _SectionCard(
      title: 'post_package_section'.tr,
      icon: Icons.workspace_premium_outlined,
      child: Column(
        children: _packages
            .map(
              (package) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PackageChoiceTile(
                  package: package,
                  selected: _effectivePackage?.packageId == package.packageId,
                  imageLimit:
                      math.max(1, math.min(package.maxImages, _slots.length)),
                  priceLabel: _formatPackagePrice(package.price),
                  onTap: () => _selectPackage(package),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ── Step 2: ẢNH PHÒNG ────────────────────────
  Widget _buildStepImages() {
    final maxImages = _maxSelectableImages;
    final maxVideos = _maxSelectableVideos;
    final packageName =
        _effectivePackage?.packageName ?? 'post_package_current'.tr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner hướng dẫn
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'post_img_banner_title'
                            .tr
                            .replaceAll('{max}', '$maxImages'),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: context.profileText)),
                    const SizedBox(height: 4),
                    Text(
                      'post_img_banner_desc'
                          .tr
                          .replaceAll('{package}', packageName)
                          .replaceAll('{max}', '$maxImages'),
                      style: TextStyle(
                          fontSize: 12,
                          color: context.profileText.withValues(alpha: 0.7),
                          height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Counter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('post_img_list_title'.tr,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: context.profileText)),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _filledCount > 0
                    ? AppColors.primaryLight.withValues(alpha: 0.6)
                    : context.profileBorder.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'post_img_count'
                    .tr
                    .replaceAll('{current}', '$_filledCount')
                    .replaceAll('{max}', '$maxImages'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _filledCount > 0
                      ? AppColors.primary
                      : context.profileText.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Slot 0: Ảnh bìa (to)
        _ImageSlotCard(
          slot: _slots[0],
          isCoverLayout: true,
          onPick: () => _pickImage(0),
          onRemove: () => _removeImage(0),
        ),
        const SizedBox(height: 10),

        if (maxImages > 1)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.2,
            ),
            itemCount: maxImages - 1,
            itemBuilder: (_, i) => _ImageSlotCard(
              slot: _slots[i + 1],
              isCoverLayout: false,
              onPick: () => _pickImage(i + 1),
              onRemove: () => _removeImage(i + 1),
              onMakeCover:
                  _slots[i + 1].isEmpty ? null : () => _swapSlots(0, i + 1),
            ),
          ),
        const SizedBox(height: 14),
        if (_isEditing)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.25),
              ),
            ),
            child: const Text(
              'Chỉnh sửa hiện chưa hỗ trợ thay đổi video.',
              style: TextStyle(color: AppColors.warningText, height: 1.4),
            ),
          )
        else
          _buildVideoSection(maxVideos),
        const SizedBox(height: 14),

        // Tip
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.successBg,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppColors.success.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            const Icon(Icons.lightbulb_outline,
                color: AppColors.success, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'post_img_tip'.tr,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.successText, height: 1.4),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildVideoSection(int maxVideos) {
    if (maxVideos <= 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.videocam_off_outlined,
                color: AppColors.warning, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'post_video_not_supported'.tr,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.warningText, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return _SectionCard(
      title: 'post_video_section'.tr,
      icon: Icons.video_library_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('post_video_list'.tr,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: context.profileText)),
              Text(
                'post_video_count'
                    .tr
                    .replaceAll('{current}', '$_filledVideoCount')
                    .replaceAll('{max}', '$maxVideos'),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(
            maxVideos,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _VideoSlotCard(
                slot: _videoSlots[index],
                onPick: () => _pickVideo(index),
                onRemove: () => _removeVideo(index),
              ),
            ),
          ),
          Text(
            'post_video_specs'.tr,
            style: TextStyle(
                fontSize: 12,
                color: context.profileText.withValues(alpha: 0.7),
                height: 1.4),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Địa chỉ ──────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'post_address_section'.tr,
          icon: Icons.location_on_outlined,
          child: Column(children: [
            _DropdownField(
              label: 'post_province_label'.tr,
              value: _selectedProvince,
              items: _provinces,
              onChanged: (v) => setState(() {
                _selectedProvince = v;
                _selectedDistrict = null;
                _selectedWard = null;
                _markDraftChanged();
              }),
            ),
            const SizedBox(height: 14),
            _DropdownField(
              label: 'post_district_label'.tr,
              value: _selectedDistrict,
              items: _districts,
              enabled: _selectedProvince != null,
              onChanged: (v) => setState(() {
                _selectedDistrict = v;
                _selectedWard = null;
                _markDraftChanged();
              }),
            ),
            const SizedBox(height: 14),
            _DropdownField(
              label: 'post_ward_label'.tr,
              value: _selectedWard,
              items: _wards,
              enabled: _selectedDistrict != null,
              onChanged: (v) => setState(() {
                _selectedWard = v;
                _markDraftChanged();
              }),
            ),
            const SizedBox(height: 14),
            _InputField(
              ctrl: _streetCtrl,
              label: 'post_street_label'.tr,
              hint: 'post_street_hint'.tr,
              prefixIcon: Icons.edit_location_alt_outlined,
            ),
          ]),
        ),
        const SizedBox(height: 14),
        _MapPickerPreview(
          latitude: _selectedLatitude,
          longitude: _selectedLongitude,
          isResolvingAddress: _isResolvingAddress,
          onTap: _openLocationPicker,
        ),
      ],
    );
  }

  // ── Step 4: Chi tiết ─────────────────────────
  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'post_details_area_section'.tr,
          icon: Icons.straighten_outlined,
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: _InputField(
                      ctrl: _areaCtrl,
                      label: 'post_details_area_label'.tr,
                      hint: '25',
                      keyboardType: TextInputType.number,
                      suffixText: 'm2')),
              const SizedBox(width: 12),
              Expanded(
                  child: _InputField(
                      ctrl: _maxOccupantsCtrl,
                      label: 'post_details_occupants_label'.tr,
                      hint: '1',
                      keyboardType: TextInputType.number,
                      suffixText: 'post_details_occupants_unit'.tr)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: _InputField(
                      ctrl: _floorCtrl,
                      label: 'post_details_floor_label'.tr,
                      hint: '3',
                      keyboardType: TextInputType.number,
                      suffixText: 'post_details_floor_unit'.tr)),
              const SizedBox(width: 12),
              Expanded(
                  child: _InputField(
                      ctrl: _totalFloorsCtrl,
                      label: 'post_details_total_floors_label'.tr,
                      hint: '5',
                      keyboardType: TextInputType.number,
                      suffixText: 'post_details_floor_unit'.tr)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'post_details_available_section'.tr,
          icon: Icons.calendar_today_outlined,
          child: _DatePickerTile(
            date: _availableFrom,
            onTap: () async {
              final p = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: AppColors.primary,
                      brightness: Theme.of(context).brightness,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (p != null) {
                setState(() {
                  _availableFrom = p;
                  _markDraftChanged();
                });
              }
            },
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'post_policy_section'.tr,
          icon: Icons.policy_outlined,
          child: _ToggleTile(
            value: _allowPet,
            onChanged: (v) => setState(() {
              _allowPet = v;
              _markDraftChanged();
            }),
            icon: Icons.pets_outlined,
            activeColor: AppColors.success,
            title: 'post_policy_pet_title'.tr,
            subtitle: 'post_policy_pet_desc'.tr,
          ),
        ),
      ],
    );
  }

  // ── Step 5: Giá & Preview ────────────────────
  Widget _buildStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'post_price_section'.tr,
          icon: Icons.payments_outlined,
          child: _InputField(
            ctrl: _priceCtrl,
            label: 'post_price_label'.tr,
            hint: '3500000',
            keyboardType: TextInputType.number,
            suffixText: 'post_price_unit'.tr,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            isLarge: true,
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'post_services_section'.tr,
          icon: Icons.receipt_long_outlined,
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: _InputField(
                      ctrl: _electricCtrl,
                      label: 'post_service_electric'.tr,
                      hint: '3500',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.bolt_outlined)),
              const SizedBox(width: 12),
              Expanded(
                  child: _InputField(
                      ctrl: _waterCtrl,
                      label: 'post_service_water'.tr,
                      hint: '15000',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.water_drop_outlined)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: _InputField(
                      ctrl: _internetCtrl,
                      label: 'post_service_internet'.tr,
                      hint: '100000',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.wifi_outlined)),
              const SizedBox(width: 12),
              Expanded(
                  child: _InputField(
                      ctrl: _parkingCtrl,
                      label: 'post_service_parking'.tr,
                      hint: '100000',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.directions_car_outlined)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'post_amenities_section'.tr,
          icon: Icons.checklist_outlined,
          child: _isLoadingAmenities
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : _allAmenities.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'post_amenities_empty'.tr,
                        style: TextStyle(
                            color: context.profileText.withValues(alpha: 0.6),
                            fontSize: 13),
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allAmenities.map((amenity) {
                        final isSelected =
                            _selectedAmenityIds.contains(amenity.amenityId);
                        return FilterChip(
                          selected: isSelected,
                          label: Text(
                            amenity.name,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : context.profileText,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          selectedColor: AppColors.primary,
                          checkmarkColor: Colors.white,
                          backgroundColor:
                              context.profileCard.withValues(alpha: 0.5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : context.profileBorder,
                            ),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedAmenityIds.add(amenity.amenityId);
                              } else {
                                _selectedAmenityIds.remove(amenity.amenityId);
                              }
                            });
                            _markDraftChanged();
                          },
                        );
                      }).toList(),
                    ),
        ),
        const SizedBox(height: 14),
        _PreviewCard(
          coverSlot: _slots[0],
          title: _titleCtrl.text.isEmpty
              ? 'post_preview_no_title'.tr
              : _titleCtrl.text,
          typeName: _selectedType != null
              ? _localizedRoomTypeName(_selectedType!.id)
              : 'post_preview_no_type'.tr,
          price: _priceCtrl.text.isEmpty
              ? 'post_preview_no_price'.tr
              : '${_priceCtrl.text} ${'post_price_unit'.tr}',
          address: _streetCtrl.text.isEmpty
              ? 'post_preview_no_address'.tr
              : _streetCtrl.text,
          isFeatured: _shouldBuyPackage,
          imageCount: _filledCount,
          videoCount: _filledVideoCount,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// ImageSlotCard
// ─────────────────────────────────────────────
class _ImageSlotCard extends StatelessWidget {
  final ImageSlot slot;
  final bool isCoverLayout;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final VoidCallback? onMakeCover;

  const _ImageSlotCard({
    required this.slot,
    required this.isCoverLayout,
    required this.onPick,
    required this.onRemove,
    this.onMakeCover,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = !slot.isEmpty;
    final h = isCoverLayout ? 220.0 : 130.0;

    return GestureDetector(
      onTap: hasImage ? null : onPick,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: hasImage
              ? Colors.black
              : context.profileCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasImage
                ? Colors.transparent
                : isCoverLayout
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : context.profileBorder,
            width: (isCoverLayout && !hasImage) ? 2 : 1,
          ),
          boxShadow: hasImage
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Ảnh hoặc placeholder
              if (hasImage)
                _SlotImage(file: slot.file)
              else
                _EmptySlot(isCover: isCoverLayout, slotIndex: slot.slotIndex),

              // Overlay khi có ảnh
              if (hasImage) ...[
                // Gradient dưới
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 65,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // Badge bìa
                if (isCoverLayout)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.tagHot,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.tagHot.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text('post_img_cover'.tr,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),

                // Số slot
                Positioned(
                  bottom: 8,
                  left: 10,
                  child: Text(
                    isCoverLayout
                        ? 'post_img_slot_cover'.tr
                        : 'post_img_slot_index'
                            .tr
                            .replaceAll('{index}', '${slot.slotIndex + 1}'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),

                // Action buttons
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(children: [
                    if (!isCoverLayout && onMakeCover != null) ...[
                      _ActionBtn(
                        icon: Icons.star_border_rounded,
                        color: AppColors.tagHot,
                        tooltip: 'post_tooltip_make_cover'.tr,
                        onTap: onMakeCover!,
                      ),
                      const SizedBox(width: 5),
                    ],
                    _ActionBtn(
                      icon: Icons.edit_outlined,
                      color: AppColors.primary,
                      tooltip: 'post_tooltip_change_img'.tr,
                      onTap: onPick,
                    ),
                    const SizedBox(width: 5),
                    _ActionBtn(
                      icon: Icons.delete_outline,
                      color: AppColors.error,
                      tooltip: 'post_tooltip_delete'.tr,
                      onTap: onRemove,
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotImage extends StatelessWidget {
  final File? file;
  const _SlotImage({required this.file});

  @override
  Widget build(BuildContext context) {
    if (file == null || file!.path.startsWith('picked_')) {
      // Demo placeholder
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.illus1.withValues(alpha: 0.8),
              AppColors.illus2.withValues(alpha: 0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.image, color: Colors.white, size: 40),
        ),
      );
    }
    return Image.file(file!, fit: BoxFit.cover);
  }
}

class _EmptySlot extends StatelessWidget {
  final bool isCover;
  final int slotIndex;
  const _EmptySlot({required this.isCover, required this.slotIndex});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: isCover ? 54 : 40,
          height: isCover ? 54 : 40,
          decoration: BoxDecoration(
            color: isCover
                ? AppColors.primaryLight.withValues(alpha: 0.5)
                : context.profileBorder.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCover
                ? Icons.add_photo_alternate_outlined
                : Icons.add_a_photo_outlined,
            color: isCover
                ? AppColors.primary
                : context.profileText.withValues(alpha: 0.5),
            size: isCover ? 26 : 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isCover
              ? 'post_img_add_cover'.tr
              : 'post_img_add_extra'
                  .tr
                  .replaceAll('{index}', '${slotIndex + 1}'),
          style: TextStyle(
            color: isCover
                ? AppColors.primary
                : context.profileText.withValues(alpha: 0.5),
            fontSize: isCover ? 13 : 11,
            fontWeight: isCover ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        if (isCover) ...[
          const SizedBox(height: 3),
          Text(
            'post_img_click_gallery'.tr,
            style: TextStyle(
                color: context.profileText.withValues(alpha: 0.5),
                fontSize: 11),
          ),
        ],
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 1),
              )
            ],
          ),
          child: Icon(icon, color: color, size: 15),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared UI Components
// ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  final int step, total;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onHelp;
  final bool isEditing;
  const _Header({
    required this.step,
    required this.total,
    required this.title,
    required this.onBack,
    required this.onHelp,
    this.isEditing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.primaryMedium
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      isEditing
                          ? 'post_header_edit_title'.tr
                          : 'post_header_title'.tr,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  Text(
                      'post_header_step'
                          .tr
                          .replaceAll('{step}', '${step + 1}')
                          .replaceAll('{total}', '$total')
                          .replaceAll('{title}', title),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12)),
                ],
              ),
            ),
            GestureDetector(
              onTap: onHelp,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.help_outline, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text('post_help'.tr,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  final int current, total;
  const _StepBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final labels = [
      'post_label_type'.tr,
      'post_label_photos'.tr,
      'post_label_address'.tr,
      'post_label_details'.tr,
      'post_label_pricing'.tr,
    ];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.primaryMedium
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: Column(children: [
        // Progress bars
        Row(
          children: List.generate(total, (i) {
            final a = i == current;
            final d = i < current;
            return Expanded(
              child: Row(children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    decoration: BoxDecoration(
                      color: (a || d)
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (i < total - 1) const SizedBox(width: 4),
              ]),
            );
          }),
        ),
        const SizedBox(height: 10),
        // Step dots
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            total,
            (i) => _StepDot(
              index: i,
              isActive: i == current,
              isDone: i < current,
              label: labels[i],
            ),
          ),
        ),
      ]),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final bool isActive, isDone;
  final String label;
  const _StepDot({
    required this.index,
    required this.isActive,
    required this.isDone,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: isActive ? 28 : 22,
        height: isActive ? 28 : 22,
        decoration: BoxDecoration(
          color: (isDone || isActive)
              ? Colors.white
              : Colors.white.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Center(
          child: isDone
              ? const Icon(Icons.check, color: AppColors.primary, size: 14)
              : Text('${index + 1}',
                  style: TextStyle(
                    color: isActive ? AppColors.primary : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  )),
        ),
      ),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: isActive ? 1.0 : 0.65),
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          )),
    ]);
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: context.profileText)),
            ]),
          ),
          Divider(height: 1, color: context.profileBorder),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

class _PackageChoiceTile extends StatelessWidget {
  final PostPackage package;
  final bool selected;
  final int imageLimit;
  final String priceLabel;
  final VoidCallback onTap;

  const _PackageChoiceTile({
    required this.package,
    required this.selected,
    required this.imageLimit,
    required this.priceLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = package.isFeatured
        ? AppColors.tagHot
        : package.isVip
            ? AppColors.primary
            : context.profileText.withValues(alpha: 0.7);
    final videoLabel = package.maxVideos > 0
        ? 'post_preview_videos'.tr.replaceAll('{count}', '${package.maxVideos}')
        : 'post_video_none'.tr;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.08)
              : context.profileCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : context.profileBorder,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: accent,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.packageName,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'post_package_desc'
                        .tr
                        .replaceAll('{photos}', '$imageLimit')
                        .replaceAll('{videos}', videoLabel)
                        .replaceAll('{days}', '${package.durationDays}'),
                    style: TextStyle(
                      color: context.profileText.withValues(alpha: 0.7),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              priceLabel,
              style: TextStyle(
                color: context.profileText,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? suffixText;
  final IconData? prefixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final bool isLarge;

  const _InputField({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.suffixText,
    this.prefixIcon,
    this.inputFormatters,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.profileText.withValues(alpha: 0.7))),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLength: maxLength,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(
            fontSize: isLarge ? 18 : 14,
            fontWeight: isLarge ? FontWeight.w700 : FontWeight.normal,
            color: context.profileText,
          ),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            hintStyle: TextStyle(
                color: context.profileText.withValues(alpha: 0.5),
                fontSize: 13),
            suffixText: suffixText,
            suffixStyle: TextStyle(
                color: context.profileText.withValues(alpha: 0.7),
                fontSize: 12),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppColors.primary, size: 18)
                : null,
            filled: true,
            fillColor: context.profileCard.withValues(alpha: 0.5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.profileBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.profileBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.profileText.withValues(alpha: 0.7))),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: enabled ? onChanged : null,
          dropdownColor: context.profileCard,
          hint: Text('post_select_field'.tr.replaceAll('{field}', label),
              style: TextStyle(
                  color: context.profileText.withValues(alpha: 0.5),
                  fontSize: 13)),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e,
                        style: TextStyle(
                            fontSize: 14, color: context.profileText)),
                  ))
              .toList(),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.primary),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled
                ? context.profileCard.withValues(alpha: 0.5)
                : context.profileBorder.withValues(alpha: 0.5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.profileBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.profileBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;
  final Color activeColor;
  final String title, subtitle;

  const _ToggleTile({
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.activeColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: value
              ? activeColor.withValues(alpha: 0.08)
              : context.profileCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? activeColor : context.profileBorder,
            width: value ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: value
                  ? activeColor.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: value
                    ? activeColor
                    : context.profileText.withValues(alpha: 0.7),
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: value ? activeColor : context.profileText,
                        fontSize: 13)),
                Text(subtitle,
                    style: TextStyle(
                        color: context.profileText.withValues(alpha: 0.7),
                        fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: activeColor,
            activeTrackColor: activeColor.withValues(alpha: 0.35),
          ),
        ]),
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final DateTime? date;
  final VoidCallback onTap;
  const _DatePickerTile({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.profileCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: date != null ? AppColors.primary : context.profileBorder,
            width: date != null ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(Icons.event_available_outlined,
              color: date != null
                  ? AppColors.primary
                  : context.profileText.withValues(alpha: 0.5),
              size: 20),
          const SizedBox(width: 10),
          Text(
            date != null
                ? 'post_details_date_format'
                    .tr
                    .replaceAll('{day}', date!.day.toString().padLeft(2, '0'))
                    .replaceAll(
                        '{month}', date!.month.toString().padLeft(2, '0'))
                    .replaceAll('{year}', '${date!.year}')
                : 'post_details_available_hint'.tr,
            style: TextStyle(
              color: date != null
                  ? context.profileText
                  : context.profileText.withValues(alpha: 0.5),
              fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: date != null
                  ? AppColors.primary
                  : context.profileText.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }
}

class _VideoSlotCard extends StatelessWidget {
  final VideoSlot slot;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _VideoSlotCard({
    required this.slot,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasVideo = !slot.isEmpty;
    return InkWell(
      onTap: hasVideo ? null : onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasVideo
              ? AppColors.primaryLight
              : context.profileCard.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasVideo ? AppColors.primary : context.profileBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                hasVideo
                    ? Icons.play_circle_outline_rounded
                    : Icons.video_call_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasVideo
                    ? slot.fileName
                    : 'post_video_hint'
                        .tr
                        .replaceAll('{index}', '${slot.slotIndex + 1}'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.profileText,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            if (hasVideo)
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, color: AppColors.error),
              )
            else
              const Icon(Icons.add_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _MapPickerPreview extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final bool isResolvingAddress;
  final VoidCallback onTap;

  const _MapPickerPreview({
    required this.latitude,
    required this.longitude,
    required this.isResolvingAddress,
    required this.onTap,
  });

  bool get _hasLocation => latitude != null && longitude != null;

  @override
  Widget build(BuildContext context) {
    final point = _hasLocation
        ? LatLng(latitude!, longitude!)
        : const LatLng(AppConstants.defaultLat, AppConstants.defaultLng);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          color: context.profileCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: _hasLocation ? 15 : 11,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: _mapTileUrlTemplate,
                    userAgentPackageName: 'com.example.ung_dung_tim_kiem_tro',
                  ),
                  if (_hasLocation)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.error,
                            size: 42,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              Positioned.fill(
                child: Container(
                  color:
                      Colors.black.withValues(alpha: _hasLocation ? 0 : 0.08),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.profileCard.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _hasLocation
                            ? Icons.location_on
                            : Icons.add_location_alt_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isResolvingAddress
                              ? 'post_map_resolving'.tr
                              : _hasLocation
                                  ? '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}'
                                  : 'post_map_select_hint'.tr,
                          style: TextStyle(
                            color: context.profileText,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationPickerScreen extends StatefulWidget {
  final LatLng initialPoint;

  const _LocationPickerScreen({required this.initialPoint});

  @override
  State<_LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<_LocationPickerScreen> {
  late final MapController _mapController;
  final TextEditingController _mapSearchCtrl = TextEditingController();
  late LatLng _selectedPoint;
  Timer? _mapSearchDebounce;
  bool _isLocating = false;
  bool _isSearchingAddress = false;
  bool _hasAddressSearchCompleted = false;
  List<_OsmSearchResult> _addressResults = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedPoint = widget.initialPoint;
  }

  @override
  void dispose() {
    _mapSearchDebounce?.cancel();
    _mapSearchCtrl.dispose();
    super.dispose();
  }

  void _onMapSearchChanged(String value) {
    _mapSearchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      setState(() {
        _addressResults = [];
        _hasAddressSearchCompleted = false;
      });
      return;
    }

    setState(() => _hasAddressSearchCompleted = false);

    _mapSearchDebounce = Timer(
      const Duration(milliseconds: 550),
      () => _searchAddress(query),
    );
  }

  Future<void> _searchAddress(String query) async {
    setState(() => _isSearchingAddress = true);

    try {
      final response = await Dio().get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'format': 'jsonv2',
          'q': query,
          'countrycodes': 'vn',
          'addressdetails': 1,
          'limit': 5,
          'accept-language': Localizations.localeOf(context).languageCode,
        },
        options: Options(headers: {
          'User-Agent': 'SwingsHouse/1.0 (development)',
        }),
      );

      final results = (response.data ?? [])
          .whereType<Map>()
          .map((item) =>
              _OsmSearchResult.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.displayName.trim().isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _addressResults = results;
        _hasAddressSearchCompleted = true;
      });
    } catch (_) {
      if (!mounted) return;
      _showMessage('post_map_search_error'.tr);
    } finally {
      if (mounted) setState(() => _isSearchingAddress = false);
    }
  }

  void _selectAddressResult(_OsmSearchResult result) {
    setState(() {
      _selectedPoint = result.point;
      _addressResults = [];
      _hasAddressSearchCompleted = false;
      _mapSearchCtrl.text = result.displayName;
    });
    FocusScope.of(context).unfocus();
    _mapController.move(result.point, 16);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('post_map_no_service'.tr);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('post_map_no_permission'.tr);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final point = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() => _selectedPoint = point);
      _mapController.move(point, 16);
    } catch (_) {
      if (!mounted) return;
      _showMessage('post_map_err_get_pos'.tr);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPoint,
              initialZoom: 15,
              onTap: (_, point) => setState(() => _selectedPoint = point),
            ),
            children: [
              TileLayer(
                urlTemplate: _mapTileUrlTemplate,
                userAgentPackageName: 'com.example.ung_dung_tim_kiem_tro',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedPoint,
                    width: 52,
                    height: 52,
                    child: const Icon(
                      Icons.location_on,
                      color: AppColors.error,
                      size: 48,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _MapRoundButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: context.profileCard,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                    alpha: context.isDarkProfile ? 0.2 : 0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            'post_map_tap_instruction'.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: context.profileText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _MapRoundButton(
                        icon: Icons.my_location_rounded,
                        isLoading: _isLocating,
                        onTap: _useCurrentLocation,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _MapSearchBox(
                    controller: _mapSearchCtrl,
                    isLoading: _isSearchingAddress,
                    onChanged: _onMapSearchChanged,
                  ),
                  if (_addressResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _MapSearchResults(
                      results: _addressResults,
                      onTap: _selectAddressResult,
                    ),
                  ] else if (_mapSearchCtrl.text.trim().length >= 3 &&
                      _hasAddressSearchCompleted &&
                      !_isSearchingAddress) ...[
                    const SizedBox(height: 8),
                    _MapSearchEmpty(),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.profileCard,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: context.isDarkProfile ? 0.25 : 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'post_map_selected_pos'.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: context.profileText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_selectedPoint.latitude.toStringAsFixed(6)}, ${_selectedPoint.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      color: context.profileTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pop(_selectedPoint),
                      icon: const Icon(Icons.check_rounded),
                      label: Text('post_map_use_pos'.tr),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapSearchBox extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final ValueChanged<String> onChanged;

  const _MapSearchBox({
    required this.controller,
    required this.isLoading,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: context.isDarkProfile ? 0.2 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(
          color: context.profileText,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'post_map_search_hint'.tr,
          hintStyle: TextStyle(
            color: context.profileTextSecondary,
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.primary,
          ),
          suffixIcon: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

class _MapSearchResults extends StatelessWidget {
  final List<_OsmSearchResult> results;
  final ValueChanged<_OsmSearchResult> onTap;

  const _MapSearchResults({
    required this.results,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: context.isDarkProfile ? 0.2 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: results.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: context.profileBorder,
        ),
        itemBuilder: (context, index) {
          final result = results[index];
          return ListTile(
            dense: true,
            leading: const Icon(
              Icons.place_outlined,
              color: AppColors.primary,
            ),
            title: Text(
              result.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.profileText,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            onTap: () => onTap(result),
          );
        },
      ),
    );
  }
}

class _MapSearchEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: context.isDarkProfile ? 0.2 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        'post_map_search_empty'.tr,
        style: TextStyle(
          color: context.profileTextSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _MapRoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;

  const _MapRoundButton({
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, color: AppColors.primary),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final ImageSlot coverSlot;
  final String title, typeName, price, address;
  final bool isFeatured;
  final int imageCount;
  final int videoCount;

  const _PreviewCard({
    required this.coverSlot,
    required this.title,
    required this.typeName,
    required this.price,
    required this.address,
    required this.isFeatured,
    required this.imageCount,
    required this.videoCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.preview_outlined,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text('post_preview_title'.tr,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: context.profileText)),
            ]),
          ),
          Divider(height: 1, color: context.profileBorder),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                Stack(children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: context.profileCard.withValues(alpha: 0.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: coverSlot.file != null &&
                              !coverSlot.file!.path.startsWith('picked_')
                          ? Image.file(coverSlot.file!, fit: BoxFit.cover)
                          : coverSlot.isEmpty
                              ? Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.illus1,
                                        AppColors.catBlue,
                                      ],
                                    ),
                                  ),
                                  child: const Icon(Icons.image_outlined,
                                      color: AppColors.primary, size: 32),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.illus1.withValues(alpha: 0.8),
                                        AppColors.illus2.withValues(alpha: 0.6),
                                      ],
                                    ),
                                  ),
                                  child: const Icon(Icons.image,
                                      color: Colors.white, size: 36),
                                ),
                    ),
                  ),
                  if (imageCount > 0)
                    Positioned(
                      bottom: 5,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'post_preview_images'
                              .tr
                              .replaceAll('{count}', '$imageCount'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isFeatured)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.tagVip,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('VIP',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      Text(title,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: context.profileText),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(price,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.location_on_outlined,
                            size: 12,
                            color: context.profileText.withValues(alpha: 0.7)),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(address,
                              style: TextStyle(
                                  color: context.profileText
                                      .withValues(alpha: 0.7),
                                  fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(typeName,
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                      if (videoCount > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.play_circle_outline_rounded,
                                size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'post_preview_videos'
                                  .tr
                                  .replaceAll('{count}', '$videoCount'),
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentStep, totalSteps;
  final bool isSubmitting;
  final bool isEditing;
  final VoidCallback onNext, onPrev, onSubmit;

  const _BottomNav({
    required this.currentStep,
    required this.totalSteps,
    required this.isSubmitting,
    required this.isEditing,
    required this.onNext,
    required this.onPrev,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentStep == totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: context.profileCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: context.isDarkProfile ? 0.2 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Row(children: [
        if (currentStep > 0) ...[
          Expanded(
            flex: 1,
            child: OutlinedButton.icon(
              onPressed: onPrev,
              icon: const Icon(Icons.arrow_back_ios, size: 14),
              label: Text('post_btn_prev'.tr),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: isSubmitting ? null : (isLast ? onSubmit : onNext),
            style: ElevatedButton.styleFrom(
              backgroundColor: isLast ? AppColors.success : AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSubmitting) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('post_submitting'.tr,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ] else ...[
                  Text(
                      isLast
                          ? (isEditing ? 'Cập nhật tin' : 'post_btn_submit'.tr)
                          : 'post_btn_next'.tr,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(width: 6),
                  Icon(
                    isLast
                        ? Icons.check_circle_outline
                        : Icons.arrow_forward_ios,
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
