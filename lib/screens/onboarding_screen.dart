import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/baby.dart';
import '../services/baby_service.dart';
import 'auth_screen.dart';
import 'main_navigation.dart';

class OnboardingScreen extends StatefulWidget {
  final bool postLogin;
  const OnboardingScreen({super.key, this.postLogin = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  final _nameController = TextEditingController();
  DateTime? _birthDate;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.subtract(const Duration(days: 180)),
      firstDate: now.subtract(const Duration(days: 730)),
      lastDate: now,
      helpText: 'Doğum Tarihini Seçin',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _complete() async {
    final name = _nameController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    if (name.isNotEmpty) await prefs.setString('pending_baby_name', name);
    if (_birthDate != null) {
      await prefs.setString('pending_baby_birth', _birthDate!.toIso8601String());
    }
    // Yerel bebek listesine kaydet
    if (name.isNotEmpty) {
      final existing = await BabyService.getBabies();
      if (existing.isEmpty) {
        await BabyService.addBaby(Baby(
          id: BabyService.generateId(),
          name: name,
          birthDate: _birthDate,
        ));
      }
    }
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => widget.postLogin
              ? const MainNavigationScreen()
              : const AuthScreen(),
        ),
      );
    }
  }

  String _formatDate(DateTime d) {
    const months = ['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran',
                    'Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'];
    return '${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1425) : const Color(0xFFF4F0F6),
      body: SafeArea(
        child: Column(
          children: [
            // Skip butonu (sadece sayfa 1'de)
            Align(
              alignment: Alignment.topRight,
              child: AnimatedOpacity(
                opacity: _page == 0 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: _page == 0 ? _complete : null,
                  child: Text('Atla', style: TextStyle(color: colors.primary.withValues(alpha: 0.6))),
                ),
              ),
            ),

            // Dot indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _page == i ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _page == i ? colors.primary : colors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _buildWelcomePage(colors, isDark),
                  _buildBabyInfoPage(colors, isDark),
                ],
              ),
            ),

            // Alt buton
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _page == 0 ? _next : _complete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: Text(
                    _page == 0 ? 'Başlayalım' : 'Hesap Oluştur / Giriş Yap',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage(ColorScheme colors, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5C4B71), Color(0xFFB19CD9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: const Color(0xFF836FA9).withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8)),
              ],
            ),
            child: const Icon(Icons.nightlight_round, color: Colors.white, size: 52),
          ),
          const SizedBox(height: 28),
          Text(
            'Tatlı Rüyalar',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: colors.onSurface),
          ),
          const SizedBox(height: 10),
          Text(
            'Bebeğinizin uyku yolculuğunda\nyanlınızdayız.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: isDark ? Colors.white54 : Colors.black45, height: 1.5),
          ),
          const SizedBox(height: 40),
          _featureRow(Icons.bedtime_rounded, 'Uyku Takibi', 'Tüm uyku verilerini kayıt altında tut', colors, isDark),
          const SizedBox(height: 16),
          _featureRow(Icons.school_rounded, 'Kişisel Koç', 'Kanıta dayalı, şefkatli uyku yöntemleriyle rehberlik', colors, isDark),
          const SizedBox(height: 16),
          _featureRow(Icons.people_rounded, 'Aile Senkronizasyonu', 'Anne ve babanın verisi her zaman güncel', colors, isDark),
          const SizedBox(height: 16),
          _featureRow(Icons.notifications_rounded, 'Akıllı Bildirimler', 'Uyku penceresi ve rutin hatırlatıcıları', colors, isDark),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String title, String subtitle, ColorScheme colors, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: colors.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colors.onSurface)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black38)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBabyInfoPage(ColorScheme colors, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.child_care_rounded, color: colors.primary, size: 48),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Bebeğinizi Tanıyalım',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: colors.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'Bu bilgiler uyku penceresi tahmini ve koç programı için kullanılır.',
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black38, height: 1.4),
          ),
          const SizedBox(height: 32),

          // Bebek adı
          Text('Bebeğin Adı', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primary)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Bebeğinin adı',
              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
              filled: true,
              fillColor: isDark ? const Color(0xFF2C223A) : const Color(0xFFEBE3EE),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              prefixIcon: Icon(Icons.child_care_rounded, color: colors.primary),
            ),
          ),
          const SizedBox(height: 24),

          // Doğum tarihi
          Text('Doğum Tarihi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primary)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _selectBirthDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C223A) : const Color(0xFFEBE3EE),
                borderRadius: BorderRadius.circular(16),
                border: _birthDate != null
                    ? Border.all(color: colors.primary, width: 1.5)
                    : null,
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: colors.primary, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    _birthDate != null ? _formatDate(_birthDate!) : 'Doğum ayını seçin',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: _birthDate != null ? FontWeight.w700 : FontWeight.normal,
                      color: _birthDate != null ? colors.onSurface : (isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'İsterseniz bu adımı atlayabilirsiniz. Profil bölümünden daha sonra eklenebilir.',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white30 : Colors.black26, height: 1.4),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
