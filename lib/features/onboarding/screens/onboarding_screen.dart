// lib/features/onboarding/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

// ─── Model dữ liệu từng slide ───────────────────────────────────────────────

class OnboardingData {
  final String tag;
  final IconData tagIcon;
  final Color tagBg;
  final Color tagText;
  final String title;
  final String description;
  final Widget illustration;

  const OnboardingData({
    required this.tag,
    required this.tagIcon,
    required this.tagBg,
    required this.tagText,
    required this.title,
    required this.description,
    required this.illustration,
  });
}

// ─── Screen chính ────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const Color _primary = Color(0xFF0057D9);

  late final List<OnboardingData> _slides = [
    OnboardingData(
      tag: 'Tìm phòng dễ dàng',
      tagIcon: Icons.home_rounded,
      tagBg: const Color(0xFFEFF6FF),
      tagText: const Color(0xFF185FA5),
      title: 'Hàng nghìn phòng\ncập nhật mỗi ngày',
      description:
      'Tìm ngay phòng trọ ưng ý chỉ trong vài giây — từ sinh viên đến căn hộ cao cấp, tất cả đều có.',
      illustration: const _Slide1Illustration(),
    ),
    OnboardingData(
      tag: 'Định vị thông minh',
      tagIcon: Icons.location_on_rounded,
      tagBg: const Color(0xFFF0FDF4),
      tagText: const Color(0xFF166534),
      title: 'Phòng trọ xịn\nngay gần bạn',
      description:
      'Bật GPS, ứng dụng tự tìm phòng trong bán kính bạn chọn — nhanh, chính xác, không cần gõ địa chỉ.',
      illustration: const _Slide2Illustration(),
    ),
    OnboardingData(
      tag: 'Kết nối trực tiếp',
      tagIcon: Icons.chat_bubble_rounded,
      tagBg: const Color(0xFFFFF7ED),
      tagText: const Color(0xFF9A3412),
      title: 'Nhắn tin chủ nhà\nkhông qua trung gian',
      description:
      'Chat trực tiếp, đặt lịch xem phòng, hỏi giá — tất cả trong một ứng dụng, nhanh gọn và miễn phí.',
      illustration: const _Slide3Illustration(),
    ),
  ];

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _onSkip() => _finishOnboarding();

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: _primary,
      body: Stack(
        children: [
          // ── Nền vòng tròn trang trí ──
          Positioned(
            top: -80,
            left: -60,
            child: _CircleBg(size: 240),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: _CircleBg(size: 200),
          ),

          // ── PageView phần illustration ──
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _slides.length,
                  itemBuilder: (_, i) => _slides[i].illustration,
                ),
              ),

              // ── Bottom sheet trắng ──
              _BottomSheet(
                slide: slide,
                pageController: _pageController,
                currentPage: _currentPage,
                totalPages: _slides.length,
                isLast: isLast,
                onNext: _onNext,
                onSkip: _onSkip,
                primary: _primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Bottom Sheet ─────────────────────────────────────────────────────────────

class _BottomSheet extends StatelessWidget {
  final OnboardingData slide;
  final PageController pageController;
  final int currentPage;
  final int totalPages;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final Color primary;

  const _BottomSheet({
    required this.slide,
    required this.pageController,
    required this.currentPage,
    required this.totalPages,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dots indicator dùng smooth_page_indicator
          SmoothPageIndicator(
            controller: pageController,
            count: totalPages,
            effect: ExpandingDotsEffect(
              activeDotColor: primary,
              dotColor: const Color(0xFFE2E8F0),
              dotHeight: 7,
              dotWidth: 7,
              expansionFactor: 3,
              spacing: 6,
            ),
          ),
          const SizedBox(height: 20),

          // Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: slide.tagBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(slide.tagIcon, size: 13, color: slide.tagText),
                const SizedBox(width: 5),
                Text(
                  slide.tag,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slide.tagText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            slide.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),

          // Description
          Text(
            slide.description,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),

          // Buttons
          isLast
              ? SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Bắt đầu ngay',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14),
                ],
              ),
            ),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: onSkip,
                child: const Text(
                  'Bỏ qua',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  children: [
                    Text('Tiếp theo',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 13),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Decoration helpers ───────────────────────────────────────────────────────

class _CircleBg extends StatelessWidget {
  final double size;
  const _CircleBg({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.07),
      ),
    );
  }
}

// ─── Illustration Slide 1: Ngôi nhà + floating cards ─────────────────────────

class _Slide1Illustration extends StatelessWidget {
  const _Slide1Illustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Floating card trên phải
        Positioned(
          top: 40,
          right: 20,
          child: _FloatingCard(
            iconBg: const Color(0xFFDBEAFE),
            icon: Icons.home_rounded,
            iconColor: const Color(0xFF185FA5),
            label: 'Phòng trọ',
            value: '12,400+',
          ),
        ),
        // Floating card dưới trái
        Positioned(
          bottom: 24,
          left: 20,
          child: _FloatingCard(
            iconBg: const Color(0xFFDCFCE7),
            icon: Icons.verified_rounded,
            iconColor: const Color(0xFF166534),
            label: 'Đã xác thực',
            value: '8,200+',
            valueColor: const Color(0xFF166534),
          ),
        ),
        // Ngôi nhà trung tâm
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(110, 55),
              painter: _RoofPainter(),
            ),
            Container(
              width: 110,
              height: 80,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB5D4F4),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF85B7EB), width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 26,
                    height: 40,
                    margin: const EdgeInsets.only(bottom: 0),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0057D9),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB5D4F4),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF85B7EB), width: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Illustration Slide 2: Mini Map ──────────────────────────────────────────

class _Slide2Illustration extends StatelessWidget {
  const _Slide2Illustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Verified tag
        Positioned(
          top: 32,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(radius: 4, backgroundColor: Color(0xFF10B981)),
                SizedBox(width: 5),
                Text('Đã xác thực',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF065F46))),
              ],
            ),
          ),
        ),
        // Map card
        Container(
          width: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Map placeholder
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    // Grid lines
                    ...[0.3, 0.6].map((t) => Positioned(
                      top: null,
                      bottom: null,
                      left: 0,
                      right: 0,
                      child: FractionallySizedBox(
                        widthFactor: 1,
                        child: Align(
                          alignment: Alignment(0, (t * 2) - 1),
                          child: Container(
                            height: 1,
                            color: const Color(0xFF93C5FD).withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    )),
                    // Pins
                    const Positioned(
                        top: 28,
                        left: 80,
                        child: _MapPin(color: Color(0xFF0057D9))),
                    const Positioned(
                        top: 60,
                        left: 30,
                        child: _MapPin(color: Color(0xFF10B981))),
                    const Positioned(
                        top: 45,
                        right: 30,
                        child: _MapPin(color: Color(0xFFF59E0B))),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Info rows
              Row(
                children: [
                  const Text('Khu vực',
                      style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  const Text('Bình Thạnh',
                      style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF0057D9),
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('3 phòng',
                        style: TextStyle(
                            fontSize: 9,
                            color: Color(0xFF185FA5),
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: const [
                  Text('Giá từ',
                      style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600)),
                  SizedBox(width: 6),
                  Text('2.5tr/tháng',
                      style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF0057D9),
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Illustration Slide 3: Chat bubbles ──────────────────────────────────────

class _Slide3Illustration extends StatelessWidget {
  const _Slide3Illustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Floating card phản hồi
        Positioned(
          top: 32,
          left: 20,
          child: _FloatingCard(
            iconBg: const Color(0xFFDBEAFE),
            icon: Icons.chat_bubble_rounded,
            iconColor: const Color(0xFF185FA5),
            label: 'Phản hồi',
            value: 'Trong 5 phút',
          ),
        ),
        // Chat bubbles
        SizedBox(
          width: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ảnh thumbnail phòng
              Container(
                width: 130,
                height: 75,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      size: const Size(48, 24),
                      painter: _RoofPainter(color: Colors.white.withValues(alpha: 0.7)),
                    ),
                    Container(
                      width: 48,
                      height: 20,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Bubble trái
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                child: const Text(
                  'Phòng còn trống không ạ? 🙏',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 6),
              // Bubble phải
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(4),
                    ),
                    border:
                    Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Còn ạ! Bạn xem thứ 7 được không?',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Bubble trái 2
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                    bottomLeft: Radius.circular(4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 13, color: Color(0xFF10B981)),
                    SizedBox(width: 5),
                    Text(
                      'Ok, mình đặt lịch xem phòng!',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Reusable widgets ─────────────────────────────────────────────────────────

class _FloatingCard extends StatelessWidget {
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;

  const _FloatingCard({
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500)),
              Text(value,
                  style: TextStyle(
                      fontSize: 11,
                      color: valueColor ?? const Color(0xFF1E293B),
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  const _MapPin({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        Container(width: 2, height: 8, color: color),
      ],
    );
  }
}

class _RoofPainter extends CustomPainter {
  final Color? color;
  const _RoofPainter({this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color ?? Colors.white
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}