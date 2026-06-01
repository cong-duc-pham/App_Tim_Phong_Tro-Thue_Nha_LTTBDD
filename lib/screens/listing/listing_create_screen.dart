import 'dart:io';
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../repositories/listing_repository.dart';
import '../../screens/payment/package_screen.dart';
import '../../services/post_listing_draft_service.dart';



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
  File?   file;
  String? networkUrl;
  ImageSlot({required this.slotIndex, this.file, this.networkUrl});
  bool get isEmpty => file == null && networkUrl == null;
  bool get isCover => slotIndex == 0;
}

const _mapTileUrlTemplate =
    'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────
class PostListingScreen extends StatefulWidget {
  const PostListingScreen({super.key});
  @override
  State<PostListingScreen> createState() => _PostListingScreenState();
}

class _PostListingScreenState extends State<PostListingScreen> {
  final ListingRepository _listingRepository = ListingRepository();
  final ImagePicker _imagePicker = ImagePicker();
  int _currentStep = 0;
  static const int _totalSteps = 5;
  bool _isSubmitting = false;
  int? _createdListingIdForVip;

  // 6 slot ảnh cố định (slot_index 0-5)
  final List<ImageSlot> _slots =
  List.generate(6, (i) => ImageSlot(slotIndex: i));

  // Form controllers
  RoomType? _selectedType;
  final _titleCtrl        = TextEditingController();
  final _descCtrl         = TextEditingController();
  final _priceCtrl        = TextEditingController();
  final _areaCtrl         = TextEditingController();
  final _floorCtrl        = TextEditingController();
  final _totalFloorsCtrl  = TextEditingController();
  final _maxOccupantsCtrl = TextEditingController(text: '1');
  final _streetCtrl       = TextEditingController();
  final _electricCtrl     = TextEditingController();
  final _waterCtrl        = TextEditingController();
  final _internetCtrl     = TextEditingController();
  final _parkingCtrl      = TextEditingController();

  bool      _allowPet   = false;
  bool      _isFeatured = false;
  DateTime? _availableFrom;

  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedWard;
  double? _selectedLatitude;
  double? _selectedLongitude;
  bool _isResolvingAddress = false;

  final _roomTypes = const [
    RoomType(id: 1, name: 'Phòng trọ SV',   icon: Icons.bed_outlined),
    RoomType(id: 2, name: 'Căn hộ DV',       icon: Icons.apartment_outlined),
    RoomType(id: 3, name: 'Ở ghép',          icon: Icons.people_outline),
    RoomType(id: 4, name: 'Nhà nguyên căn',  icon: Icons.home_outlined),
  ];

  final _provinces = ['TP. Hồ Chí Minh', 'Hà Nội', 'Đà Nẵng', 'Cần Thơ'];
  final _districts = ['Quận 1','Quận 2','Quận 3','Bình Thạnh','Gò Vấp','Tân Bình'];
  final _wards     = ['Phường 1','Phường 2','Phường 3','Phường Bến Nghé','Phường Đa Kao'];

  final _stepTitles = const [
    'Loại hình & Tiêu đề',
    'Ảnh phòng (6 ảnh)',
    'Địa chỉ',
    'Chi tiết phòng',
    'Giá & Tiện ích',
  ];

  @override
  void initState() {
    super.initState();
    for (final c in [
      _titleCtrl, _descCtrl, _priceCtrl, _areaCtrl, _floorCtrl,
      _totalFloorsCtrl, _maxOccupantsCtrl, _streetCtrl,
      _electricCtrl, _waterCtrl, _internetCtrl, _parkingCtrl,
    ]) {
      c.addListener(_markDraftChanged);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl, _descCtrl, _priceCtrl, _areaCtrl, _floorCtrl,
      _totalFloorsCtrl, _maxOccupantsCtrl, _streetCtrl,
      _electricCtrl, _waterCtrl, _internetCtrl, _parkingCtrl,
    ]) {
      c.dispose();
    }
    PostListingDraftService.clear();
    super.dispose();
  }

  void _goTo(int s) => setState(() => _currentStep = s);
  void _next() {
    if (!_validateStepAndNotify(_currentStep)) return;
    if (_currentStep < _totalSteps - 1) _goTo(_currentStep + 1);
  }
  void _prev() { if (_currentStep > 0) _goTo(_currentStep - 1); }

  void _markDraftChanged() => PostListingDraftService.markDirty();

  Future<void> _pickImage(int idx) async {
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
    _slots[idx].file       = null;
    _slots[idx].networkUrl = null;
    _markDraftChanged();
  });

  void _swapSlots(int a, int b) => setState(() {
    final tf = _slots[a].file;
    final tu = _slots[a].networkUrl;
    _slots[a].file       = _slots[b].file;
    _slots[a].networkUrl = _slots[b].networkUrl;
    _slots[b].file       = tf;
    _slots[b].networkUrl = tu;
    _markDraftChanged();
  });

  int get _filledCount => _slots.where((s) => !s.isEmpty).length;

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
      final created = await _listingRepository.createListing(
        _buildCreatePayload(),
      );
      final imageUploadMessage = await _tryUploadImages(created.listingId);
      if (!mounted) return;

      PostListingDraftService.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 12),
          Text('Đăng tin thành công! Đang chờ xét duyệt.'),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      if (imageUploadMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(imageUploadMessage),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      if (_isFeatured) {
        setState(() => _createdListingIdForVip = created.listingId);
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
      return 'Tin đã được tạo, nhưng upload ảnh quá lâu. Bạn vẫn có thể mua gói VIP.';
    } catch (_) {
      return 'Tin đã được tạo, nhưng chưa cập nhật được ảnh. Bạn vẫn có thể mua gói VIP.';
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
        if (_selectedType == null) return 'Vui lòng chọn loại hình phòng.';
        if (_titleCtrl.text.trim().isEmpty) {
          return 'Vui lòng nhập tiêu đề tin đăng.';
        }
        return null;
      case 1:
        if (_slots[0].file == null && _slots[0].networkUrl == null) {
          return 'Vui lòng thêm ảnh bìa để admin có thể duyệt tin.';
        }
        return null;
      case 2:
        if (_selectedProvince == null) return 'Vui lòng chọn tỉnh / thành phố.';
        if (_selectedDistrict == null) return 'Vui lòng chọn quận / huyện.';
        if (_selectedWard == null) return 'Vui lòng chọn phường / xã.';
        if (_streetCtrl.text.trim().isEmpty) {
          return 'Vui lòng nhập địa chỉ chi tiết.';
        }
        return null;
      case 3:
        final area = _parseDecimal(_areaCtrl.text);
        if (area == null || area <= 0) return 'Vui lòng nhập diện tích hợp lệ.';
        final maxOccupants = _parseInt(_maxOccupantsCtrl.text);
        if (maxOccupants == null || maxOccupants <= 0) {
          return 'Vui lòng nhập số người tối đa hợp lệ.';
        }
        return null;
      case 4:
        final price = _parseDecimal(_priceCtrl.text);
        if (price == null || price <= 0) return 'Vui lòng nhập giá thuê hợp lệ.';
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
    if (!PostListingDraftService.hasDraft.value) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ thông tin đang nhập?'),
        content: const Text(
          'Bạn đang nhập dở tin đăng. Nếu rời khỏi trang này, thông tin chưa đăng sẽ bị mất.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rời trang'),
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
    if (await _confirmDiscardDraft() && mounted) {
      Navigator.of(context).pop();
    }
  }

  Map<String, dynamic> _buildCreatePayload() {
    return {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
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
      'availableFrom': _availableFrom == null
          ? null
          : _availableFrom!.toIso8601String().split('T').first,
      'amenityIds': <int>[],
      'image0': _slots[0].networkUrl,
      'image1': _slots[1].networkUrl,
      'image2': _slots[2].networkUrl,
      'image3': _slots[3].networkUrl,
      'image4': _slots[4].networkUrl,
      'image5': _slots[5].networkUrl,
    };
  }

  Future<List<String>> _uploadSelectedImages(int listingId) async {
    final urls = <String>[];

    for (final slot in _slots) {
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
      if (_selectedDistrict?.trim().isNotEmpty == true) _selectedDistrict!.trim(),
      if (_selectedProvince?.trim().isNotEmpty == true) _selectedProvince!.trim(),
    ].where((part) => part.isNotEmpty).join(', ');
  }

  Future<void> _openLocationPicker() async {
    final initialPoint = _selectedLatitude != null && _selectedLongitude != null
        ? LatLng(_selectedLatitude!, _selectedLongitude!)
        : LatLng(AppConstants.defaultLat, AppConstants.defaultLng);

    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _LocationPickerScreen(initialPoint: initialPoint),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      _selectedLatitude = picked.latitude;
      _selectedLongitude = picked.longitude;
      _markDraftChanged();
    });
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
        address['city'],
        address['state'],
        address['province'],
      ]));
      final district = _firstNonEmpty([
        address['city_district'],
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
        const SnackBar(
          content: Text('Đã chọn tọa độ, nhưng chưa tự nhận diện được địa chỉ.'),
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
    const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
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
      return PackageScreen(listingId: vipListingId);
    }

    return WillPopScope(
      onWillPop: () async {
        if (_currentStep > 0) {
          _prev();
          return false;
        }
        return _confirmDiscardDraft();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgPage,
        body: Column(children: [
          _Header(
            step: _currentStep,
            total: _totalSteps,
            title: _stepTitles[_currentStep],
            onBack: _handleBack,
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
          title: 'Loại hình phòng',
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
                    color: sel ? AppColors.primary : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? AppColors.primary : AppColors.border,
                      width: sel ? 2 : 1,
                    ),
                    boxShadow: sel
                        ? [BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3))]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(t.icon,
                          color: sel ? Colors.white : AppColors.primary,
                          size: 20),
                      const SizedBox(width: 8),
                      Text(t.name,
                          style: TextStyle(
                            color: sel ? Colors.white : AppColors.textPrimary,
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
          title: 'Thông tin cơ bản',
          icon: Icons.edit_outlined,
          child: Column(children: [
            _InputField(
              ctrl: _titleCtrl,
              label: 'Tiêu đề tin đăng',
              hint: 'VD: Phòng trọ full nội thất Bình Thạnh giá rẻ',
              maxLength: 200,
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            _InputField(
              ctrl: _descCtrl,
              label: 'Mô tả chi tiết',
              hint: 'Mô tả đặc điểm nổi bật, tiện ích xung quanh...',
              maxLines: 4,
              maxLength: 2000,
            ),
            const SizedBox(height: 14),
            _ToggleTile(
              value: _isFeatured,
              onChanged: (v) => setState(() {
                _isFeatured = v;
                _markDraftChanged();
              }),
              icon: Icons.workspace_premium_outlined,
              activeColor: AppColors.tagHot,
              title: 'Nâng cấp VIP sau khi đăng',
              subtitle: 'Chọn VIP Tuần, VIP Tháng hoặc Nổi bật 30 ngày',
            ),
          ]),
        ),
      ],
    );
  }

  // ── Step 2: ẢNH PHÒNG ────────────────────────
  Widget _buildStepImages() {
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ảnh phòng - tối đa 6 ảnh',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text(
                      '- Ảnh đầu tiên (Slot 1) là ẢNH BÌA hiển thị trên danh sách\n'
                          '- Định dạng JPG/PNG, tối đa 5 MB mỗi ảnh\n'
                          '- Nhấn giữ để đặt ảnh phụ thành ảnh bìa',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
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
            const Text('Danh sách ảnh',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimary)),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _filledCount > 0
                    ? AppColors.primaryLight.withValues(alpha: 0.6)
                    : AppColors.border.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_filledCount / 6 ảnh',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _filledCount > 0
                      ? AppColors.primary
                      : AppColors.textSecondary,
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

        // Slot 1-5: Ảnh phụ (grid 2 cột)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.2,
          ),
          itemCount: 5,
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

        // Tip
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.successBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
          ),
          child: const Row(children: [
            Icon(Icons.lightbulb_outline, color: AppColors.success, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Mẹo: Ảnh sáng, rõ nét, chụp từ nhiều góc giúp tăng 3x lượt liên hệ!',
                style: TextStyle(
                    fontSize: 12, color: AppColors.successText, height: 1.4),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  // ── Step 3: Địa chỉ ──────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'Địa chỉ phòng',
          icon: Icons.location_on_outlined,
          child: Column(children: [
            _DropdownField(
              label: 'Tỉnh / Thành phố',
              value: _selectedProvince,
              items: _provinces,
              onChanged: (v) => setState(() {
                _selectedProvince = v;
                _selectedDistrict = null;
                _selectedWard     = null;
                _markDraftChanged();
              }),
            ),
            const SizedBox(height: 14),
            _DropdownField(
              label: 'Quận / Huyện',
              value: _selectedDistrict,
              items: _districts,
              enabled: _selectedProvince != null,
              onChanged: (v) => setState(() {
                _selectedDistrict = v;
                _selectedWard     = null;
                _markDraftChanged();
              }),
            ),
            const SizedBox(height: 14),
            _DropdownField(
              label: 'Phường / Xã',
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
              label: 'Địa chỉ chi tiết',
              hint: 'Số nhà, tên đường...',
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
          title: 'Diện tích & Tầng',
          icon: Icons.straighten_outlined,
          child: Column(children: [
            Row(children: [
              Expanded(child: _InputField(
                  ctrl: _areaCtrl, label: 'Diện tích (m2)',
                  hint: '25', keyboardType: TextInputType.number, suffixText: 'm2')),
              const SizedBox(width: 12),
              Expanded(child: _InputField(
                  ctrl: _maxOccupantsCtrl, label: 'Số người tối đa',
                  hint: '1', keyboardType: TextInputType.number, suffixText: 'người')),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _InputField(
                  ctrl: _floorCtrl, label: 'Tầng',
                  hint: '3', keyboardType: TextInputType.number, suffixText: 'tầng')),
              const SizedBox(width: 12),
              Expanded(child: _InputField(
                  ctrl: _totalFloorsCtrl, label: 'Tổng số tầng',
                  hint: '5', keyboardType: TextInputType.number, suffixText: 'tầng')),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Ngày có thể vào ở',
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
                  data: ThemeData.light().copyWith(
                      colorScheme: const ColorScheme.light(
                          primary: AppColors.primary)),
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
          title: 'Chính sách',
          icon: Icons.policy_outlined,
          child: _ToggleTile(
            value: _allowPet,
            onChanged: (v) => setState(() {
              _allowPet = v;
              _markDraftChanged();
            }),
            icon: Icons.pets_outlined,
            activeColor: AppColors.success,
            title: 'Cho phép nuôi thú cưng',
            subtitle: 'Chó, mèo, thú nhỏ...',
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
          title: 'Giá thuê',
          icon: Icons.payments_outlined,
          child: _InputField(
            ctrl: _priceCtrl,
            label: 'Giá thuê mỗi tháng (VND)',
            hint: '3500000',
            keyboardType: TextInputType.number,
            suffixText: 'đ/tháng',
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            isLarge: true,
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Chi phí dịch vụ',
          icon: Icons.receipt_long_outlined,
          child: Column(children: [
            Row(children: [
              Expanded(child: _InputField(
                  ctrl: _electricCtrl, label: 'Điện (đ/kWh)',
                  hint: '3500', keyboardType: TextInputType.number,
                  prefixIcon: Icons.bolt_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _InputField(
                  ctrl: _waterCtrl, label: 'Nước (đ/m3)',
                  hint: '15000', keyboardType: TextInputType.number,
                  prefixIcon: Icons.water_drop_outlined)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _InputField(
                  ctrl: _internetCtrl, label: 'Internet (đ/tháng)',
                  hint: '100000', keyboardType: TextInputType.number,
                  prefixIcon: Icons.wifi_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _InputField(
                  ctrl: _parkingCtrl, label: 'Gửi xe (đ/tháng)',
                  hint: '100000', keyboardType: TextInputType.number,
                  prefixIcon: Icons.directions_car_outlined)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        _PreviewCard(
          coverSlot: _slots[0],
          title: _titleCtrl.text.isEmpty
              ? 'Tiêu đề chưa nhập'
              : _titleCtrl.text,
          typeName: _selectedType?.name ?? 'Chưa chọn loại hình',
          price: _priceCtrl.text.isEmpty
              ? '---'
              : '${_priceCtrl.text} đ/tháng',
          address: _streetCtrl.text.isEmpty
              ? 'Chưa nhập địa chỉ'
              : _streetCtrl.text,
          isFeatured: _isFeatured,
          imageCount: _filledCount,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// ImageSlotCard
// ─────────────────────────────────────────────
class _ImageSlotCard extends StatelessWidget {
  final ImageSlot    slot;
  final bool         isCoverLayout;
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
    final h        = isCoverLayout ? 220.0 : 130.0;

    return GestureDetector(
      onTap: hasImage ? null : onPick,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: hasImage ? Colors.black : AppColors.bgPage,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasImage
                ? Colors.transparent
                : isCoverLayout
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.border,
            width: (isCoverLayout && !hasImage) ? 2 : 1,
          ),
          boxShadow: hasImage
              ? [BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4))]
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
                  bottom: 0, left: 0, right: 0,
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
                    top: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.tagHot,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                          color: AppColors.tagHot.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )],
                      ),
                      child: const Row(children: [
                        Icon(Icons.star_rounded, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text('Ảnh bìa', style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),

                // Số slot
                Positioned(
                  bottom: 8, left: 10,
                  child: Text(
                    isCoverLayout
                        ? 'Slot 1 (Bìa)'
                        : 'Slot ${slot.slotIndex + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),

                // Action buttons
                Positioned(
                  top: 8, right: 8,
                  child: Row(children: [
                    if (!isCoverLayout && onMakeCover != null) ...[
                      _ActionBtn(
                        icon: Icons.star_border_rounded,
                        color: AppColors.tagHot,
                        tooltip: 'Đặt làm ảnh bìa',
                        onTap: onMakeCover!,
                      ),
                      const SizedBox(width: 5),
                    ],
                    _ActionBtn(
                      icon: Icons.edit_outlined,
                      color: AppColors.primary,
                      tooltip: 'Thay ảnh',
                      onTap: onPick,
                    ),
                    const SizedBox(width: 5),
                    _ActionBtn(
                      icon: Icons.delete_outline,
                      color: AppColors.error,
                      tooltip: 'Xoá',
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
  final int  slotIndex;
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
                : AppColors.border.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCover
                ? Icons.add_photo_alternate_outlined
                : Icons.add_a_photo_outlined,
            color: isCover ? AppColors.primary : AppColors.textMuted,
            size: isCover ? 26 : 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isCover ? 'Thêm ảnh bìa' : 'Ảnh ${slotIndex + 1}',
          style: TextStyle(
            color: isCover ? AppColors.primary : AppColors.textMuted,
            fontSize: isCover ? 13 : 11,
            fontWeight: isCover ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        if (isCover) ...[
          const SizedBox(height: 3),
          const Text(
            'Nhấn để chọn từ thư viện',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       tooltip;
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
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 1),
            )],
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
  const _Header({required this.step, required this.total, required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryMedium],
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
                width: 38, height: 38,
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
                  const Text('Đăng tin cho thuê',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  Text('Bước ${step + 1}/$total - $title',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.help_outline, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('Trợ giúp',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  final int current, total;
  static const _labels = ['Loại hình', 'Ảnh', 'Địa chỉ', 'Chi tiết', 'Giá cả'];
  const _StepBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryMedium],
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
              label: _labels[i],
            ),
          ),
        ),
      ]),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int    index;
  final bool   isActive, isDone;
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
        width:  isActive ? 28 : 22,
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
  final String  title;
  final IconData icon;
  final Widget  child;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary)),
            ]),
          ),
          Divider(height: 1, color: AppColors.border),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController ctrl;
  final String  label, hint;
  final int?    maxLength;
  final int     maxLines;
  final TextInputType? keyboardType;
  final String?  suffixText;
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
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
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
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            hintStyle: const TextStyle(
                color: AppColors.textMuted, fontSize: 13),
            suffixText: suffixText,
            suffixStyle: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppColors.primary, size: 18)
                : null,
            filled: true,
            fillColor: AppColors.bgPage,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
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
  final String   label;
  final String?  value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool     enabled;

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
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: enabled ? onChanged : null,
          hint: Text('Chọn $label',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13)),
          items: items
              .map((e) => DropdownMenuItem(
            value: e,
            child: Text(e,
                style: const TextStyle(fontSize: 14)),
          ))
              .toList(),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.primary),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled
                ? AppColors.bgPage
                : AppColors.border.withValues(alpha: 0.5),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
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
  final bool   value;
  final ValueChanged<bool> onChanged;
  final IconData icon;
  final Color  activeColor;
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
          color: value ? activeColor.withValues(alpha: 0.08) : AppColors.bgPage,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? activeColor : AppColors.border,
            width: value ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: value
                  ? activeColor.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                color: value ? activeColor : AppColors.textSecondary,
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
                        color: value ? activeColor : AppColors.textPrimary,
                        fontSize: 13)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
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
  final DateTime?    date;
  final VoidCallback onTap;
  const _DatePickerTile({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgPage,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: date != null ? AppColors.primary : AppColors.border,
            width: date != null ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(Icons.event_available_outlined,
              color: date != null ? AppColors.primary : AppColors.textMuted,
              size: 20),
          const SizedBox(width: 10),
          Text(
            date != null
                ? 'Ngày ${date!.day.toString().padLeft(2, '0')}/'
                '${date!.month.toString().padLeft(2, '0')}/'
                '${date!.year}'
                : 'Chọn ngày có thể vào ở',
            style: TextStyle(
              color: date != null
                  ? AppColors.textPrimary
                  : AppColors.textMuted,
              fontWeight: date != null
                  ? FontWeight.w600
                  : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: date != null
                  ? AppColors.primary
                  : AppColors.textMuted),
        ]),
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
        : LatLng(AppConstants.defaultLat, AppConstants.defaultLng);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 170,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
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
                  color: Colors.black.withValues(alpha: _hasLocation ? 0 : 0.08),
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
                    color: Colors.white.withValues(alpha: 0.94),
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
                              ? 'Đang tự điền địa chỉ...'
                              : _hasLocation
                                  ? '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}'
                                  : 'Chạm để chọn vị trí trên bản đồ',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
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
  late LatLng _selectedPoint;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedPoint = widget.initialPoint;
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Vui lòng bật dịch vụ vị trí trên thiết bị.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Ứng dụng chưa được cấp quyền vị trí.');
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
      _showMessage('Không lấy được vị trí hiện tại.');
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
              child: Row(
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Chạm vào bản đồ để đặt vị trí',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
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
          ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vị trí đã chọn',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_selectedPoint.latitude.toStringAsFixed(6)}, ${_selectedPoint.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
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
                      label: const Text('Dùng vị trí này'),
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
  final String    title, typeName, price, address;
  final bool      isFeatured;
  final int       imageCount;

  const _PreviewCard({
    required this.coverSlot,
    required this.title,
    required this.typeName,
    required this.price,
    required this.address,
    required this.isFeatured,
    required this.imageCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.07),
          blurRadius: 12,
          offset: const Offset(0, 3),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.preview_outlined,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Xem trước tin đăng',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
          ),
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                Stack(children: [
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.bgPage,
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
                      bottom: 5, right: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('$imageCount ảnh',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600)),
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
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary),
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
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(address,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
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
  final int          currentStep, totalSteps;
  final bool isSubmitting;
  final VoidCallback onNext, onPrev, onSubmit;

  const _BottomNav({
    required this.currentStep,
    required this.totalSteps,
    required this.isSubmitting,
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
        color: AppColors.bgCard,
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, -4),
        )],
      ),
      child: Row(children: [
        if (currentStep > 0) ...[
          Expanded(
            flex: 1,
            child: OutlinedButton.icon(
              onPressed: onPrev,
              icon: const Icon(Icons.arrow_back_ios, size: 14),
              label: const Text('Quay lại'),
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
              backgroundColor:
              isLast ? AppColors.success : AppColors.primary,
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
                  const Text('Đang đăng tin...',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ] else ...[
                  Text(isLast ? 'Đăng tin ngay' : 'Tiếp theo',
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
