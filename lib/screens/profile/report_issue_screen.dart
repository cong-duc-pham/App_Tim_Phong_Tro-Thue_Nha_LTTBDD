import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/profile_theme.dart';
import '../../repositories/report_repository.dart';

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
        return 'report_type_account'.tr;
      case _IssueType.listing:
        return 'report_type_listing'.tr;
      case _IssueType.payment:
        return 'report_type_payment'.tr;
      case _IssueType.chat:
        return 'report_type_chat'.tr;
      case _IssueType.appError:
        return 'report_type_app'.tr;
      case _IssueType.other:
        return 'report_type_other'.tr;
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
  final _reportRepository = ReportRepository();
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  _IssueType _selectedType = _IssueType.appError;
  bool _includeDeviceInfo = true;
  bool _isSubmitting = false;

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
      backgroundColor: context.profileBg,
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
                  Text(
                    'profile_report_issue'.tr,
                    style: const TextStyle(
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
              decoration: BoxDecoration(
                color: context.profileBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
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
        color: context.profileCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: context.profileBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.support_agent_rounded,
              color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'report_intro'.tr,
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: context.profileTextSecondary,
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
        _SectionTitle('report_issue_type'.tr),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.profileCard,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(color: context.profileBorder),
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
                  color: selected ? Colors.white : context.profileText,
                ),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.4),
                side: BorderSide(
                  color: selected ? AppColors.primary : context.profileBorder,
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
        _SectionTitle('report_content'.tr),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.profileCard,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(color: context.profileBorder),
          ),
          child: Column(
            children: [
              _ReportTextField(
                controller: _titleCtrl,
                label: 'report_title_label'.tr,
                hint: 'report_title_hint'.tr,
                icon: Icons.title_rounded,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'report_title_required'.tr;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _ReportTextField(
                controller: _descriptionCtrl,
                label: 'report_desc_label'.tr,
                hint: 'report_desc_hint'.tr,
                icon: Icons.notes_rounded,
                minLines: 5,
                maxLines: 7,
                validator: (value) {
                  if (value == null || value.trim().length < 10) {
                    return 'report_desc_required'.tr;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _ReportTextField(
                controller: _contactCtrl,
                label: 'report_contact_label'.tr,
                hint: 'report_contact_hint'.tr,
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
        color: context.profileCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: context.profileBorder),
      ),
      child: SwitchListTile(
        value: _includeDeviceInfo,
        onChanged: (value) => setState(() => _includeDeviceInfo = value),
        activeThumbColor: AppColors.primary,
        title: Text(
          'report_device_title'.tr,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.profileText,
          ),
        ),
        subtitle: Text(
          'report_device_desc'.tr,
          style: AppTextStyles.bodySmall.copyWith(
            color: context.profileTextMuted,
          ),
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
        onPressed: _isSubmitting ? null : _submitReport,
        icon: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded, size: 18),
        label: Text('report_submit'.tr),
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

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await _reportRepository.createIssueReport(
        reason: _selectedType.label,
        description: _buildReportDescription(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
        ),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('report_success'.tr),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
      ),
    );

    context.pop();
  }

  String _buildReportDescription() {
    final lines = <String>[
      '${'report_title_label'.tr}: ${_titleCtrl.text.trim()}',
      '${'report_desc_label'.tr}: ${_descriptionCtrl.text.trim()}',
    ];

    final contact = _contactCtrl.text.trim();
    if (contact.isNotEmpty) {
      lines.add('${'report_contact_label'.tr}: $contact');
    }

    lines.add(
      '${'report_device_title'.tr}: ${_includeDeviceInfo ? 'yes'.tr : 'no'.tr}',
    );
    return lines.join('\n');
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: context.profileTextMuted,
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
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.profileTextSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(fontSize: 14, color: context.profileText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.inputHint.copyWith(
              color: context.profileTextMuted,
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: maxLines > 1 ? 72 : 0),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            filled: true,
            fillColor: context.profileInputFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide: BorderSide(color: context.profileBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide: BorderSide(color: context.profileBorder),
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
