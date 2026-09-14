import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/baby.dart';
import '../services/api_service.dart';
import '../services/baby_service.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _inviteCodeController = TextEditingController();
  final TextEditingController _babyNameController = TextEditingController();
  
  bool _isLoading = false;
  bool _isSavingProfile = false;
  String? _generatedCode;
  String _familyName = "Ailemiz";
  DateTime? _babyBirthDate;
  List<String> _familyMembers = [];

  List<Baby> _babies = [];
  String? _activeBabyId;

  @override
  void initState() {
    super.initState();
    _loadFamilyInfo();
    _loadBabies();
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    _babyNameController.dispose();
    super.dispose();
  }

  Future<void> _loadBabies() async {
    final babies = await BabyService.getBabies();
    final active = await BabyService.getActiveBaby();
    if (mounted) {
      setState(() {
        _babies = babies;
        _activeBabyId = active?.id;
        if (active != null) {
          _babyNameController.text = active.name;
          _babyBirthDate = active.birthDate;
        }
      });
    }
  }

  Future<void> _loadFamilyInfo() async {
    final info = await ApiService.getFamilyInfo();
    if (info != null && mounted) {
      setState(() {
        _familyName = info['familyName'] ?? 'Ailemiz';
        // Lokal bebek adı varsa onu koru, yoksa API değerini kullan
        if (_babyNameController.text.isEmpty) {
          _babyNameController.text = info['babyName'] ?? 'Bebeğimiz';
        }
        
        if (info['babyBirthDate'] != null) {
          _babyBirthDate = DateTime.tryParse(info['babyBirthDate'])?.toLocal();
        }
        
        // YENİ EKLENDİ: API'den gelen üyeleri listeye aktar (Eğer backend 'members' dizisi dönüyorsa)
        if (info['members'] is List) {
          _familyMembers = (info['members'] as List).map((e) => e.toString()).toList();
        } else {
          // Eğer API henüz üye listesi dönmüyorsa geçici olarak sadece anlık kullanıcıyı göster
          _familyMembers = ['Siz (Yönetici)'];
        }
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSavingProfile = true);
    final babyName = _babyNameController.text.trim();

    // Yerel bebek listesini güncelle
    if (_activeBabyId != null && babyName.isNotEmpty) {
      await BabyService.updateBaby(Baby(
        id: _activeBabyId!,
        name: babyName,
        birthDate: _babyBirthDate,
      ));
      await _loadBabies();
    }

    final success = await ApiService.updateFamilyInfo(_familyName, babyName, _babyBirthDate);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Profil başarıyla güncellendi!' : 'Güncelleme başarısız oldu.'),
          backgroundColor: success ? Theme.of(context).colorScheme.primary : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    if (mounted) setState(() => _isSavingProfile = false);
  }

  Future<void> _pickBirthDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _babyBirthDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: Theme.of(context).colorScheme.primary),
        ),
        child: child!,
      ),
    );

    if (pickedDate != null) {
      setState(() {
        _babyBirthDate = pickedDate;
      });
    }
  }

  String _calculateAge() {
    if (_babyBirthDate == null) return "Gelişim takibi için doğum tarihi ekleyin";
    final now = DateTime.now();
    int months = (now.year - _babyBirthDate!.year) * 12 + now.month - _babyBirthDate!.month;
    if (now.day < _babyBirthDate!.day) months--; 
    if (months < 0) return "Henüz doğmadı";
    if (months == 0) {
      final days = now.difference(_babyBirthDate!).inDays;
      return "$days günlük";
    }
    return "$months aylık";
  }

  String _ageText(DateTime birth) {
    final now = DateTime.now();
    int months = (now.year - birth.year) * 12 + now.month - birth.month;
    if (now.day < birth.day) months--;
    if (months < 0) return 'Henüz doğmadı';
    if (months == 0) return '${now.difference(birth).inDays} günlük';
    return '$months aylık';
  }

  void _showAddBabySheet() {
    final nameCtrl = TextEditingController();
    DateTime? birth;
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24, right: 24, top: 24,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              Text('Yeni Bebek Ekle', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: colors.onSurface)),
              const SizedBox(height: 24),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Bebeğin Adı',
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2C223A) : const Color(0xFFF5F0F6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.only(right: 16, top: 18, bottom: 18),
                  prefixIcon: Padding(padding: const EdgeInsets.only(left: 16, right: 12), child: Icon(Icons.child_care_rounded, color: colors.primary, size: 20)),
                  prefixIconConstraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().subtract(const Duration(days: 90)),
                    firstDate: DateTime.now().subtract(const Duration(days: 730)),
                    lastDate: DateTime.now(),
                    helpText: 'Doğum Tarihini Seçin',
                  );
                  if (picked != null) setSheet(() => birth = picked);
                },
                controller: TextEditingController(
                  text: birth != null
                      ? '${birth!.day.toString().padLeft(2, '0')} / ${birth!.month.toString().padLeft(2, '0')} / ${birth!.year}'
                      : '',
                ),
                decoration: InputDecoration(
                  hintText: 'Doğum tarihi seçin (isteğe bağlı)',
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2C223A) : const Color(0xFFF5F0F6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.only(right: 16, top: 18, bottom: 18),
                  prefixIcon: Padding(padding: const EdgeInsets.only(left: 16, right: 12), child: Icon(Icons.calendar_month_rounded, color: colors.primary, size: 20)),
                  prefixIconConstraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final n = nameCtrl.text.trim();
                    if (n.isEmpty) return;
                    await BabyService.addBaby(Baby(id: BabyService.generateId(), name: n, birthDate: birth));
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadBabies();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Ekle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(nameCtrl.dispose);
  }

  Future<void> _confirmDeleteBaby(Baby baby) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Bebeği Sil', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('${baby.name} profilini silmek istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await BabyService.deleteBaby(baby.id);
      await _loadBabies();
    }
  }

  void _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Çıkış Yap', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ApiService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthScreen()), (route) => false);
    }
  }

  void _deleteAccount() async {
    final passwordController = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Hesabı Sil', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bu işlem geri alınamaz. Tüm verileriniz kalıcı olarak silinecek.'),
              const SizedBox(height: 16),
              const Text('Onaylamak için şifrenizi girin:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                decoration: InputDecoration(
                  hintText: 'Şifreniz',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setModalState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text('Hesabı Sil'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final password = passwordController.text.trim();
    passwordController.dispose();
    if (password.isEmpty) return;

    final error = await ApiService.deleteAccount(password);
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      return;
    }

    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthScreen()), (route) => false);
  }

  // --- AİLE YÖNETİMİ İÇİN ALTTAN AÇILAN MODERN PANEL (BOTTOM SHEET) ---
  void _showFamilyBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder( 
        builder: (BuildContext context, StateSetter setModalState) {
          final themeColors = Theme.of(context).colorScheme;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24, 
              left: 24, right: 24, top: 24,
            ),
            decoration: BoxDecoration(
              color: themeColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 24),
                  
                  Text('Aile Yönetimi', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: themeColors.onSurface)),
                  const SizedBox(height: 8),
                  Text('Uyku verilerini eşinizle gerçek zamanlı senkronize edin.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                  const SizedBox(height: 32),

                  // YENİ EKLENDİ: 1. MEVCUT ÜYELER LİSTESİ
                  Text('Mevcut Aile Üyeleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeColors.onSurface)),
                  const SizedBox(height: 12),
                  if (_familyMembers.isEmpty)
                    Text('Şu an ailede sadece siz varsınız.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54))
                  else
                    ..._familyMembers.map((member) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C223A) : const Color(0xFFF5F0F6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: themeColors.primary.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: themeColors.primary.withValues(alpha: 0.2),
                                child: Icon(Icons.person_rounded, color: themeColors.primary),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  member,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: themeColors.onSurface),
                                ),
                              ),
                              Icon(Icons.check_circle_rounded, color: Colors.green.withValues(alpha: 0.8), size: 20),
                            ],
                          ),
                        )),
                  
                  Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Divider(color: themeColors.primary.withValues(alpha: 0.1), thickness: 2)),

                  // 2. DAVET ET
                  Text('Yeni Üye Davet Et', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeColors.onSurface)),
                  const SizedBox(height: 12),
                  if (_generatedCode != null)
                    Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(color: themeColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: themeColors.primary.withValues(alpha: 0.3))),
                          child: Center(
                            child: Text(_generatedCode!, style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: themeColors.primary, letterSpacing: 8)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _generatedCode!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Davet kodu kopyalandı!'),
                                  backgroundColor: themeColors.primary,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded),
                            label: const Text('Kodu Kopyala', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : () async {
                          setModalState(() => _isLoading = true);
                          final code = await ApiService.generateInvite();
                          try {
                            setModalState(() {
                              _generatedCode = code;
                              _isLoading = false;
                            });
                          } catch (_) {}
                        },
                        icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('Eşiniz İçin Kod Üretin', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: themeColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      ),
                    ),
                  
                  Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Divider(color: themeColors.primary.withValues(alpha: 0.1), thickness: 2)),

                  // 3. KATIL
                  Text('Bir Aileye Katıl', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeColors.onSurface)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _inviteCodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'Eşinizden gelen 6 haneli kod',
                      filled: true,
                      counterText: "",
                      fillColor: isDark ? const Color(0xFF2C223A) : const Color(0xFFF5F0F6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      prefixIcon: Icon(Icons.key_rounded, color: themeColors.primary.withValues(alpha: 0.6)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () async {
                        final code = _inviteCodeController.text.trim();
                        if (code.length != 6) return;
                        final messenger = ScaffoldMessenger.of(context);
                        setModalState(() => _isLoading = true);
                        final success = await ApiService.joinFamily(code);
                        if (success) {
                          if (context.mounted) Navigator.pop(context);
                          if (mounted) {
                            messenger.showSnackBar(const SnackBar(content: Text('Aileye başarıyla katıldınız!')));
                            _loadFamilyInfo();
                          }
                        } else {
                          setModalState(() => _isLoading = false);
                          messenger.showSnackBar(const SnackBar(content: Text('Geçersiz veya süresi dolmuş kod.'), backgroundColor: Colors.red));
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: isDark ? const Color(0xFF382F44) : const Color(0xFFD8CADD), foregroundColor: themeColors.onSurface, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                      child: const Text('Aileye Katıl', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profil & Ayarlar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: themeColors.onSurface)),
            const SizedBox(height: 32),

            // --- BEBEKLERİM ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Bebeklerim', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: themeColors.onSurface)),
                TextButton.icon(
                  onPressed: () => _showAddBabySheet(),
                  icon: Icon(Icons.add_rounded, color: themeColors.primary, size: 18),
                  label: Text('Ekle', style: TextStyle(color: themeColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_babies.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('Henüz bebek eklenmemiş.', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
              )
            else
              ...List.generate(_babies.length, (i) {
                final baby = _babies[i];
                final isActive = baby.id == _activeBabyId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? themeColors.primary.withValues(alpha: 0.1)
                        : (isDark ? const Color(0xFF2C223A) : const Color(0xFFF5F0F6)),
                    borderRadius: BorderRadius.circular(16),
                    border: isActive
                        ? Border.all(color: themeColors.primary, width: 1.5)
                        : null,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: themeColors.primary.withValues(alpha: isActive ? 0.25 : 0.1),
                      child: Text(
                        baby.name.isNotEmpty ? baby.name[0].toUpperCase() : '?',
                        style: TextStyle(color: themeColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      baby.name,
                      style: TextStyle(fontWeight: FontWeight.w700, color: themeColors.onSurface),
                    ),
                    subtitle: baby.birthDate != null
                        ? Text(_ageText(baby.birthDate!), style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38))
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isActive)
                          Icon(Icons.check_circle_rounded, color: themeColors.primary, size: 20),
                        const SizedBox(width: 4),
                        if (_babies.length > 1)
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withValues(alpha: 0.7), size: 20),
                            onPressed: () => _confirmDeleteBaby(baby),
                          ),
                      ],
                    ),
                    onTap: isActive ? null : () async {
                      await BabyService.setActiveBaby(baby.id);
                      await _loadBabies();
                    },
                  ),
                );
              }),
            const SizedBox(height: 16),

            // --- GÖRSEL OLARAK YENİLENMİŞ BEBEK KARTI ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: themeColors.surface,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [themeColors.primary, const Color(0xFF836FA9)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: themeColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: const Icon(Icons.child_care_rounded, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_babyNameController.text.isEmpty ? 'Bebek Profili' : _babyNameController.text, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: themeColors.onSurface)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: themeColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(_calculateAge(), style: TextStyle(color: themeColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  TextField(
                    controller: _babyNameController,
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Bebeğinizin Adı',
                      labelStyle: TextStyle(fontWeight: FontWeight.bold, color: themeColors.primary),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF2C223A) : const Color(0xFFF5F0F6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      prefixIcon: Icon(Icons.edit_rounded, color: themeColors.primary.withValues(alpha: 0.6)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: _pickBirthDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C223A) : const Color(0xFFF5F0F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cake_rounded, color: themeColors.primary.withValues(alpha: 0.6)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _babyBirthDate == null 
                                ? 'Doğum Tarihi Seçin' 
                                : '${_babyBirthDate!.day.toString().padLeft(2,'0')} / ${_babyBirthDate!.month.toString().padLeft(2,'0')} / ${_babyBirthDate!.year}',
                              style: TextStyle(
                                color: _babyBirthDate == null ? (isDark ? Colors.white54 : Colors.black54) : themeColors.onSurface, 
                                fontSize: 16, 
                                fontWeight: _babyBirthDate == null ? FontWeight.normal : FontWeight.w600
                              ),
                            ),
                          ),
                          Icon(Icons.calendar_month_rounded, color: themeColors.primary, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSavingProfile ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSavingProfile
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Değişiklikleri Kaydet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),

            // --- AİLE YÖNETİMİ BUTONU ---
            GestureDetector(
              onTap: _showFamilyBottomSheet,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C223A) : const Color(0xFFF5F0F6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: themeColors.primary.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.6), shape: BoxShape.circle),
                      child: Icon(Icons.family_restroom_rounded, color: themeColors.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Aile Yönetimi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeColors.onSurface)),
                          const SizedBox(height: 4),
                          Text('Eşinizi davet edin veya katılın', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: themeColors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),

            // ÇIKIŞ YAP
            Center(
              child: TextButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                label: const Text('Hesaptan Çıkış Yap', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _deleteAccount,
                child: const Text('Hesabı Kalıcı Olarak Sil', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}