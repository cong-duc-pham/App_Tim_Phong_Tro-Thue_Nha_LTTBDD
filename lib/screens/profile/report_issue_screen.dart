import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';

enum _IssueType {
  account,
  listing,
  payment,
  chat,
  appError,
  other,
}

extension _IssueTypeLabel on _IssueType {
  String get label {
    switch (this) {
      case _IssueType.account:
        return 'Tài khoản';
      case _IssueType.listing:
        return 'Tin đăng/phòng trọ';
      case _IssueType.payment:
        return 'Thanh toán';
      case _IssueType.chat:
        return 'Nhắn tin/liên hệ';
      case _IssueType.appError:
        return 'Lỗi ứng dụng';
      case _IssueType.other:
        return 'Khác';
    }
  }

  IconData get icon {
    switch (this) {
      case _IssueType.account:
        return Icons.person_outline_rounded;
      case _IssueType.listing:
        return Icons.home_work_outlined;
      case _IssueType.payment:
        return Icons.receipt_long_outlined;
      case _IssueType.chat:
        return Icons.chat_bubble_outline_rounded;
      case _IssueType.appError:
        return Icons.bug_report_outlined;
      case _IssueType.other:
        return Icons.more_horiz_rounded;
    }
  }
}

class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  _IssueType _selectedType = _IssueType.appError;
  bool _includeDeviceInfo = true;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                children: [
                  _buildIntro(),
                  const SizedBox(height: 14),
                  _buildTypePicker(),
                  const SizedBox(height: 14),
                  _buildInputCard(),
                  const SizedBox(height: 14),
                  _buildDeviceOption(),
                  const SizedBox(height: 20),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Báo cáo sự cố',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Container(
              height: 20,
              decoration: const BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Hãy mô tả rõ vấn đề bạn gặp phải. SWING HOUSE sẽ dùng thông tin này để kiểm tra và hỗ trợ nhanh hơn.',
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Loại sự cố'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _IssueType.values.map((type) {
              final selected = type == _selectedType;
              return ChoiceChip(
                selected: selected,
                showCheckmark: false,
                avatar: Icon(
                  type.icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.primary,
                ),
                label: Text(type.label),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textPrimary,
                ),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.4),
                side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.borderLight,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                ),
                onSelected: (_) => setState(() => _selectedType = type),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Nội dung báo cáo'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              _ReportTextField(
                controller: _titleCtrl,
                label: 'Tiêu đề',
                hint: 'Ví dụ: Không đăng nhập được',
                icon: Icons.title_rounded,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tiêu đề sự cố';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _ReportTextField(
                controller: _descriptionCtrl,
                label: 'Mô tả chi tiết',
                hint: 'Bạn đang thao tác ở đâu, lỗi hiện ra như thế nào?',
                icon: Icons.notes_rounded,
                minLines: 5,
                maxLines: 7,
                validator: (value) {
                  if (value == null || value.trim().length < 10) {
                    return 'Vui lòng mô tả ít nhất 10 ký tự';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _ReportTextField(
                controller: _contactCtrl,
                label: 'Email hoặc số điện thoại',
                hint: 'Để đội hỗ trợ liên hệ lại nếu cần',
                icon: Icons.contact_mail_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceOption() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: SwitchListTile(
        value: _includeDeviceInfo,
        onChanged: (value) => setState(() => _includeDeviceInfo = value),
        activeColor: AppColors.primary,
        title: const Text(
          'Gửi kèm thông tin thiết bị',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: const Text(
          'Giúp xác định lỗi theo phiên bản app và thiết bị đang dùng.',
          style: AppTextStyles.bodySmall,
        ),
        secondary: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.infoBg,
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.phone_android_rounded,
            size: 18,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _submitReport,
        icon: const Icon(Icons.send_rounded, size: 18),
        label: const Text('Gửi báo cáo'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
        ),
      ),
    );
  }

  void _submitReport() {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đã ghi nhận báo cáo sự cố của bạn'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
      ),
    );

    context.pop();
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ReportTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _ReportTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.inputHint,
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: maxLines > 1 ? 72 : 0),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            filled: true,
            fillColor: AppColors.bgPage,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }
}
