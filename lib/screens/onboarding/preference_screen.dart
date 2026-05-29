import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';

class PreferenceScreen extends StatefulWidget {
  const PreferenceScreen({super.key});

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {
  final Set<String> _types = {'phong-tro'};
  final Set<String> _areas = {};
  final Set<String> _amenities = {};
  double _maxBudget = 4;

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
    await prefs.setBool(AppConstants.keyOnboardingDone, true);

    if (mounted) context.go(AppConstants.routeHome);
  }

  void _toggle(Set<String> target, String value) {
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
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Bạn muốn tìm loại trọ nào?'),
                    const SizedBox(height: 10),
                    _buildTypeGrid(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Ngân sách tối đa'),
                    const SizedBox(height: 8),
                    _buildBudgetSlider(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Khu vực ưu tiên'),
                    const SizedBox(height: 10),
                    _buildChips(_areaOptions, _areas),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Tiện nghi bạn cần'),
                    const SizedBox(height: 10),
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
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.25,
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.borderLight),
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
          Slider(
            value: _maxBudget,
            min: 1,
            max: 15,
            divisions: 14,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.primaryLight,
            onChanged: (value) => setState(() => _maxBudget = value),
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
          ),
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
            onPressed: () => _finish(skipped: true),
            child: const Text(
              'Bỏ qua',
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 50,
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
                child: const Text(
                  'Xem gợi ý phù hợp',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
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
