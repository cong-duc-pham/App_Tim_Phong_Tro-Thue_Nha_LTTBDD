import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';



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

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────
class PostListingScreen extends StatefulWidget {
  const PostListingScreen({super.key});
  @override
  State<PostListingScreen> createState() => _PostListingScreenState();
}

class _PostListingScreenState extends State<PostListingScreen> {
  int _currentStep = 0;
  static const int _totalSteps = 5;

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

  final _roomTypes = const [
    RoomType(id: 1, name: 'Phòng trọ SV',   icon: Icons.bed_outlined),
    RoomType(id: 2, name: 'Căn hộ DV',       icon: Icons.apartment_outlined),
    RoomType(id: 3, name: 'Ở ghép',          icon: Icons.people_outline),
    RoomType(id: 4, name: 'Nhà nguyên căn',  icon: Icons.home_outlined),
  ];

  final _provinces = const ['TP. Hồ Chí Minh', 'Hà Nội', 'Đà Nẵng', 'Cần Thơ'];
  final _districts = const ['Quận 1','Quận 2','Quận 3','Bình Thạnh','Gò Vấp','Tân Bình'];
  final _wards     = const ['Phường 1','Phường 2','Phường 3','Phường Bến Nghé','Phường Đa Kao'];

  final _stepTitles = const [
    'Loại hình & Tiêu đề',
    'Ảnh phòng (6 ảnh)',
    'Địa chỉ',
    'Chi tiết phòng',
    'Giá & Tiện ích',
  ];

  @override
  void dispose() {
    for (final c in [
      _titleCtrl, _descCtrl, _priceCtrl, _areaCtrl, _floorCtrl,
      _totalFloorsCtrl, _maxOccupantsCtrl, _streetCtrl,
      _electricCtrl, _waterCtrl, _internetCtrl, _parkingCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _goTo(int s) => setState(() => _currentStep = s);
  void _next() { if (_currentStep < _totalSteps - 1) _goTo(_currentStep + 1); }
  void _prev() { if (_currentStep > 0) _goTo(_currentStep - 1); }

  /// Giả lập chọn ảnh - thực tế tích hợp image_picker ở đây
  void _pickImage(int idx) {
    setState(() {
      _slots[idx].file = File('picked_$idx');
    });
  }

  void _removeImage(int idx) => setState(() {
    _slots[idx].file       = null;
    _slots[idx].networkUrl = null;
  });

  void _swapSlots(int a, int b) => setState(() {
    final tf = _slots[a].file;
    final tu = _slots[a].networkUrl;
    _slots[a].file       = _slots[b].file;
    _slots[a].networkUrl = _slots[b].networkUrl;
    _slots[b].file       = tf;
    _slots[b].networkUrl = tu;
  });

  int get _filledCount => _slots.where((s) => !s.isEmpty).length;

  void _submit() {
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
  }

  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(children: [
        _Header(
          step: _currentStep,
          total: _totalSteps,
          title: _stepTitles[_currentStep],
          onBack: () {
            if (_currentStep > 0) {
              _prev();
            } else {
              Navigator.of(context).pop();
            }
          },
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
          onNext: _next,
          onPrev: _prev,
          onSubmit: _submit,
        ),
      ]),
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
                onTap: () => setState(() => _selectedType = t),
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
              onChanged: (v) => setState(() => _isFeatured = v),
              icon: Icons.workspace_premium_outlined,
              activeColor: AppColors.tagHot,
              title: 'Tin VIP / Nổi bật',
              subtitle: 'Hiển thị ưu tiên, tiếp cận nhiều người hơn',
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
            childAspectRatio: 1.35,
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
              }),
            ),
            const SizedBox(height: 14),
            _DropdownField(
              label: 'Phường / Xã',
              value: _selectedWard,
              items: _wards,
              enabled: _selectedDistrict != null,
              onChanged: (v) => setState(() => _selectedWard = v),
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
        _MapPlaceholder(),
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
              if (p != null) setState(() => _availableFrom = p);
            },
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Chính sách',
          icon: Icons.policy_outlined,
          child: _ToggleTile(
            value: _allowPet,
            onChanged: (v) => setState(() => _allowPet = v),
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
    final h        = isCoverLayout ? 210.0 : 115.0;

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
    return Column(children: [
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

class _MapPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        )],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.infoBg, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          CustomPaint(
            size: const Size(double.infinity, 150),
            painter: _GridPainter(),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )],
                  ),
                  child: const Icon(Icons.location_on,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(height: 8),
                const Text('Chạm để chọn vị trí trên bản đồ',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
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
  final VoidCallback onNext, onPrev, onSubmit;

  const _BottomNav({
    required this.currentStep,
    required this.totalSteps,
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
            onPressed: isLast ? onSubmit : onNext,
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
            ),
          ),
        ),
      ]),
    );
  }
}
