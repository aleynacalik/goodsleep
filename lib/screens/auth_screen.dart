import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/baby_service.dart';
import 'main_navigation.dart';
import 'onboarding_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true; // Giriş mi Kayıt mı?
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _syncPendingBabyData() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingName = prefs.getString('pending_baby_name');
    final pendingBirth = prefs.getString('pending_baby_birth');
    if (pendingName == null && pendingBirth == null) return;

    final familyInfo = await ApiService.getFamilyInfo();
    final familyName = familyInfo?['familyName'] as String? ?? '';
    final birthDate = pendingBirth != null ? DateTime.tryParse(pendingBirth) : null;

    await ApiService.updateFamilyInfo(familyName, pendingName ?? '', birthDate);
    await prefs.remove('pending_baby_name');
    await prefs.remove('pending_baby_birth');
  }

  void _submit() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name     = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLogin && name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen tüm alanları doldurun.'), backgroundColor: Colors.red));
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli bir e-posta adresi girin.'), backgroundColor: Colors.red));
      return;
    }
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifre en az 8 karakter olmalıdır.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    if (_isLogin) {
      final error = await ApiService.login(email, password);
      if (!mounted) return;
      if (error == null) {
        await _syncPendingBabyData();
        if (!mounted) return;
        final babies = await BabyService.getBabies();
        final prefs = await SharedPreferences.getInstance();
        final needsSetup = babies.isEmpty;
        if (needsSetup) await prefs.setBool('onboarding_done', false);
        if (!mounted) return;
        if (needsSetup) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingScreen(postLogin: true)));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    } else {
      final error = await ApiService.register(name, email, password);
      if (!mounted) return;
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kayıt başarılı! Şimdi giriş yapabilirsiniz.'), backgroundColor: Colors.green));
        setState(() => _isLogin = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.nightlight_round, size: 80, color: themeColors.primary),
                const SizedBox(height: 16),
                Text('Little Dreams', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: themeColors.onSurface)),
                const SizedBox(height: 8),
                Text(_isLogin ? 'Hoş geldiniz, devam etmek için giriş yapın.' : 'Ailenizi kurmak için kayıt olun.', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                const SizedBox(height: 40),

                if (!_isLogin) ...[
                  _buildTextField(controller: _nameController, label: 'Adınız', icon: Icons.person_rounded, isDark: isDark),
                  const SizedBox(height: 16),
                ],
                
                _buildTextField(controller: _emailController, label: 'E-Posta', icon: Icons.email_rounded, isDark: isDark, isEmail: true),
                const SizedBox(height: 16),
                
                _buildTextField(controller: _passwordController, label: 'Şifre', icon: Icons.lock_rounded, isDark: isDark, isPassword: true),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isLogin ? 'Giriş Yap' : 'Kayıt Ol', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),

                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin ? 'Hesabınız yok mu? Kayıt Olun' : 'Zaten hesabınız var mı? Giriş Yapın',
                    style: TextStyle(color: themeColors.primary, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, required bool isDark, bool isPassword = false, bool isEmail = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
        filled: true,
        fillColor: isDark ? const Color(0xFF2C223A) : const Color(0xFFEBE3EE),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }
}