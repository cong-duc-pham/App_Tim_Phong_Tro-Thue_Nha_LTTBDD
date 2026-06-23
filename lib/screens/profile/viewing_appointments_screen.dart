import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/profile_theme.dart';
import '../../models/viewing_appointment.dart';
import '../../repositories/viewing_appointment_repository.dart';

class ViewingAppointmentsScreen extends StatefulWidget {
  const ViewingAppointmentsScreen({super.key});

  @override
  State<ViewingAppointmentsScreen> createState() =>
      _ViewingAppointmentsScreenState();
}

class _ViewingAppointmentsScreenState extends State<ViewingAppointmentsScreen> {
  final ViewingAppointmentRepository _repository =
      ViewingAppointmentRepository();
  final List<ViewingAppointment> _appointments = [];
  final Set<int> _updatingAppointmentIds = {};
  bool _isLoading = true;
  String? _error;
  String _roleFilter = '';

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await _repository.getMyAppointments(
        role: _roleFilter.isEmpty ? null : _roleFilter,
      );
      if (!mounted) return;
      setState(() {
        _appointments
          ..clear()
          ..addAll(items);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(
    ViewingAppointment appointment,
    String action,
  ) async {
    if (_updatingAppointmentIds.contains(appointment.appointmentId)) return;

    final note = await _showNoteSheet(action);
    if (!mounted || note == null) return;

    setState(() => _updatingAppointmentIds.add(appointment.appointmentId));

    try {
      late final ViewingAppointment updated;
      if (action == 'confirm') {
        updated =
            await _repository.confirm(appointment.appointmentId, note: note);
      } else if (action == 'decline') {
        updated =
            await _repository.decline(appointment.appointmentId, note: note);
      } else {
        updated =
            await _repository.cancel(appointment.appointmentId, note: note);
      }

      if (!mounted) return;
      setState(() {
        _updatingAppointmentIds.remove(appointment.appointmentId);
        final index = _appointments.indexWhere(
          (item) => item.appointmentId == appointment.appointmentId,
        );
        if (index != -1) {
          _appointments[index] = updated;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_successMessage(action)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _updatingAppointmentIds.remove(appointment.appointmentId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanError(e)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(
            () => _updatingAppointmentIds.remove(appointment.appointmentId));
      }
    }
  }

  Future<String?> _showNoteSheet(String action) async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: context.profileCard,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppConstants.radiusXxl),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.profileBorder,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusFull),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _sheetTitle(action),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.profileText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Ghi chú thêm cho người còn lại',
                      filled: true,
                      fillColor: context.profileInputFill,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMd),
                        borderSide: BorderSide(color: context.profileBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Đóng'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(context, controller.text.trim()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                action == 'decline' || action == 'cancel'
                                    ? AppColors.error
                                    : AppColors.primary,
                          ),
                          child: Text(_sheetAction(action)),
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
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.profileBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Lịch xem phòng'),
        actions: [
          IconButton(
            onPressed: _loadAppointments,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAppointments,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final options = [
      ('', 'Tất cả'),
      ('tenant', 'Tôi đặt'),
      ('landlord', 'Khách đặt'),
    ];

    return Container(
      color: context.profileCard,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: options.map((option) {
          final selected = _roleFilter == option.$1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                selected: selected,
                showCheckmark: false,
                label: Center(child: Text(option.$2)),
                onSelected: (_) {
                  setState(() => _roleFilter = option.$1);
                  _loadAppointments();
                },
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : context.profileText,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.event_busy_rounded,
              size: 48, color: context.profileTextMuted),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.profileTextSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadAppointments,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ],
      );
    }

    if (_appointments.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.calendar_month_outlined,
              size: 52, color: context.profileTextMuted),
          const SizedBox(height: 12),
          Text(
            'Chưa có lịch xem phòng nào.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.profileText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lịch hẹn bạn tạo hoặc khách đặt với tin của bạn sẽ xuất hiện ở đây.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.profileTextSecondary),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _appointments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _AppointmentCard(
        appointment: _appointments[index],
        isUpdating: _updatingAppointmentIds
            .contains(_appointments[index].appointmentId),
        onConfirm: () => _updateStatus(_appointments[index], 'confirm'),
        onDecline: () => _updateStatus(_appointments[index], 'decline'),
        onCancel: () => _updateStatus(_appointments[index], 'cancel'),
      ),
    );
  }

  String _sheetTitle(String action) {
    switch (action) {
      case 'confirm':
        return 'Xác nhận lịch xem phòng';
      case 'decline':
        return 'Từ chối lịch hẹn';
      default:
        return 'Hủy lịch xem phòng';
    }
  }

  String _sheetAction(String action) {
    switch (action) {
      case 'confirm':
        return 'Xác nhận';
      case 'decline':
        return 'Từ chối';
      default:
        return 'Hủy lịch';
    }
  }

  String _successMessage(String action) {
    switch (action) {
      case 'confirm':
        return 'Đã xác nhận lịch hẹn.';
      case 'decline':
        return 'Đã từ chối lịch hẹn.';
      default:
        return 'Đã hủy lịch hẹn.';
    }
  }

  String _cleanError(Object e) {
    final value = e.toString();
    return value.startsWith('Exception: ')
        ? value.substring('Exception: '.length)
        : value;
  }
}

class _AppointmentCard extends StatelessWidget {
  final ViewingAppointment appointment;
  final bool isUpdating;
  final VoidCallback onConfirm;
  final VoidCallback onDecline;
  final VoidCallback onCancel;

  const _AppointmentCard({
    required this.appointment,
    required this.isUpdating,
    required this.onConfirm,
    required this.onDecline,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: context.profileBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.profileSubtleCard,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                clipBehavior: Clip.antiAlias,
                child: appointment.listingImage == null ||
                        appointment.listingImage!.isEmpty
                    ? const Icon(Icons.home_work_outlined,
                        color: AppColors.primary)
                    : Image.network(
                        appointment.listingImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.home_work_outlined,
                          color: AppColors.primary,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.listingTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.profileText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(appointment.scheduledAt),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: appointment.status),
            ],
          ),
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.person_outline_rounded,
            text:
                'Người thuê: ${appointment.tenantName}${_phone(appointment.tenantPhone)}',
          ),
          const SizedBox(height: 6),
          _InfoLine(
            icon: Icons.home_repair_service_outlined,
            text:
                'Chủ trọ: ${appointment.landlordName}${_phone(appointment.landlordPhone)}',
          ),
          if (appointment.tenantNote?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _InfoLine(
              icon: Icons.notes_rounded,
              text: 'Ghi chú khách: ${appointment.tenantNote}',
            ),
          ],
          if (appointment.landlordNote?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _InfoLine(
              icon: Icons.rate_review_outlined,
              text: 'Phản hồi chủ trọ: ${appointment.landlordNote}',
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/listing/${appointment.listingId}'),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Xem tin'),
              ),
              const Spacer(),
              if (appointment.canDecline)
                TextButton(
                  onPressed: isUpdating ? null : onDecline,
                  child: const Text(
                    'Từ chối',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              if (appointment.canCancel)
                TextButton(
                  onPressed: isUpdating ? null : onCancel,
                  child: const Text(
                    'Hủy',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              if (appointment.canConfirm)
                ElevatedButton(
                  onPressed: isUpdating ? null : onConfirm,
                  child: isUpdating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Xác nhận'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} ${date.hour}:$minute';
  }

  String _phone(String? phone) {
    return phone == null || phone.trim().isEmpty ? '' : ' - ${phone.trim()}';
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      'confirmed' => ('Đã xác nhận', AppColors.success, AppColors.successBg),
      'declined' => ('Từ chối', AppColors.error, AppColors.errorBg),
      'cancelled' => ('Đã hủy', AppColors.textMuted, context.profileSubtleCard),
      _ => ('Đang chờ', AppColors.warning, AppColors.warningBg),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: context.profileTextMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: context.profileTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
