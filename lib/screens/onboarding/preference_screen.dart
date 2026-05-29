import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';

class PreferenceScreen extends StatefulWidget {
  final String? from;
  const PreferenceScreen({super.key, this.from});

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {
  final Set<String> _types = {'phong-tro'};
  final Set<String> _areas = {};
  final Set<String> _amenities = {};
  double _maxBudget = 4;
  bool _isLoading = true;

  bool get _isEdit => widget.from != null && widget.from!.trim().isNotEmpty;

  static const _typeOptions = [
    _ChoiceOption('phong-tro', 'Phòng trọ', Icons.home_rounded),
    _ChoiceOption('can-ho', 'Căn hộ dịch vụ', Icons.apartment_rounded),
    _ChoiceOption('o-ghep', 'Ở ghép', Icons.people_rounded),
    _ChoiceOption('nha-nguyen-can', 'Nhà nguyên căn', Icons.house_rounded),
  ];

  static const _areaOptions = [
    'Bình Thạnh',
    'Quận 1',
    'Quận 7',
    'Quận 10',
    'Tân Bình',
    'Thủ Đức',
    'Gò Vấp',
    'Bình Dương',
  ];

  static const _amenityOptions = [
    'Wifi',
    'Điều hòa',
    'Máy giặt',
    'Thang máy',
    'Bảo vệ',
    'Ban công',
    'Sân vườn',
    'Nuôi thú',
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTypes = prefs.getStringList(AppConstants.keyPreferenceTypes);
    final savedAreas = prefs.getStringList(AppConstants.keyPreferenceAreas);
    final savedAmenities = prefs.getStringList(AppConstants.keyPreferenceAmenities);
    final savedMaxBudget = prefs.getDouble(AppConstants.keyPreferenceMaxBudget);

    if (mounted) {
      setState(() {
        if (savedTypes != null && savedTypes.isNotEmpty) {
          _types.clear();
          _types.addAll(savedTypes);
        }
        if (savedAreas != null && savedAreas.isNotEmpty) {
          _areas.clear();
          _areas.addAll(savedAreas);
        }
        if (savedAmenities != null && savedAmenities.isNotEmpty) {
          _amenities.clear();
          _amenities.addAll(savedAmenities);
        }
        if (savedMaxBudget != null) {
          _maxBudget = savedMaxBudget / 1000000;
          if (_maxBudget < 1) _maxBudget = 1;
          if (_maxBudget > 15) _maxBudget = 15;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _finish({bool skipped = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!skipped) {
      await prefs.setStringList(
        AppConstants.keyPreferenceTypes,
        _types.toList(),
      );
      await prefs.setStringList(
        AppConstants.keyPreferenceAreas,
        _areas.toList(),
      );
      await prefs.setStringList(
        AppConstants.keyPreferenceAmenities,
        _amenities.toList(),
      );
      await prefs.setDouble(
        AppConstants.keyPreferenceMaxBudget,
        _maxBudget * 1000000,
      );
    }
    
    if (!_isEdit) {
      await prefs.setBool(AppConstants.keyOnboardingDone, true);
      if (mounted) context.go(AppConstants.routeHome);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'Đã cập nhật nhu cầu tìm phòng thành công!',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        context.pop();
      }
    }
  }

  void _toggle(Set<String> target, String value) {
    HapticFeedback.lightImpact();
    setState(() {
      if (target.contains(value)) {
        target.remove(value);
      } else {
        target.add(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgPage,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: _isEdit
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary,
                  size: 18,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.pop();
                },
              ),
              title: const Text(
                'Nhu cầu tìm phòng',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  color: AppColors.borderLight,
                  height: 1,
                ),
              ),
            )
          : null,
      body: SafeArea(
        top: !_isEdit,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isEdit) ...[
                      _buildHeader(),
                      const SizedBox(height: 24),
                    ],
                    _buildSectionTitle('Bạn muốn tìm loại trọ nào?'),
                    const SizedBox(height: 12),
                    _buildTypeGrid(),
                    const SizedBox(height: 28),
                    _buildSectionTitle('Ngân sách tối đa'),
                    const SizedBox(height: 12),
                    _buildBudgetSlider(),
                    const SizedBox(height: 28),
                    _buildSectionTitle('Khu vực ưu tiên'),
                    const SizedBox(height: 12),
                    _buildChips(_areaOptions, _areas),
                    const SizedBox(height: 28),
                    _buildSectionTitle('Tiện nghi bạn cần'),
                    const SizedBox(height: 12),
                    _buildChips(_amenityOptions, _amenities),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Nhu cầu tìm trọ của bạn',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Chọn vài thông tin cơ bản để Swings House gợi ý phòng phù hợp hơn.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTypeGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _typeOptions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (_, index) {
        final option = _typeOptions[index];
        final selected = _types.contains(option.key);
        return _ChoiceTile(
          label: option.label,
          icon: option.icon,
          selected: selected,
          onTap: () => _toggle(_types, option.key),
        );
      },
    );
  }

  Widget _buildBudgetSlider() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _maxBudget >= 15
                ? 'Từ 15 triệu/tháng trở xuống'
                : 'Tối đa ${_maxBudget.toStringAsFixed(_maxBudget % 1 == 0 ? 0 : 1)} triệu/tháng',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.primaryLight,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
              valueIndicatorColor: AppColors.primary,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: _maxBudget,
              min: 1,
              max: 15,
              divisions: 14,
              onChanged: (value) {
                if (value != _maxBudget) {
                  HapticFeedback.selectionClick();
                  setState(() => _maxBudget = value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChips(List<String> options, Set<String> selectedValues) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((value) {
        final selected = selectedValues.contains(value);
        return FilterChip(
          label: Text(value),
          selected: selected,
          onSelected: (_) => _toggle(selectedValues, value),
          selectedColor: AppColors.primaryLight,
          checkmarkColor: AppColors.primary,
          backgroundColor: Colors.white,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.borderLight,
            width: selected ? 1.5 : 1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          labelStyle: TextStyle(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              if (_isEdit) {
                context.pop();
              } else {
                _finish(skipped: true);
              }
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              _isEdit ? 'Hủy' : 'Bỏ qua',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _types.isEmpty ? null : () => _finish(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primaryLight,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                  ),
                ),
                child: Text(
                  _isEdit ? 'Lưu thay đổi' : 'Xem gợi ý phù hợp',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceOption {
  final String key;
  final String label;
  final IconData icon;

  const _ChoiceOption(this.key, this.label, this.icon);
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderLight,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
