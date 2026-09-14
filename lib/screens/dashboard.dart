import 'dart:async';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/baby_service.dart';
import '../services/notification_service.dart';
import '../main.dart';
import 'guide.dart';

const _sleepTips = [
  {'kaynak': 'Uyku Koçluğu', 'ipucu': 'Tutarlı bir yatış rutini bebeğe "uyku vakti geliyor" mesajı verir — rutin başladığında bebek sakinleşmeye başlar.'},
  {'kaynak': 'Uyku Koçluğu', 'ipucu': 'Emzirme bitmeden bebeği hafifçe uyandırın. Bu küçük adım, emzirme-uyku bağlantısını kırmada büyük fark yaratır.'},
  {'kaynak': 'Uyku Koçluğu', 'ipucu': 'Küçük ve kademeli değişimler büyük müdahalelerden çok daha kalıcı sonuç verir. Sabır bu yolculuğun en güçlü aracıdır.'},
  {'kaynak': 'Uyku Koçluğu', 'ipucu': '5 adımlı sakinleştirme yöntemi hepsini aynı anda uygulayınca güçlüdür: Sarmalama, Yan pozisyon, Şşşt sesi, Sallama ve emzik.'},
  {'kaynak': 'Uyku Koçluğu', 'ipucu': 'İlk 3 ayda sarıp sakinleştirmek bağımsız uyku becerisini zedelemez — ihtiyaçları karşılanan bebekler daha iyi uyur.'},
  {'kaynak': 'Uyku Koçluğu', 'ipucu': '"Uykuya yakın ama hâlâ uyanık" yatırmak bağımsız uyku becerisinin temelidir. Derin uykuya dalmadan önce beşiğe koyun.'},
  {'kaynak': 'Uyku Koçluğu', 'ipucu': 'Göz ovma, bakış bulanıklaşması, kulak çekme — bu sinyalleri fark ettiğinizde doğru uyku penceresini yakalamışsınızdır.'},
  {'kaynak': 'Uyku Koçluğu', 'ipucu': 'Gece uyanmalarında hemen koşmayın; 2–3 dakika bekleyin. Bebekler uyku döngüleri arasında kendi kendine tekrar uyuyabilir.'},
  {'kaynak': 'AAP', 'ipucu': 'Amerikan Pediatri Akademisi uyku odası sıcaklığının 16–20°C arasında olmasını önerir. Fazla sıcak ortam uyku kalitesini düşürür.'},
  {'kaynak': 'AAP', 'ipucu': 'Bebeği her zaman sırtüstü yatırın — bu hem güvenlidir hem de beyin için "uyku vakti" sinyali oluşturur.'},
  {'kaynak': 'Araştırmalar', 'ipucu': 'Beyaz gürültü uyku döngüleri arasındaki geçişleri kolaylaştırır — beşikten 30 cm uzakta, 60–65 dB, tüm gece boyunca kullanın.'},
  {'kaynak': 'Araştırmalar', 'ipucu': 'Uyku penceresi kaçırıldığında kortizol devreye girer. İlk yorgunluk işaretinde harekete geçmek uyutma süresini dramatik biçimde kısaltır.'},
];

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _babyName = "Bebeğimiz";

  bool _isSleeping = false;
  DateTime? _sleepStartTime;
  Timer? _timer;
  Duration _currentSleepDuration = Duration.zero;

  int _weeklyCount = 0;
  double _weeklyTotalHours = 0;
  double _weeklyAvgHours = 0;
  bool _weeklyLoaded = false;

  Timer? _pollTimer;
  DateTime? _babyBirthDate;
  DateTime? _lastSleepEnd;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 6)  return 'İyi geceler 🌙';
    if (hour < 12) return 'Günaydın ☀️';
    if (hour < 17) return 'İyi öğleden sonralar 🌤️';
    if (hour < 21) return 'İyi akşamlar ✨';
    return 'İyi geceler 🌙';
  }

  Map<String, String> get _currentTip {
    final index = (DateTime.now().hour ~/ 2) % _sleepTips.length;
    return _sleepTips[index];
  }

  @override
  void initState() {
    super.initState();
    _loadSleepState();
    _loadBabyName();
    _loadWeeklySummary();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadWeeklySummary());
    HomeWidget.setAppGroupId('group.com.aleynacalik.goodsleep');
  }

  Future<void> _loadWeeklySummary() async {
    final logs = await ApiService.getLogs();
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final week = logs.where((l) {
      try { return DateTime.parse(l['startTime'] as String).isAfter(cutoff); }
      catch (_) { return false; }
    }).toList();
    if (!mounted) return;
    final totalSecs = week.fold<int>(0, (s, l) => s + ((l['durationInSeconds'] as num?)?.toInt() ?? 0));

    DateTime? lastEnd;
    for (final l in logs) {
      try {
        final endStr = l['endTime'] as String?;
        if (endStr != null) {
          final t = DateTime.parse(endStr);
          if (lastEnd == null || t.isAfter(lastEnd)) lastEnd = t;
        }
      } catch (_) {}
    }

    setState(() {
      _weeklyCount = week.length;
      _weeklyTotalHours = totalSecs / 3600;
      _weeklyAvgHours = week.isEmpty ? 0 : _weeklyTotalHours / week.length;
      _weeklyLoaded = true;
      if (lastEnd != null) _lastSleepEnd = lastEnd;
    });
  }

  Future<void> _loadBabyName() async {
    final baby = await BabyService.getActiveBaby();
    if (baby != null && mounted) {
      setState(() {
        _babyName = baby.name;
        _babyBirthDate = baby.birthDate;
      });
      return;
    }
    // Fallback: API'den çek (eski kullanıcılar için)
    final info = await ApiService.getFamilyInfo();
    if (info != null && mounted) {
      final birthStr = info['babyBirthDate'] as String?;
      setState(() {
        _babyName = info['babyName'] ?? 'Bebeğimiz';
        _babyBirthDate = birthStr != null ? DateTime.tryParse(birthStr) : null;
      });
    }
  }

  Future<void> _loadSleepState() async {
    final prefs = await SharedPreferences.getInstance();
    final isSleeping = prefs.getBool('isSleeping') ?? false;
    final startTimeStr = prefs.getString('sleepStartTime');

    if (isSleeping && startTimeStr != null) {
      final startTime = DateTime.parse(startTimeStr);
      setState(() {
        _isSleeping = true;
        _sleepStartTime = startTime;
        _currentSleepDuration = DateTime.now().difference(startTime);
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) { timer.cancel(); return; }
        setState(() {
          _currentSleepDuration = DateTime.now().difference(_sleepStartTime!);
        });
      });
    }
  }

  void _toggleSleep() async {
    final prefs = await SharedPreferences.getInstance();

    if (!_isSleeping) {
      final startTime = DateTime.now();
      await prefs.setBool('isSleeping', true);
      await prefs.setString('sleepStartTime', startTime.toIso8601String());
      await NotificationService.scheduleSleepReminder();
      await HomeWidget.saveWidgetData('babyName', _babyName);
      await HomeWidget.saveWidgetData('isSleeping', true);
      await HomeWidget.saveWidgetData('sleepDuration', '00:00:00');
      await HomeWidget.updateWidget(
          name: 'SleepWidgetProvider', iOSName: 'SleepWidget');
      setState(() {
        _isSleeping = true;
        _sleepStartTime = startTime;
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted) { timer.cancel(); return; }
          setState(() {
            _currentSleepDuration = DateTime.now().difference(_sleepStartTime!);
          });
          if (_currentSleepDuration.inSeconds % 30 == 0) {
            HomeWidget.saveWidgetData(
                'sleepDuration', _formatDuration(_currentSleepDuration));
            HomeWidget.updateWidget(
                name: 'SleepWidgetProvider', iOSName: 'SleepWidget');
          }
        });
      });
    } else {
      if (_sleepStartTime != null) {
        _timer?.cancel();
        final endTime = DateTime.now();
        final durationInSeconds = endTime.difference(_sleepStartTime!).inSeconds;
        await prefs.remove('isSleeping');
        await prefs.remove('sleepStartTime');
        await NotificationService.cancelSleepReminder();
        final saved = await ApiService.addLog(_sleepStartTime!, endTime, durationInSeconds);
        if (!saved && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uyku kaydedilemedi. Bağlantınızı kontrol edin.'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
        await HomeWidget.saveWidgetData('isSleeping', false);
        await HomeWidget.saveWidgetData('sleepDuration', '');
        await HomeWidget.updateWidget(
            name: 'SleepWidgetProvider', iOSName: 'SleepWidget');
        setState(() {
          _isSleeping = false;
          _currentSleepDuration = Duration.zero;
          _sleepStartTime = null;
          _lastSleepEnd = endTime;
        });
        _loadWeeklySummary();
      }
    }
  }

  Widget _statCell(String value, String label, ColorScheme colors) => Expanded(
    child: Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: colors.primary)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
      ],
    ),
  );

  Widget _statDivider(bool isDark) => Container(width: 1, height: 36, color: isDark ? Colors.white12 : Colors.black12);

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Duration _wakeWindowForAge(DateTime birth) {
    final weeks = DateTime.now().difference(birth).inDays ~/ 7;
    if (weeks < 4)  return const Duration(minutes: 50);
    if (weeks < 8)  return const Duration(minutes: 75);
    if (weeks < 12) return const Duration(minutes: 90);
    if (weeks < 16) return const Duration(hours: 2);
    if (weeks < 24) return const Duration(hours: 2, minutes: 30);
    if (weeks < 36) return const Duration(hours: 3);
    if (weeks < 52) return const Duration(hours: 3, minutes: 30);
    if (weeks < 78) return const Duration(hours: 4, minutes: 30);
    return const Duration(hours: 5, minutes: 30);
  }

  String _formatWakeWindow(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes} dk';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return m == 0 ? '$h sa' : '$h sa $m dk';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColors = Theme.of(context).colorScheme;

    final hPad = MediaQuery.of(context).size.width > 600
        ? (MediaQuery.of(context).size.width - 560) / 2
        : 24.0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting, style: TextStyle(color: isDark ? const Color(0xFFBDB3C7) : const Color(0xFF8E7D9E), fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Tatlı Rüyalar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: themeColors.onSurface)),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF2C223A) : const Color(0xFFEBE3EE), shape: BoxShape.circle),
                    child: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: isDark ? const Color(0xFFF6E8B6) : const Color(0xFF6C5A7D), size: 22),
                  ),
                )
              ],
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF2C223A) : const Color(0xFFEBE3EE), borderRadius: BorderRadius.circular(24)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 10, color: _isSleeping ? const Color(0xFF836FA9) : themeColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    _isSleeping ? '$_babyName uyuyor...' : 'Uyanık',
                    style: TextStyle(color: isDark ? const Color(0xFFEBE3EE) : const Color(0xFF6C5A7D), fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            GestureDetector(
              onTap: _toggleSleep,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  color: _isSleeping ? const Color(0xFF836FA9) : themeColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isSleeping ? const Color(0xFF836FA9) : themeColors.primary).withValues(alpha: isDark ? 0.1 : 0.4),
                      blurRadius: _isSleeping ? 30 : 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isSleeping ? Icons.wb_sunny_outlined : Icons.bedtime_outlined,
                      color: Colors.white,
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isSleeping ? _formatDuration(_currentSleepDuration) : 'Uyku kaydını başlat',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                    if (_isSleeping)
                      const Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: Text('Uyku kaydını durdur', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                      )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),

            // UYKU PENCERESİ TAHMİNİ
            if (_babyBirthDate != null && _lastSleepEnd != null && !_isSleeping) ...[
              Builder(builder: (context) {
                final wakeWindow = _wakeWindowForAge(_babyBirthDate!);
                final nextSleep = _lastSleepEnd!.add(wakeWindow);
                final now = DateTime.now();
                final remaining = nextSleep.difference(now);
                final isOverdue = remaining.isNegative;
                final windowStr = _formatWakeWindow(wakeWindow);
                final timeStr = isOverdue
                    ? 'Uyku zamanı geçmiş olabilir'
                    : remaining.inMinutes < 1
                        ? 'Uyku vakti!'
                        : '${remaining.inMinutes} dk sonra';
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isOverdue
                          ? [const Color(0xFF5C4B71), const Color(0xFF836FA9)]
                          : [themeColors.primary.withValues(alpha: 0.15), themeColors.primary.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: themeColors.primary.withValues(alpha: 0.25), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isOverdue ? Colors.white.withValues(alpha: 0.2) : themeColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.schedule_rounded, color: isOverdue ? Colors.white : themeColors.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'UYKU PENCERESİ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                color: isOverdue ? Colors.white70 : themeColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isOverdue ? Colors.white : themeColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Uyanık kalma süresi: $windowStr',
                              style: TextStyle(
                                fontSize: 11,
                                color: isOverdue ? Colors.white60 : (isDark ? Colors.white54 : Colors.black38),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // HAFTALIK ÖZET KARTI
            if (_weeklyLoaded) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: themeColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bar_chart_rounded, color: themeColors.primary, size: 16),
                        const SizedBox(width: 6),
                        Text('BU HAFTA', style: TextStyle(color: themeColors.primary, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_weeklyCount == 0)
                      Text('Henüz kayıt yok — büyük düğmeye basarak uyku takibine başlayın.', style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.black45, height: 1.4))
                    else
                      Row(
                        children: [
                          _statCell('${_weeklyTotalHours.toStringAsFixed(1)}s', 'Toplam Uyku', themeColors),
                          _statDivider(isDark),
                          _statCell('${_weeklyAvgHours.toStringAsFixed(1)}s', 'Ortalama', themeColors),
                          _statDivider(isDark),
                          _statCell('$_weeklyCount', 'Kayıt', themeColors),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // KÜTÜPHANEye HIZLI ERİŞİM
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                appBar: AppBar(
                  title: const Text('Uyku Kütüphanesi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  centerTitle: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                ),
                body: const GuideScreen(),
              ))),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: themeColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: themeColors.primary.withValues(alpha: 0.18), width: 1.5),
                  boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(color: themeColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.menu_book_rounded, color: themeColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Uyku Kütüphanesi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: themeColors.onSurface)),
                          const SizedBox(height: 2),
                          Text('Kanıta dayalı uyku yöntemleri', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.black26),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: themeColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('GÜNÜN İPUCU', style: TextStyle(color: themeColors.primary, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
                      const Spacer(),
                      Text(_currentTip['kaynak'] ?? '', style: TextStyle(color: themeColors.primary.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_currentTip['ipucu'] ?? '', style: TextStyle(fontSize: 15, color: themeColors.onSurface, height: 1.55, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
