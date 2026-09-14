import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/baby_service.dart';
import 'universal_coach_screen.dart';

// --- METOT VERİ MODELİ ---
class SleepMethod {
  final String id;
  final String title;
  final String shortDesc;
  final int minMonth;
  final int maxMonth;
  final IconData icon;
  final Color color;
  final bool hasLiveCoach;
  final String category; // YENİ: Kategori özelliği eklendi!

  SleepMethod({
    required this.id,
    required this.title,
    required this.shortDesc,
    required this.minMonth,
    required this.maxMonth,
    required this.icon,
    required this.color,
    this.hasLiveCoach = false,
    required this.category,
  });
}

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  bool _isLoading = true;
  int _babyAgeInMonths = -1; 
  String _babyName = "Bebeğiniz";

  // --- 3 KATEGORİYE AYRILMIŞ YENİ KÜTÜPHANE ---
  final List<SleepMethod> _allMethods = [
    // 1. KRİZ ANI MÜDAHALELERİ (Ağlama Krizleri İçin)
    SleepMethod(
      id: '5s',
      title: '5 Adımlı Sakinleştirme',
      shortDesc: 'Kolik bebekleri bile susturan, 5 temel prensibin aynı anda uygulanması.',
      minMonth: 0, maxMonth: 4,
      icon: Icons.waves_rounded,
      color: const Color(0xFF5C4B71), 
      hasLiveCoach: true,
      category: 'kriz', 
    ),
    SleepMethod(
      id: 'hold_cocktail',
      title: 'Kokteyl Tekniği',
      shortDesc: 'Bebeği havaya kaldırıp kokteyl çalkalar gibi yapılan hızlı ritmik sallama.',
      minMonth: 0, maxMonth: 6,
      icon: Icons.liquor_rounded, 
      color: const Color(0xFF5C4B71), 
      hasLiveCoach: true,
      category: 'kriz',
    ),
    SleepMethod(
      id: 'hold_wiper',
      title: 'Ön Cam Sileceği',
      shortDesc: 'Bebeğinizi dizlerinizde yan yatırıp silecek gibi sağa sola sallayın.',
      minMonth: 0, maxMonth: 6,
      icon: Icons.swap_horiz_rounded,
      color: const Color(0xFF5C4B71), 
      hasLiveCoach: true,
      category: 'kriz',
    ),

    // 2. UYKU KOÇU (Uykuya Hazırlık ve Destek)
    SleepMethod(
      id: 'swaddle_dudu',
      title: 'DUDU Kundaklama Tekniği',
      shortDesc: 'Bebeğin kollarını sabitleyip düşme hissini engelleyen sıkı sarış tekniği.',
      minMonth: 0, maxMonth: 4,
      icon: Icons.layers_rounded,
      color: const Color(0xFF5C4B71), 
      hasLiveCoach: true,
      category: 'uyku', 
    ),
    SleepMethod(
      id: 'hold_football',
      title: 'Futbol Tutuşu',
      shortDesc: 'Karnı ön kolunuzun üzerine yatırarak sağladığınız hızlı sakinleştirme.',
      minMonth: 0, maxMonth: 6,
      icon: Icons.sports_football_rounded,
      color: const Color(0xFF5C4B71), 
      hasLiveCoach: true,
      category: 'uyku',
    ),
    SleepMethod(
      id: 'hold_reverse_nursing',
      title: 'Ters Emzirme Tutuşu',
      shortDesc: 'Bebeğinizi yüzükoyun, başı dizlerinize gelecek şekilde yatırın.',
      minMonth: 0, maxMonth: 6,
      icon: Icons.airline_seat_legroom_extra_rounded,
      color: const Color(0xFF5C4B71), 
      hasLiveCoach: true,
      category: 'uyku',
    ),
    SleepMethod(
      id: 'gentle_extras',
      title: 'Emzik Tuzağı & Bebek Masajı',
      shortDesc: 'Ters psikoloji ile emzik tutturma ve rahatlatıcı bebek masajı.',
      minMonth: 0, maxMonth: 12,
      icon: Icons.favorite_rounded,
      color: const Color(0xFF5C4B71), 
      hasLiveCoach: true,
      category: 'uyku',
    ),

    SleepMethod(
      id: 'pantley_pull_off',
      title: 'Emme Çıkarma Tekniği',
      shortDesc: 'Ağlamadan bağımsız uykuya geçiş için kullanılan nazif emme-bırakma yöntemi.',
      minMonth: 2, maxMonth: 18,
      icon: Icons.self_improvement_rounded,
      color: const Color(0xFF5C4B71),
      hasLiveCoach: true,
      category: 'uyku',
    ),
    SleepMethod(
      id: 'responsive_settling',
      title: 'Şefkatli Kaldır-Yatır',
      shortDesc: 'Ağlayan bebeği kucaklayıp sakinleşince yatıran, güvenli bağlanmayı pekiştiren duyarlı yerleştirme.',
      minMonth: 0, maxMonth: 12,
      icon: Icons.child_friendly_rounded,
      color: const Color(0xFF5C4B71),
      hasLiveCoach: true,
      category: 'uyku',
    ),

    // 3. GÜNLÜK RUTİNLER (4. Trimester Yaşam Tarzı)
    SleepMethod(
      id: 'routine_skin',
      title: 'Ten Tene Temas (Kanguru)',
      shortDesc: 'Kalp atışınız ve vücut ısınızla bebeğe anne karnını yaşatan mucizevi cilt teması.',
      minMonth: 0, maxMonth: 12,
      icon: Icons.favorite_border_rounded,
      color: const Color(0xFF5C4B71), 
      hasLiveCoach: true,
      category: 'rutin',
    ),
    SleepMethod(
      id: 'routine_sling',
      title: 'Sling / Askı ile Taşıma',
      shortDesc: 'Rahimdeki sarsıntı hissini gün boyu yaşatan ergonomik taşıma yöntemi.',
      minMonth: 0, maxMonth: 12,
      icon: Icons.child_care_rounded,
      color: const Color(0xFF5C4B71), 
      hasLiveCoach: true,
      category: 'rutin',
    ),
    SleepMethod(
      id: 'routine_noise',
      title: 'Kesintisiz Beyaz Gürültü',
      shortDesc: 'Uykuyu bölen sesleri maskeleyen ve rahmin sürekli uğultusunu taklit eden sistem.',
      minMonth: 0, maxMonth: 24,
      icon: Icons.speaker_rounded,
      color: const Color(0xFF5C4B71), 
      hasLiveCoach: true,
      category: 'rutin',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchBabyData();
  }

  Future<void> _fetchBabyData() async {
    // Önce lokal BabyService'e bak
    final activeBaby = await BabyService.getActiveBaby();
    String? name = activeBaby?.name;
    DateTime? birthDate = activeBaby?.birthDate;

    // Lokal veri yoksa API'ye fallback
    if (name == null || name.isEmpty) {
      final info = await ApiService.getFamilyInfo();
      if (info != null) {
        name = info['babyName'];
        final birthStr = info['babyBirthDate'] as String?;
        if (birthStr != null) birthDate = DateTime.tryParse(birthStr)?.toLocal();
      }
    }

    int calculatedMonths = -1;
    if (birthDate != null) {
      final now = DateTime.now();
      calculatedMonths = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
      if (now.day < birthDate.day) calculatedMonths--;
      if (calculatedMonths < 0) calculatedMonths = 0;
    }

    if (mounted) {
      setState(() {
        _babyName = (name != null && name.isNotEmpty) ? name : 'Bebeğiniz';
        _babyAgeInMonths = calculatedMonths;
        _isLoading = false;
      });
    }
  }

  void _openMethodDetail(SleepMethod method) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(method.icon, color: method.color),
            const SizedBox(width: 8),
            Expanded(child: Text(method.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: Text('${method.shortDesc}\n\nBu eğitim ${method.minMonth}-${method.maxMonth} aylık dördüncü trimester bebekleri için tasarlanmıştır.'),
        actions: [
          if (method.hasLiveCoach)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); 
                
                List<Map<String, dynamic>> methodSteps = [];

                if (method.id == '5s') {
                  methodSteps = [
                    {'title': '1. Kundaklama', 'desc': 'Kollarını iki yana dümdüz uzatarak onu sıkıca kundaklayın.', 'icon': Icons.layers_rounded},
                    {'title': '2. Yan / Yüzükoyun', 'desc': 'Onu kucağınızda hafifçe yan veya yüzükoyun çevirerek rahatlatın.', 'icon': Icons.child_care_rounded},
                    {'title': '3. Şşşt Sesi', 'desc': 'Ağlaması kadar yüksek bir şşşt sesi çıkarın. (Ses şu an aktif!)', 'icon': Icons.volume_up_rounded},
                    {'title': '4. Sallama', 'desc': 'Başını ve boynunu destekleyerek, sarsmadan hızlı ritmik hareketlerle sallayın.', 'icon': Icons.waves_rounded},
                    {'title': '5. Emme', 'desc': 'Emzik veya temiz parmağınızı emmesine izin verin.', 'icon': Icons.face_retouching_natural_rounded},
                  ];
                } else if (method.id == 'swaddle_dudu') {
                  methodSteps = [
                    {'title': 'Başlangıç Pozisyonu', 'desc': 'Battaniyeyi elmas şeklinde serin. Üst köşesini ortaya kıvırıp bebeğinizin boynunu bu çizgiye yatırın.', 'icon': Icons.square_foot_rounded},
                    {'title': 'Adım 1: AŞAĞI', 'desc': 'Sağ kolunu yanına uzatın. Battaniyeyi sol çapraza (AŞAĞI) gererek çekin ve sol kalçasının altına sıkıştırın.', 'icon': Icons.arrow_downward_rounded},
                    {'title': 'Adım 2: YUKARI', 'desc': 'Sol kolunu düzleştirin. Alttaki ucu YUKARI doğru, sol omzunun altına gergin şekilde sıkıştırın.', 'icon': Icons.arrow_upward_rounded},
                    {'title': 'Adım 3: AŞAĞI/YUKARI', 'desc': 'Üstte kalan köşeyi göğsüne AŞAĞI kıvırın. Sağdaki açık ucu gererek belinde kemer gibi döndürün ve sabitleyin.', 'icon': Icons.sync_rounded},
                  ];
                } else if (method.id == 'hold_football') {
                  methodSteps = [
                    {'title': '1. Çene Desteği', 'desc': 'Kundaklanmış bebeğinizi kucağınıza oturtun, yüzünü sola döndürün ve sol elinizi çenesinin altına yerleştirin.', 'icon': Icons.sports_football_rounded},
                    {'title': '2. Öne Eğme', 'desc': 'Bebeğinizi yavaşça öne doğru eğin. Göğsü ve karnı sol kolunuza değmelidir.', 'icon': Icons.arrow_downward_rounded},
                    {'title': '3. Doğru Pozisyon', 'desc': 'Baş avucunuzda olmalı, kolları ve bacakları da aşağı doğru sarkmalıdır. Hafifçe sallayın.', 'icon': Icons.check_circle_rounded},
                  ];
                } else if (method.id == 'hold_reverse_nursing') {
                  methodSteps = [
                    {'title': '1. Oturun ve Yerleştirin', 'desc': 'Bebeğinizi sağ tarafı üzerine, başı dizlerinize, ayakları sol kalçanıza gelecek biçimde yatırın.', 'icon': Icons.airline_seat_legroom_extra_rounded},
                    {'title': '2. Sırt Desteği', 'desc': 'Yürürken veya zıplatırken başını çok iyi destekler. Sırtını hafifçe sıvazlayın.', 'icon': Icons.back_hand_rounded},
                  ];
                } else if (method.id == 'hold_cocktail') {
                  methodSteps = [
                    {'title': '1. Kucağa Oturtma', 'desc': 'Bebeğinizi oturtup sol elinizi çenesinin altına yerleştirin.', 'icon': Icons.child_care_rounded},
                    {'title': '2. Havaya Kaldırma', 'desc': 'Sağ elinizi doğrudan kalçasının altına yerleştirin ve bebeğinizi havaya kaldırın.', 'icon': Icons.upload_rounded},
                    {'title': '3. Çalkalama', 'desc': 'Sağ elinizle, bir kokteyl karıştırır gibi saniyede 2-3 kez ve küçük hareketlerle sallayın.', 'icon': Icons.liquor_rounded},
                  ];
                } else if (method.id == 'hold_wiper') {
                  methodSteps = [
                    {'title': '1. Hazırlık', 'desc': 'Ayaklarınız yere değecek şekilde rahatça oturabileceğiniz bir sandalyeye oturun.', 'icon': Icons.chair_alt_rounded},
                    {'title': '2. Bacak Arasına Yatırma', 'desc': 'Kundaklanmış bebeğinizi sağ yanı üzerine bacaklarınız arasına yatırın.', 'icon': Icons.airline_seat_recline_normal_rounded},
                    {'title': '3. Ritmik Sallama', 'desc': 'Kulağına şşşt sesi çıkarın ve dizlerinizi bir cam sileceği gibi sağa sola sallamaya başlayın.', 'icon': Icons.swap_horiz_rounded},
                  ];
                } else if (method.id == 'gentle_extras') {
                  methodSteps = [
                    {'title': '1. Ortam Hazırlığı', 'desc': 'Odayı ısıtın, ışıkları kısın. Bebeğinizi çıplak bacaklarınıza yüzükoyun yatırın.', 'icon': Icons.brightness_4_rounded},
                    {'title': '2. Bebek Masajı', 'desc': 'Ellerinizi yağlayın. Başından ayaklarına kadar hafif ve yumuşak dokunuşlarla masaj yapın.', 'icon': Icons.spa_rounded},
                    {'title': '3. Emzik Tuzağı', 'desc': 'Emziği verin, tam emmeye başladığında yavaşça ağzından çeker gibi yapın. Daha sıkı tutacaktır.', 'icon': Icons.face_retouching_natural_rounded},
                  ];
                } else if (method.id == 'pantley_pull_off') {
                  methodSteps = [
                    {'title': '1. Sakinleştirici Emzirme', 'desc': 'Bebeğinizi alışıldık şekilde emzirin veya emzik verin. Gözleri kapanmaya başlayana kadar bekleyin.', 'icon': Icons.self_improvement_rounded},
                    {'title': '2. Nazik Ayrılma', 'desc': 'Bebek yarı uykulu hale gelince parmağınızı ağzının köşesine nazikçe sokarak emişi kırın. Acele etmeyin.', 'icon': Icons.pan_tool_alt_rounded},
                    {'title': '3. Tutun ve Bekleyin', 'desc': 'Ayrıldıktan hemen sonra bırakmayın. Sıkıca kucaklayıp birkaç saniye hafifçe sallayın, uykuya devam etmesini izleyin.', 'icon': Icons.favorite_rounded},
                    {'title': '4. Gerekirse Tekrarlayın', 'desc': 'Bebek tekrar emmeye çalışırsa izin verin. 2-3 dakika sonra ayrılmayı yeniden deneyin. Her deneme bir öğrenme adımıdır.', 'icon': Icons.refresh_rounded},
                    {'title': '5. Kutlayın', 'desc': 'Her geceyi başarı olarak görün. Zamanla bebek emme olmadan da uykuya dalacak ve bu anlar giderek kısalacaktır.', 'icon': Icons.star_rounded},
                  ];
                } else if (method.id == 'responsive_settling') {
                  methodSteps = [
                    {'title': '1. Uykulu Ama Uyanık', 'desc': 'Uyku rutinini tamamladıktan sonra bebeğinizi gözleri açık, uykulu ama uyanık haldeyken yatağına yatırın.', 'icon': Icons.bedtime_rounded},
                    {'title': '2. Önce Yerinde Sakinleştirin', 'desc': 'Ağlamaya başlarsa hemen kaldırmayın. "Şşşt, buradayım" diyerek sesli ve dokunuşla sakinleştirmeyi önce deneyin.', 'icon': Icons.record_voice_over_rounded},
                    {'title': '3. Gerekiyorsa Kucağa Alın', 'desc': 'Sakinleşmiyorsa nazikçe kucağınıza alın. Bağırmadan, alçak sesle konuşarak veya şşşt yaparak rahatlatın.', 'icon': Icons.child_friendly_rounded},
                    {'title': '4. Sakinleşince Yatırın', 'desc': 'Ağlaması kesilir kesilmez (tam uykuya dalmadan önce) tekrar yatağına yatırın. Yatağı güvenli alan olarak benimsemesi için bu kritiktir.', 'icon': Icons.airline_seat_flat_rounded},
                    {'title': '5. Sabırla Sürdürün', 'desc': 'İlk gecelerde 10-15 kez tekrarlayabilirsiniz. Bu normaldir. Her tekrar bebeğe "Güvendesin" mesajı verir ve bağlanmayı güçlendirir.', 'icon': Icons.favorite_border_rounded},
                  ];
                } else if (method.id == 'routine_skin') {
                  methodSteps = [
                    {'title': '1. Hazırlık', 'desc': 'Odayı sıcak tutun. Üstünüzü çıkarın, bebeğiniz de sadece beziyle kalsın.', 'icon': Icons.thermostat_rounded},
                    {'title': '2. Göğse Yatırma', 'desc': 'Bebeğinizi dik bir şekilde, doğrudan kalbinizin üzerine, çıplak göğsünüze yatırın.', 'icon': Icons.favorite_border_rounded},
                    {'title': '3. Rahatlama', 'desc': 'Üzerinize pamuklu bir battaniye örtün. Nefesiniz ve kalp atışınız onu rahme geri döndürecektir.', 'icon': Icons.spa_rounded},
                  ];
                } else if (method.id == 'routine_sling') {
                  methodSteps = [
                    {'title': '1. Ergonomik Seçim', 'desc': 'Bebeğin bacaklarının "M" harfi şeklinde duracağı, dizlerinin kalçasından yukarıda kalacağı bir askı seçin.', 'icon': Icons.check_circle_rounded},
                    {'title': '2. Yerleştirme', 'desc': 'Bebeğinizi göğsünüze asın. Yüzü dışarıda ve her an öpebileceğiniz bir yükseklikte olmalıdır.', 'icon': Icons.child_care_rounded},
                    {'title': '3. Hareket', 'desc': 'Ev işi yaparken veya yürürken oluşan o hafif sarsıntı, ona gün boyu rahim konforu yaşatacaktır.', 'icon': Icons.directions_walk_rounded},
                  ];
                } else if (method.id == 'routine_noise') {
                  methodSteps = [
                    {'title': '1. Cihaz Seçimi', 'desc': 'Telefondan ziyade, kaliteli bir beyaz gürültü makinesi veya fön makinesi/elektrik süpürgesi kaydı kullanın.', 'icon': Icons.speaker_rounded},
                    {'title': '2. Doğru Konum', 'desc': 'Cihazı beşiğin tam içine değil, odanın köşesine veya yatağın uzağına yerleştirin.', 'icon': Icons.place_rounded},
                    {'title': '3. Kesintisiz Kullanım', 'desc': 'Ses sadece bebek ağlarken değil, uykuya daldığı andan uyanana kadar KESİNTİSİZ açık kalmalıdır.', 'icon': Icons.all_inclusive_rounded},
                  ];
                }

                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => UniversalCoachScreen(
                    title: '${method.title} Asistanı',
                    color: method.color,
                    steps: methodSteps,
                  ),
                ));
              },
              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              label: const Text('Asistanı Başlat', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: method.color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Kapat', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
        ],
      ),
    );
  }

  String _sleepExpectation(int months) {
    if (months <= 3)  return 'Günlük 14–17 saat uyku beklenir. 4–5 gündüz uykusu, gece 4–6 uyanma bu dönem için normaldir.';
    if (months <= 6)  return 'Günlük 12–15 saat uyku beklenir. 3–4 gündüz uykusu, gece 2–4 uyanma normaldir.';
    if (months <= 9)  return 'Günlük 12–14 saat uyku beklenir. 2–3 gündüz uykusu, gece 1–3 uyanma beklenir.';
    if (months <= 12) return 'Günlük 12–14 saat uyku beklenir. 2 gündüz uykusu, gece 1–2 uyanma normaldir.';
    if (months <= 18) return 'Günlük 11–14 saat uyku beklenir. 1–2 gündüz uykusu, gece uyanmalar azalmaktadır.';
    if (months <= 24) return 'Günlük 11–14 saat uyku beklenir. 1 gündüz uykusu, gece kesintisiz uyku gelişmektedir.';
    return 'Günlük 10–13 saat uyku beklenir. Gündüz uykusu ilerleyen aylarda azalabilir.';
  }

  // --- KATEGORİ SEKSİYONUNU OLUŞTURAN YARDIMCI WIDGET ---
  Widget _buildCategorySection(String title, IconData icon, String category, ColorScheme themeColors, bool isDark) {
    final methods = _allMethods.where((m) => m.category == category).toList();
    if (methods.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: themeColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: themeColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeColors.onSurface))),
          ],
        ),
        const SizedBox(height: 16),
        ...methods.map((method) => _buildMethodCard(method, themeColors, isDark)),
        const SizedBox(height: 32), // Bölümler arası boşluk
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: _isLoading
          ? Center(child: CircularProgressIndicator(color: themeColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Uyku Rehberi', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: themeColors.onSurface)),
                  const SizedBox(height: 24),

                  // DURUM KARTI
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [themeColors.primary, const Color(0xFF836FA9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [if (!isDark) BoxShadow(color: themeColors.primary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              _babyAgeInMonths == -1 ? 'Gelişim Takibi' : 'Mevcut Dönem',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _babyAgeInMonths == -1
                              ? 'Özel tavsiyeler almak için lütfen Profil sayfasından doğum tarihi ekleyin.'
                              : '$_babyName şu an $_babyAgeInMonths aylık.',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.4),
                        ),
                        if (_babyAgeInMonths >= 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                            child: Text(_sleepExpectation(_babyAgeInMonths), style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5)),
                          ),
                          if (_babyAgeInMonths <= 4)
                            const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Text('4. trimester döneminde 5 adımlı sakinleştirme yöntemi en etkili yaklaşımlardan biridir.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // YENİ 3'LÜ KATEGORİ SİSTEMİ
                  _buildCategorySection('Kriz Anı Müdahaleleri', Icons.warning_amber_rounded, 'kriz', themeColors, isDark),
                  _buildCategorySection('Uyku Koçu', Icons.nights_stay_rounded, 'uyku', themeColors, isDark),
                  _buildCategorySection('Günlük Rutinler', Icons.wb_sunny_rounded, 'rutin', themeColors, isDark),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildMethodCard(SleepMethod method, ColorScheme themeColors, bool isDark) {
    return GestureDetector(
      onTap: () => _openMethodDetail(method),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: themeColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: method.color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(method.icon, color: method.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(method.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeColors.onSurface))),
                      if (method.hasLiveCoach)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Text('ASİSTAN', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(method.shortDesc, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 8),
                  Text('${method.minMonth} - ${method.maxMonth} Ay', style: TextStyle(color: method.color, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.black26),
          ],
        ),
      ),
    );
  }
}