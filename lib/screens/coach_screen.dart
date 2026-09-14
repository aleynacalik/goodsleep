import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/baby_service.dart';
import 'guide.dart';

// ─── MODELLER ──────────────────────────────────────────────────────────────

class _Choice {
  final String value;
  final String label;
  final String sublabel;
  final IconData icon;
  const _Choice({required this.value, required this.label, this.sublabel = '', required this.icon});
}

class _Question {
  final String key;
  final String question;
  final String subtitle;
  final List<_Choice> choices;
  const _Question({required this.key, required this.question, required this.subtitle, required this.choices});
}

class _CoachStep {
  final int order;
  final String title;
  final String why;
  final String howTo;
  final String expected;
  final IconData icon;
  final int requiredNights;
  final bool isPreparation; // tek seferlik kurulum adımı, gece takibi gerekmez
  const _CoachStep({required this.order, required this.title, required this.why, required this.howTo, required this.expected, required this.icon, this.requiredNights = 3, this.isPreparation = false});
}

class _CoachProfile {
  final String id;
  final String name;
  final String tagline;
  final String description;
  final IconData icon;
  final List<_CoachStep> steps;
  final String checkInLabel; // gece mi gün mü takip ediyoruz
  const _CoachProfile({required this.id, required this.name, required this.tagline, required this.description, required this.icon, required this.steps, this.checkInLabel = 'Bu geceyi tamamladım'});
}

// ─── SORULAR ───────────────────────────────────────────────────────────────

const _questions = [
  _Question(
    key: 'parent_wellbeing',
    question: 'Bu hafta nasıl hissediyorsunuz?',
    subtitle: 'Dürüst cevabınız koç planını şekillendirir',
    choices: [
      _Choice(value: 'good',     label: 'İyi',            sublabel: 'Yorgun ama üstesinden geliyorum',  icon: Icons.sentiment_satisfied_rounded),
      _Choice(value: 'tired',    label: 'Çok yorgunum',   sublabel: 'Ama devam etmeye hazırım',         icon: Icons.sentiment_neutral_rounded),
      _Choice(value: 'struggle', label: 'Zorlanıyorum',   sublabel: 'Bu süreç beni çok etkiliyor',      icon: Icons.sentiment_dissatisfied_rounded),
      _Choice(value: 'crisis',   label: 'Baş edemiyorum', sublabel: 'Yardıma gerçekten ihtiyacım var',  icon: Icons.sentiment_very_dissatisfied_rounded),
    ],
  ),
  _Question(
    key: 'sleep_method',
    question: 'Bebeğiniz nasıl uykuya dalıyor?',
    subtitle: 'Şu an en çok işe yarayan yöntemi seçin',
    choices: [
      _Choice(value: 'nursing',     label: 'Emzirerken veya biberonla', sublabel: 'Emme sırasında gözleri kapanıyor', icon: Icons.baby_changing_station_rounded),
      _Choice(value: 'rocking',     label: 'Sallanarak',                sublabel: 'Kolda veya beşikte sallayarak',  icon: Icons.waves_rounded),
      _Choice(value: 'carrying',    label: 'Kucakta taşınarak',         sublabel: 'Yürürken veya hareketle',        icon: Icons.child_care_rounded),
      _Choice(value: 'independent', label: 'Büyük ölçüde kendi kendine',sublabel: 'Az müdahaleyle uyuyabiliyor',   icon: Icons.self_improvement_rounded),
    ],
  ),
  _Question(
    key: 'main_problem',
    question: 'En büyük zorluğunuz nedir?',
    subtitle: 'Sizi en çok zorlayan durumu seçin',
    choices: [
      _Choice(value: 'cant_sleep',    label: 'Uykuya dalamıyor',          sublabel: 'Yatırmak çok uzun sürüyor',      icon: Icons.bedtime_off_rounded),
      _Choice(value: 'night_wakings', label: 'Sık gece uyanmaları',       sublabel: 'Her uyanışta müdahale gerekiyor',icon: Icons.nightlight_rounded),
      _Choice(value: 'no_naps',       label: 'Gündüz uyumak istemiyor',   sublabel: 'Kısa veya hiç gündüz uykusu',   icon: Icons.wb_sunny_rounded),
      _Choice(value: 'early_rising',  label: 'Çok erken kalkıyor',        sublabel: 'Sabah 5–6\'da güne başlıyor',   icon: Icons.alarm_rounded),
    ],
  ),
  _Question(
    key: 'sleep_location',
    question: 'Bebek genellikle nerede uyuyor?',
    subtitle: 'En uzun uyuduğu yeri seçin',
    choices: [
      _Choice(value: 'crib',     label: 'Kendi beşiği veya yatağı', sublabel: 'Ayrı uyku yüzeyi',           icon: Icons.king_bed_rounded),
      _Choice(value: 'cosleep',  label: 'Anne-baba yatağı',         sublabel: 'Birlikte uyuma',              icon: Icons.people_rounded),
      _Choice(value: 'contact',  label: 'Kucakta veya taşıyıcıda', sublabel: 'Vücut temasıyla uyuyor',      icon: Icons.favorite_rounded),
      _Choice(value: 'stroller', label: 'Araba veya puset',         sublabel: 'Hareket veya titreşimle',     icon: Icons.drive_eta_rounded),
    ],
  ),
  _Question(
    key: 'night_wakings',
    question: 'Gece kaç kez uyanıyor?',
    subtitle: 'Son bir haftanın ortalamasını düşünün',
    choices: [
      _Choice(value: '0_1',   label: '0 – 1 kez',       sublabel: 'Neredeyse kesintisiz uyku',    icon: Icons.nightlight_round_rounded),
      _Choice(value: '2_3',   label: '2 – 3 kez',       sublabel: 'Yaygın ve yönetilebilir',      icon: Icons.battery_5_bar_rounded),
      _Choice(value: '4_5',   label: '4 – 5 kez',       sublabel: 'Yorucu ve düzensiz',           icon: Icons.battery_2_bar_rounded),
      _Choice(value: '5plus', label: '5\'ten fazla',    sublabel: 'Neredeyse her saat uyanıyor',  icon: Icons.battery_0_bar_rounded),
    ],
  ),
  _Question(
    key: 'tried_before',
    question: 'Şimdiye kadar ne denediniz?',
    subtitle: 'En çok başvurduğunuz yöntemi seçin',
    choices: [
      _Choice(value: 'nothing',       label: 'Henüz hiçbir şey',        sublabel: 'Nereden başlayacağımı bilmiyorum',icon: Icons.fiber_new_rounded),
      _Choice(value: 'swaddle_noise', label: 'Sarmalama & Beyaz gürültü',sublabel: 'Temel teknikleri bildim',        icon: Icons.layers_rounded),
      _Choice(value: 'routine',       label: 'Rutin oluşturmaya çalıştım',sublabel: 'Düzenli yatış saati gibi',     icon: Icons.schedule_rounded),
      _Choice(value: 'multiple',      label: 'Birçok şey denedim',       sublabel: 'Ama kalıcı sonuç alamadım',     icon: Icons.psychology_rounded),
    ],
  ),
];

// ─── PROFİLLER ─────────────────────────────────────────────────────────────

const _profileNursing = _CoachProfile(
  id: 'nursing_association',
  name: 'Emme ile Uyku Bağlantısı',
  tagline: 'Bebeğiniz uykuya geçmek için emmeye ihtiyaç duyuyor',
  description: 'Bu durum son derece yaygındır ve şefkatli, kademeli yöntemlerle çözülebilir. Bebeğiniz emmeyi bir uyku tetikleyicisi olarak öğrenmiş — amacımız bu bağlantıyı yavaşça gevşetmek. Süreç genellikle 4–6 hafta sürer ve hiçbir adımda bebeğinizi ağlayarak bırakmayı gerektirmez.',
  icon: Icons.baby_changing_station_rounded,
  steps: [
    _CoachStep(
      order: 1,
      title: 'Uyku Ortamını Hazırla',
      why: 'Herhangi bir davranış değişikliğine başlamadan önce uyku ortamı optimize edilmelidir. Karanlık melatonin üretimini destekler; beyaz gürültü dış uyarıcıları maskeleyerek uyku döngülerinin derinleşmesini sağlar. Bu iki koşul oluşturulduğunda sonraki adımların etkisi önemli ölçüde artar.',
      howTo: 'Uyku odasını gündüz de gece de tamamen karartın — el görünmeyecek kadar. Bir beyaz gürültü cihazı veya uygulama kullanarak beşikten 30 cm uzakta yaklaşık 60–65 dB ses seviyesi sağlayın. Beyaz gürültüyü bebek uyanana kadar kesintisiz çalışır bırakın. Bu düzenlemeleri bugün yapın ve programın tamamında sabit tutun.',
      expected: 'Pek çok bebek bu ortam değişikliğiyle birlikte ilk geceden itibaren daha uzun uyku döngüleri yaşar.',
      icon: Icons.dark_mode_rounded,
      requiredNights: 1,
      isPreparation: true,
    ),
    _CoachStep(
      order: 2,
      title: 'Beslenme–Uyku Sırasını Değiştir',
      why: 'Bebek her beslenmede uyursa, zamanla emme onun için uykuya geçişin zorunlu koşulu haline gelir. Bu örüntüyü kırmak için yatış rutininin sırasını değiştirmek yeterlidir — beslenmeyi rutinin başına, uyku yüzeyine yatırmayı sonuna taşıyoruz.',
      howTo: 'Yatış rutinini şöyle sıralayın: önce besleyin → sonra masaj veya ninni (10–15 dk) → ardından uyku kıyafeti ve karanlık oda → en son yatırın. Bebek beslenirken uyumaya başlarsa topuğunu hafifçe okşayarak ya da adını fısıldayarak uyanık tutun. İlk birkaç gece buna direniş normaldir.',
      expected: 'Genellikle 5–7 gün içinde bebek beslenme bitmeden uyumayı bırakmaya başlar.',
      icon: Icons.restaurant_rounded,
      requiredNights: 5,
    ),
    _CoachStep(
      order: 3,
      title: 'Erken Gece Beslemesi Ekle',
      why: 'Sonraki adıma geçmeden önce gece açlık uyanmalarını azaltmak gerekir. Ebeveyn uyumaya gitmeden önce verilen yarı uykulu besleme, gece ortası gerçek açlık uyanmalarını proaktif olarak önler. Bu sayede sonraki teknik yalnızca alışkanlıktan kaynaklanan uyanmalara odaklanabilir.',
      howTo: 'Her gece siz uyumaya gitmeden yaklaşık 30 dakika önce (genellikle 22:00–23:00 arası) bebeği uyandırmadan yarı uykulu halde besleyin. Işıkları açmayın, konuşmayın — sessizce besleyin ve geri yatırın. Bu, özellikle 4–6 aylık bebekler için çok etkilidir.',
      expected: 'Gece ortası açlık uyanmaları belirgin şekilde azalır, bu da sonraki adımı çok daha kolay hale getirir.',
      icon: Icons.bedtime_rounded,
      requiredNights: 7,
    ),
    _CoachStep(
      order: 4,
      title: 'Emme Çıkarma Tekniğine Başla',
      why: 'Ortam hazır, rutinin sırası değişti, açlık uyanmaları azaldı — artık emme alışkanlığının üzerine doğrudan çalışmanın zamanı. Bu teknik bebeğe emme olmadan da uykuya geçebileceğini adım adım öğretir.',
      howTo: 'Bebek emmeye devam ederken gözleri kapanmak üzereyken (tam uykuya dalmadan hemen önce), parmağınızı ağzının köşesine hafifçe yerleştirerek emişi nazikçe kesin. Hemen bırakmayın; sıkıca kucaklayın, yavaşça şşşt deyin. Tekrar emmeye çalışırsa izin verin, birkaç dakika sonra tekrarlayın. Her besleme ve gece uyanmasında aynı şekilde uygulayın.',
      expected: 'İlk 1–2 hafta az fark görülmesi normaldir. Sürekli uygulandığında 4–8 hafta içinde belirgin ve kalıcı değişim yaşanır.',
      icon: Icons.self_improvement_rounded,
      requiredNights: 7,
    ),
    _CoachStep(
      order: 5,
      title: 'Gece Beslemelerini Değerlendir',
      why: 'Teknik uygulandıkça alışkanlık uyanmaları azalır. Bu noktada kalan uyanmaların gerçek açlıktan mı yoksa alışkanlıktan mı kaynaklandığını ayırt etmek önemlidir.',
      howTo: '6 aydan küçük bebekler için her uyanışta besleyin — gerçek açlık ihtiyaçları devam edebilir. 6 ay ve üzeri için her uyanışta hemen beslemeye koşmak yerine 3–5 dakika bekleyin. Ağlama şiddetleniyorsa besleyin; sızlanıp bekliyorsa şşşt ve sırt sıvazlamayla sakinleştirmeyi deneyin. Her gece kaç kez besleme gerektiğini not edin.',
      expected: 'Gerçek açlık ile alışkanlık uyanmaları ayrışır; toplam besleme sayısı kademeli olarak azalmaya başlar.',
      icon: Icons.nightlight_rounded,
      requiredNights: 4,
    ),
    _CoachStep(
      order: 6,
      title: 'İlerlemeyi Pekiştir',
      why: 'Her gece uyanma sayısının azalması ve emme olmadan uykuya geçiş, bebeğin öz düzenleme becerisinin geliştiğini gösterir. Bu süreç biyolojik olarak kalıcı sonuç verir — sabır en büyük desteğinizdir.',
      howTo: 'Bu hafta uyanma sayınızı program başındakiyle karşılaştırın. İyi giden geceleri not edin. Hâlâ zorlanıyorsanız 4. adıma dönerek tekniğe devam edin — süreç bireysel olarak 4–10 hafta sürebilir ve bu tamamen normaldir.',
      expected: 'Çoğu bebekte 6–8 hafta içinde belirgin ve kalıcı iyileşme. Süreci hızlandırmaya çalışmayın — her bebek kendi hızında ilerler.',
      icon: Icons.celebration_rounded,
      requiredNights: 4,
    ),
  ],
);

const _profileMotion = _CoachProfile(
  id: 'motion_dependency',
  name: 'Hareket ile Uyku Bağlantısı',
  tagline: 'Bebeğiniz uykuya dalmak için harekete ihtiyaç duyuyor',
  description: 'Sallama ve taşıma, bebekler için güçlü sakinleştirici uyaranlardır. Ancak her uyku için bu harekete ihtiyaç duyulduğunda gece uyku döngüleri arasında aynı uyaran gerekir. Kademeli azaltma yöntemiyle bu bağlantıyı yavaşça gevşetip bebeğe beşiğin de güvenli bir yer olduğunu öğreteceğiz. Süreç genellikle 4–6 hafta sürer.',
  icon: Icons.waves_rounded,
  steps: [
    _CoachStep(
      order: 1,
      title: 'Uyku Ortamını Hazırla',
      why: 'Herhangi bir davranış değişikliğine başlamadan önce uyku ortamı optimize edilmelidir. Beyaz gürültü ve tam karanlık, hareket uyaranının yokluğunu telafi eden bağımsız sakinleşme koşulları oluşturur. Bu adım atlanırsa diğer adımların etkisi önemli ölçüde azalır.',
      howTo: 'Uyku odasını tamamen karartın. Beyaz gürültüyü beşikten 30 cm uzağa, 60–65 dB seviyesinde ayarlayın — bebek uyanana kadar kesintisiz çalışsın. Oda sıcaklığını 16–20°C\'de tutun. Bu koşulları bugün kurun ve programın tamamında sabit tutun.',
      expected: 'Ortam değişikliği tek başına uyku döngülerini uzatabilir. Sonraki adımların temeli bu adımla atılır.',
      icon: Icons.speaker_rounded,
      requiredNights: 1,
      isPreparation: true,
    ),
    _CoachStep(
      order: 2,
      title: 'Yatış Rutini Oluştur',
      why: 'Hareketi azaltmaya başlamadan önce bebeğin sinir sisteminin "uyku geliyor" sinyali alması gerekir. Tutarlı bir rutin zamanla bu sinyali koşullar; rutin başlar başlamaz uyku tepkisi tetiklenmeye başlar. Bu koşullanma gerçekleşmeden uygulanan hareket azaltma çok daha zor ve uzun sürer.',
      howTo: 'Her gece tam olarak aynı sırada yaklaşık 20 dakikalık bir rutin oluşturun: yüz yıkama veya kısa banyo → beden masajı → uyku kıyafeti ve uyku tulumu → ninni → karanlık oda ve beyaz gürültü. Sırayı ve süreyi değiştirmeyin. Hafta sonları dahil her gece aynı rutini uygulayın.',
      expected: '7–14 gün içinde rutin başladığında bebek kendiliğinden sakinleşmeye başlar. Bu birikim önemlidir, ara vermeyin.',
      icon: Icons.playlist_play_rounded,
      requiredNights: 7,
    ),
    _CoachStep(
      order: 3,
      title: 'Hareketi Kademeli Azalt',
      why: 'Rutin yerleştikten sonra hareket uyaranını yavaşça azaltmaya başlayabilirsiniz. Ani bırakmak yerine kademeli azaltmak bebeğin sinir sistemine "bu ortam güvenli" mesajı verir ve direnişi önemli ölçüde azaltır.',
      howTo: '7 günlük plan: 1–2. gece hızlı sallama → 3–4. gece yavaş sallama → 5–6. gece çok hafif sallanma → 7. gece yerinde durarak kucakta tutma (hareket yok). Bebek bir aşamaya yoğun direnç gösterirse o aşamada 1–2 gece daha kalın, acele etmeyin.',
      expected: '7–10 günde hareket ihtiyacının yoğunluğu belirgin şekilde azalır. Bebek daha az hareketle sakinleşmeye başlar.',
      icon: Icons.slow_motion_video_rounded,
      requiredNights: 7,
    ),
    _CoachStep(
      order: 4,
      title: 'Kucakla Destekli Geçiş',
      why: 'Önceki adımlarla hareket ihtiyacı azalmış olan bebeğe artık beşiğin güvenli bir yer olduğunu öğretmenin zamanı. Bu teknik kucak ve beşik arasında gidip gelerek bebeğe "hem seni destekliyorum hem de beşiğin güvenli" mesajını verir. 3–8 aylık bebeklerde en etkilidir.',
      howTo: 'Rutin bittiğinde bebeği uykulu ama tam uyanık değilken beşiğe yatırın. Ağlarsa kucağa alın — tamamen uyumadan, sadece sakinleşir sakinleşmez tekrar yatırın. İlk gecelerde 10–20 kez tekrarlanabilir; bu normaldir ve her gece sayı azalır. Sabırlı olun — bu en öğretici aşamadır.',
      expected: '3–5 gece sonra beşiğe geçiş sayısı belirgin azalır. 1–2 haftada minimum müdahaleyle uyku başlar.',
      icon: Icons.child_friendly_rounded,
      requiredNights: 7,
    ),
    _CoachStep(
      order: 5,
      title: 'Beşikte Bağımsız Uyku',
      why: 'Önceki adımlar tamamlandığında bebek beşiği güvenli ve tanıdık bir yer olarak benimsemiş olur. Son adım bu bağlantıyı kalıcı hale getirmektir — bebeğin uykuya tam dalmadan bırakılması, kendi kendine geçiş becerisini pekiştirir.',
      howTo: 'Rutin bittiğinde bebeği gözler ağırlaşmışken ama henüz tam uyumamışken yatırın. Yanında 1–2 dakika kalın, sonra odadan ayrılın. Ağlarsa kucak–beşik tekniğini uygulayın. Her gece biraz daha az müdahale gerekir.',
      expected: 'Kalıcı bağımsız uyku becerisinin yerleşmesi. Toplam program süresi 4–6 haftadır.',
      icon: Icons.king_bed_rounded,
      requiredNights: 5,
    ),
  ],
);

const _profileEnvironment = _CoachProfile(
  id: 'environment_setup',
  name: 'Uyku Ortamı Geliştirme',
  tagline: 'Bebeğiniz en iyi uyku ortamına henüz kavuşmamış',
  description: 'Araç, puset veya kucak bebeğin "uyku yeri" olarak öğrendiklerinin bir parçasıdır. Doğru çevre koşulları oluşturulduğunda davranış değişiklikleri çok daha hızlı ve kolay gerçekleşir. Bu program ortamı adım adım inşa eder; çevre değişiklikleri genellikle davranış tekniklerinden daha hızlı etki eder.',
  icon: Icons.home_rounded,
  steps: [
    _CoachStep(
      order: 1,
      title: 'Beyaz Gürültü Sistemini Kur',
      why: 'Bebekler gürültüsüz ortamı tuhaf bulur; rahim içindeki ses seviyesi oldukça yüksektir. Beyaz gürültü hem sakinleştirici etki yaratır hem de dış sesleri maskeleyerek uyku döngülerinin bölünmesini önler. Araştırmalar beyaz gürültünün bebekler için uykuya dalma süresini kısalttığını göstermektedir.',
      howTo: 'Bir beyaz gürültü cihazı veya uygulama edinin. Beşikten yaklaşık 30 cm uzakta, 60–65 dB ses seviyesinde ayarlayın. Bebek uyanana kadar kesintisiz çalışır bırakın — yalnızca uyku başında değil, tüm gece. Bu ayarı bir kez yapın ve programın tamamında sabit tutun.',
      expected: 'Çoğu bebekte ilk geceden itibaren uyku kalitesinde iyileşme görülür. Bu adım diğer tüm adımların temelini oluşturur.',
      icon: Icons.speaker_rounded,
      requiredNights: 1,
      isPreparation: true,
    ),
    _CoachStep(
      order: 2,
      title: 'Tam Karartma Sağla',
      why: 'Işık, vücudun biyolojik saatini düzenleyen hormonları doğrudan etkiler. Gündüz ışığı, özellikle mavi ışık, uyku hormonunun salgılanmasını geciktirir ve uyku döngülerini sekteye uğratır. Tam karartma, bebeğin beynine güçlü bir "uyku vakti" sinyali gönderir.',
      howTo: 'Odaya girin, kapıyı kapatın ve tüm perdeleri çekin. Elinizi yüzünüzün önünde görebiliyor musunuz? Görebiliyorsanız karartma perdesi veya folyoyla odayı tamamen karartın. Gece lambaları dahil tüm ışık kaynaklarını kapatın. Bu düzenleme hem gündüz hem gece uykularda kalıcı olarak kullanılacak.',
      expected: 'Gündüz uyku süreleri uzar, gece uykuya dalma süresi kısalır.',
      icon: Icons.dark_mode_rounded,
      requiredNights: 1,
      isPreparation: true,
    ),
    _CoachStep(
      order: 3,
      title: 'Uyku Tulumu veya Sarmalama',
      why: 'Kucak veya taşıyıcıda uyumaya alışmış bebekler için uyku tulumu ya da sarmalama, vücut sıcaklığını ve sarılmışlık hissini taklit ederek beşiğe geçişi kolaylaştırır. Aynı zamanda Moro refleksinden (irkilme refleksi) kaynaklanan ani uyanmaları azaltır.',
      howTo: '0–3 aylık bebekler için kolları içine alacak şekilde klasik sarmalama uygulayın. 3+ aylık bebekler için kollar serbest, torba tipi uyku tulumu kullanın. Uyku tulumu veya sarmayı yatış rutininin sabit bir parçası haline getirin — giydirme anını ninniyle birleştirin. Her uykuda tutarlı biçimde kullanın.',
      expected: 'Hareket veya vücut teması ihtiyacı kademeli olarak azalmaya başlar.',
      icon: Icons.airline_seat_flat_rounded,
      requiredNights: 1,
      isPreparation: true,
    ),
    _CoachStep(
      order: 4,
      title: 'Beşiği Tanıdık Hale Getir',
      why: 'Bebeğin beşiği güvenli ve tanıdık bir yer olarak benimsemesi gerekir. Gündüz uyanıkken yapılan olumlu deneyimler, gece beşiğe yatırılmaya direnci önemli ölçüde azaltır. Beyin tekrar eden güvenli deneyimlerden öğrenir.',
      howTo: 'Bebeği gündüz uyanıkken de beşiğe koyun: yanında oturun, oyuncak sallayın, şarkı söyleyin. Beşiğin içine sizin kokunuzu taşıyan ince bir kıyafet bırakın. Her gün en az birkaç kez bu olumlu beşik deneyimini tekrarlayın.',
      expected: '5–7 günde beşiğe koymaya direniş belirgin şekilde azalır.',
      icon: Icons.king_bed_rounded,
      requiredNights: 5,
    ),
    _CoachStep(
      order: 5,
      title: 'Gündüz Uykusunu Beşikte Başlat',
      why: 'Beşiği artık tanıyan bebek için gündüz bir uykuyu beşikte yapmak gece geçişinden çok daha kolay kabul görür. Gece yatışından önce gündüz pratiği yapmak tüm geçiş sürecini hızlandırır.',
      howTo: 'Sabah ilk gündüz uykusunu beşikte deneyin. Önce kucakta uyutun, derin uyku aşamasına geçince (kollar sarkmış, nefes düzenli ve yavaş, ağız hafif açık) nazikçe beşiğe yerleştirin. Başarırsanız bir sonraki uykuda biraz daha erken — yarı uykuludayken — bırakmayı deneyin.',
      expected: 'Gündüz beşik kabulü 3–7 günde gerçekleşir ve gece geçişini doğrudan kolaylaştırır.',
      icon: Icons.wb_sunny_rounded,
      requiredNights: 5,
    ),
    _CoachStep(
      order: 6,
      title: 'Tutarlı Uyku Yeri',
      why: 'Bebek beyni tekrarlayan örüntülerden öğrenir. Aynı yer, aynı rutin ve aynı çevre sinyalleri bu tutarlılığı nörolojik olarak pekiştirir ve uyku becerisini kalıcı hale getirir.',
      howTo: 'Artık tüm uykularda — gündüz ve gece — beşiği birincil yer olarak kullanın. İstisna ne kadar az olursa bağlantı o kadar güçlenir. Yolculuk gibi zorunlu istisnalar olabilir, endişelenmeyin; eve dönünce rutin kaldığı yerden devam eder.',
      expected: 'Kalıcı ve tahmin edilebilir uyku düzeni oluşur. Toplam program süresi 3–5 haftadır.',
      icon: Icons.check_circle_rounded,
      requiredNights: 5,
    ),
  ],
);

const _profileWakings = _CoachProfile(
  id: 'frequent_wakings',
  name: 'Gece Uyanma Döngüsü',
  tagline: 'Bebeğiniz uyku döngüleri arasında kendi kendine geçiş yapamıyor',
  description: 'Sık gece uyanmaları çoğunlukla uyku çağrışımından kaynaklanır — bebek uykuya dalarken hangi koşul varsa gece her uyku döngüsü arasında aynı koşula ihtiyaç duyar. Hangi çağrışımın devrede olduğunu tespit edip adım adım, şefkatle çözeceğiz. Süreç genellikle 4–6 hafta sürer.',
  icon: Icons.nightlight_rounded,
  steps: [
    _CoachStep(
      order: 1,
      title: 'Uyku Ortamını Güçlendir',
      why: 'Her şeyden önce ortam hazır olmalıdır. Beyaz gürültü ve tam karanlık, gece uyanmalarını gözlemlerken ve müdahale uygularken tüm adımların zeminini oluşturur. Ortam eksikken yapılan gözlem yanıltıcı, uygulanan teknik ise daha az etkili olur.',
      howTo: 'Beyaz gürültüyü beşikten 30 cm uzağa, 60–65 dB seviyesinde ayarlayın — bebek uyanana kadar kesintisiz çalışsın. Odayı tamamen karartın. Bu iki koşulu bugün kurun ve programın tamamında sabit tutun.',
      expected: 'Ortam değişikliği tek başına uyanma sayısını azaltabilir. Sonraki tüm adımların etkisini de doğrudan artırır.',
      icon: Icons.speaker_rounded,
      requiredNights: 1,
      isPreparation: true,
    ),
    _CoachStep(
      order: 2,
      title: 'Uyku Çağrışımını Belirle',
      why: 'Ortam hazırken yapılan gözlem çok daha güvenilirdir. Bebeğin uykuya dalarken hangi uyarana ihtiyaç duyduğunu ve gece uyanmalarının örüntüsünü anlamak, etkili bir plan oluşturmanın temelini oluşturur. Doğru tespiti olmadan uygulanan müdahale genellikle işe yaramaz.',
      howTo: '3 gece boyunca kayıt tutun: bebek nasıl uyudu? (kucak, emzirme, sallama, kendi kendine) Gece her uyanışta ne oldu? (ağladı, sızlandı, bağırdı) Ne yapınca sakinleşti? Her sabah bu notları gözden geçirip tekrar eden örüntüyü belirleyin.',
      expected: 'Birincil uyku çağrışımı netleşir, hedefli bir müdahale planı oluşturulabilir.',
      icon: Icons.search_rounded,
      requiredNights: 3,
    ),
    _CoachStep(
      order: 3,
      title: 'Uyku Penceresini Optimize Et',
      why: 'Çağrışım belirlendikten sonra zamanlamayı doğru ayarlamak şarttır. Çok yorgun uyutulan bebekler kortizol yükselmesi nedeniyle daha sık ve kısa uyku döngülerine girer; çok erken yatırılanlar ise yeterince derin uyku elde edemez. Her iki durum da gece uyanmalarını artırır.',
      howTo: 'Yaşa göre uyanıklık pencerelerini esas alın: 0–3 ay → 45–90 dk, 4–6 ay → 1,5–2 saat, 6–12 ay → 2–3 saat. Uyku işaretlerini izleyin: göz ovma, bakışın bulanıklaşması, kulak çekme, ani huzursuzluk. İlk işarette rutini başlatın — pencere hızla kapanır.',
      expected: 'Doğru zamanlama yakalandığında uykuya dalma süresi kısalır ve gece uyanma sayısı azalır.',
      icon: Icons.timer_rounded,
      requiredNights: 4,
    ),
    _CoachStep(
      order: 4,
      title: 'Gece Beslemelerini Kademeli Azalt',
      why: 'Alışkanlık müdahalelerine geçmeden önce gerçek açlık uyanmalarını gerçek ihtiyaca indirmek önemlidir. Aksi takdirde bir gece uyanmasına müdahale etmemek gerçek açlığı görmezden gelmek anlamına gelebilir.',
      howTo: '6 ay altı bebekler için bu adımı atlayın. 6 ay ve üzeri için: her beslemede süreyi 2 dakika kısaltın. Her 4–5 günde bir beslemeyi, sondan başa doğru, çıkarın. Emzirme veya biberonu 3–4 dakikanın altında bitiriyorsa bebek alışkanlıktan besleniyordur.',
      expected: '2–3 haftada gece beslemeleri gerçek açlık ihtiyacına indirgenir.',
      icon: Icons.nights_stay_rounded,
      requiredNights: 4,
    ),
    _CoachStep(
      order: 5,
      title: 'Gece Yanıtını Tutarlılaştır',
      why: 'Tutarsız gece yanıtı bebeği kafa karıştırır ve öğrenmeyi yavaşlatır. Her uyanışta farklı bir tepki verildiğinde bebek hangi davranışının hangi sonucu getireceğini öğrenemez. Tutarlı bir yanıt, değişimi önemli ölçüde hızlandırır.',
      howTo: 'En az 7 gece boyunca her uyanışta aynı yanıtı uygulayın: yanına gidin → şşşt + sırt sıvazlama → kısa süre kalıp çıkın. 7 geceden önce yöntemi değiştirmeyin — beyni yeni örüntüyü öğrenmek için zamana ihtiyaç duyar.',
      expected: 'Uyanma sayısı ve süresi kademeli azalır. Değişim genellikle 4–5. geceden sonra belirginleşmeye başlar.',
      icon: Icons.rule_rounded,
      requiredNights: 7,
    ),
    _CoachStep(
      order: 6,
      title: 'Sabır Penceresi ile Pekiştir',
      why: 'Bebekler uyku döngüleri arasında hafifçe uyanır — bu normaldir. Bu anlarda ebeveyn hemen müdahale ettiğinde bebek kendi kendine geçiş yapma fırsatı bulamaz. Bekleme, bu becerinin gelişmesini destekler.',
      howTo: 'Gece uyanmalarda hemen koşmayın, 3–5 dakika bekleyin. Sızlanıp devam ediyorsa gözlemleyin. Ağlama şiddetleniyorsa gidin ve tutarlı yanıtı uygulayın. Amaç ağlamayı görmezden gelmek değil, bebeğe kendi kendine geçiş için alan açmaktır.',
      expected: 'Uyanmaların giderek artan kısmı kendiliklerinden çözülür. Kalıcı gece uykusu iyileşmesi gerçekleşir. Toplam program süresi 5–7 haftadır.',
      icon: Icons.celebration_rounded,
      requiredNights: 5,
    ),
  ],
);

const _profileSleepOnset = _CoachProfile(
  id: 'sleep_initiation',
  name: 'Uyku Başlatma Desteği',
  tagline: 'Bebeğiniz uykuya geçişte zorlanıyor',
  description: 'Uykuya dalmak, bebekler için doğuştan gelen değil, zamanla geliştirilen bir beceridir. Doğru ortam, doğru zamanlama ve tutarlı bir rutin bu becerinin en etkili öğretim yollarıdır. Çoğu bebekte 3–5 hafta içinde belirgin iyileşme görülür. Hiçbir adım bebeğinizi ağlayarak bırakmayı gerektirmez.',
  icon: Icons.bedtime_rounded,
  steps: [
    _CoachStep(
      order: 1,
      title: 'Uyku Ortamını Hazırla',
      why: 'Gözlem ve teknikler en iyi koşullarda uygulandığında anlamlı veri verir. Ortam hazır değilken yapılan gözlem yanıltıcı olabilir — bebeğin uyku işaretlerini doğru zamanda görmek için ışık, ses ve sıcaklığın kontrol altında olması gerekir.',
      howTo: 'Bugün yapılacaklar: odayı tamamen karartın (el görünmeyecek kadar), beyaz gürültüyü beşikten 30 cm uzağa 60–65 dB ayarlayın, oda sıcaklığını 16–20°C tutun. Yatıştan 30 dakika önce ekran ve parlak ışığa son verin. Bu koşulları bir kez kurun ve programın tamamında sabit tutun.',
      expected: 'Ortam değişikliği ilk geceden etki edebilir. Uykuya dalma süresi kısalır.',
      icon: Icons.dark_mode_rounded,
      requiredNights: 1,
      isPreparation: true,
    ),
    _CoachStep(
      order: 2,
      title: 'Uyku Penceresini Bul',
      why: 'Ortam hazırken yapılan gözlem güvenilirdir. Uyku penceresi kaçırılırsa kortizol devreye girer ve uyutmak çok zorlaşır; doğru zamanlama teknikten önce gelir — en iyi yöntem bile yanlış zamanda uygulanırsa işe yaramaz.',
      howTo: 'Bebeği 3 gün boyunca gözlemleyin. Son uykudan kaç dakika sonra ilk uyku işareti çıkıyor? Yaşa göre uyanıklık pencereleri: 0–3 ay → 45–90 dk, 4–6 ay → 1,5–2 saat, 6–12 ay → 2–3 saat. Uyku işaretleri: göz ovma, bakış bulanıklığı, kulak çekme, sese tepkisizlik, ani huzursuzluk. İlk işarette rutini başlatın.',
      expected: 'Doğru pencerede uyutmak, uzun yatış seanslarını ve aşırı ağlamayı dramatik biçimde azaltabilir.',
      icon: Icons.timer_rounded,
      requiredNights: 3,
    ),
    _CoachStep(
      order: 3,
      title: 'Tutarlı Yatış Rutini Başlat',
      why: 'Tutarlı bir rutin, beyinde koşullanmış bir uyku beklentisi oluşturur. Beyin tekrara dayalı öğrenir: rutin başlayınca uyku tepkisi tetiklenmeye başlar. Bu koşullanmanın yerleşmesi için 7–14 gün gerekir; bu süreyi atlatmak programın en kritik parçasıdır.',
      howTo: '20 dakikalık sabit bir rutin tasarlayın: banyo veya yüz yıkama (5 dk) → beden masajı (5 dk) → uyku kıyafeti ve uyku tulumu → emzirme veya biberon → ninni → karanlık ve beyaz gürültü. Sırayı ve süreyi değiştirmeyin. Hafta sonları dahil her gece aynı rutini uygulayın.',
      expected: '7–14 gün içinde rutin başladığı anda bebek sakinleşmeye başlar. Bu birikim önemlidir — ara vermeyin.',
      icon: Icons.playlist_play_rounded,
      requiredNights: 7,
    ),
    _CoachStep(
      order: 4,
      title: '5 Adımlı Sakinleştirme Yöntemi',
      why: 'Bu 5 adımlı yöntem rahim ortamını taklit ederek bebeğin sakinleşme refleksini tetikler. Adımlar ayrı ayrı değil, aynı anda uygulandığında çok daha güçlüdür. 0–4 aylık bebeklerde en etkili tekniklerden biridir.',
      howTo: 'Aynı anda uygulayın: (1) Sarmalama — kolları içine alarak sıkı sar. (2) Yan tutma — kucağınızda yan çevirin (asla beşikte yan veya yüzükoyun bırakmayın). (3) Şşşt sesi — bebeğin ağlaması kadar yüksek sesle sürekli yapın. (4) Hafif sallama — başını destekleyerek, küçük ve hızlı hareketlerle. (5) Emzik veya parmak emme. Sakinleşince yavaşça azaltın.',
      expected: 'Çoğu bebekte 1–3 dakika içinde sakinleşme sağlanır.',
      icon: Icons.waves_rounded,
      requiredNights: 4,
    ),
    _CoachStep(
      order: 5,
      title: 'Uykuya Yatır, Uyutma',
      why: 'Bebek uyku yüzeyini tanır ve gece uyku döngüsü geçişlerinde panik yapmaz. Bu bağımsız uyku becerisinin temel taşıdır ve en zor ama en kalıcı adımdır. Sabır ve tutarlılık her şeyden önemlidir.',
      howTo: 'Rutin bittiğinde ve bebek uykuya dalmak üzereyken (gözler ağır, vücut gevşek ama hâlâ açık) yatağına koyun. Tam uykuya dalmadan bırakın. Ağlarsa kucağa alın, sadece sakinleşince — tam uyumadan — tekrar deneyin. İlk hafta çok zorlayıcı olabilir, bu normaldir. Her gece biraz daha iyileşir.',
      expected: 'Bağımsız uyku becerisi 7–14 günde yerleşir. Süreç bireysel değişir — kendinizi başkalarıyla kıyaslamayın.',
      icon: Icons.king_bed_rounded,
      requiredNights: 7,
    ),
  ],
);

const _profileNaps = _CoachProfile(
  id: 'nap_difficulties',
  name: 'Gündüz Uykusu Düzeni',
  tagline: 'Bebeğiniz gündüz uykularında zorlanıyor',
  description: 'Gündüz uyku kalitesi gece uykusunu doğrudan etkiler; yetersiz gündüz uykusu "aşırı yorgunluk döngüsü" yaratarak gece uykusunu da bozar. Bu program gündüz uyku düzenini adım adım yerleştirmeyi hedefler. Gündüz uykuları düzelince gece uykusu da sıklıkla kendiliğinden iyileşir.',
  icon: Icons.wb_sunny_rounded,
  checkInLabel: 'Bu gün uyguladım',
  steps: [
    _CoachStep(
      order: 1,
      title: 'Gündüz Uyku Ortamını Hazırla',
      why: 'Pek çok ebeveyn gece karartma yapar ama gündüz yapmaz — bu büyük fark yaratır. Gündüz ışığı melatonin üretimini baskılar; beyin "uyku vakti değil" sinyali alır ve uyku döngüleri kısalır. Gözlem ve sonraki adımlar ancak ortam doğruyken anlamlı sonuç verir.',
      howTo: 'Gündüz uyku odası da gece kadar karanlık olsun — el görünmeyecek düzeyde. Beyaz gürültüyü gündüz uykularda da tüm uyku boyunca kullanın. Oda sıcaklığı 16–20°C. Telefon bildirimleri sessiz, dış sesler azaltılmış. Bu düzenlemeleri bir kez yapın ve her gündüz uykusunda sabit tutun.',
      expected: 'Gündüz uyku süresi uzar. Özellikle 45 dakika engeli aşılmaya başlar.',
      icon: Icons.dark_mode_rounded,
      requiredNights: 1,
      isPreparation: true,
    ),
    _CoachStep(
      order: 2,
      title: 'Yaşa Uygun Uyku Sayısını Belirle',
      why: 'Kaç uyku olacağını bilmeden pencere hesabı yapmak anlamsızdır — 2 uykulu günle 3 uykulu günün zamanlaması tamamen farklıdır. Doğru sayıyı bilmek, sonraki gözlemi ve mini rutini doğrudan şekillendirir.',
      howTo: '0–3 ay: 4–5 gündüz uykusu (henüz düzenli ritim beklenmez). 3–6 ay: 3 uyku. 6–9 ay: 2–3 uyku. 9–15 ay: 2 uyku. 15–18 ay: 2\'den 1\'e geçiş dönemi (bazen 1, bazen 2 olabilir). 18 ay+: 1 uyku. Bebeğiniz gündüzü reddediyorsa ama 15+ aylıksa geçiş döneminde olabilir — bu normaldir.',
      expected: 'Doğru uyku sayısıyla hem gündüz hem gece uykusu daha tutarlı hale gelir.',
      icon: Icons.format_list_numbered_rounded,
      requiredNights: 1,
      isPreparation: true,
    ),
    _CoachStep(
      order: 3,
      title: 'Yaşa Uygun Uyku Pencerelerini Bul',
      why: 'Ortam ve uyku sayısı netleştikten sonra zamanlamayı bulmak çok daha kolaydır. Çok yorgunken konulan bebek kortizol yükselmesiyle aşırı uyarılmış olur; çok erken konulan bebek uyumayı reddeder. Her iki durum da gündüz uykusunu zorlaştırır.',
      howTo: 'Bugünden itibaren 3 gün boyunca: (1) Bebeğin uyandığı saati not edin. (2) Yaşa göre bekleme süresini hesaplayın: 0–3 ay → 45–60 dk, 3–6 ay → 1,5–2 saat, 6–9 ay → 2–3 saat, 9–18 ay → 3–4 saat. (3) Süre dolunca uyku işaretlerini aktif izleyin: göz ovma, bakış bulanıklaşması, kulak çekme, ani huzursuzluk. (4) İlk işarette perdeleri kapatın, beyaz gürültüyü açın ve yatırın — pencere çabuk kapanır.',
      expected: 'Doğru pencerede yatırılan bebek çok daha kolay uyur, direniş belirgin azalır.',
      icon: Icons.timer_rounded,
      requiredNights: 3,
    ),
    _CoachStep(
      order: 4,
      title: 'Gündüz Mini Rutini Oluştur',
      why: 'Uyku sayısı netleştikten sonra, her uykudan önce beyne "uyku geliyor" sinyali vermek gerekir. Mini rutin bu sinyali güçlendirir. Rutinsiz kısa uyku uzatmaya çalışmak çok daha az etkilidir.',
      howTo: 'Her gündüz uykusu öncesinde 5–10 dakikalık mini rutin: perdeleri kapat → beyaz gürültüyü aç → uyku tulumu giy → kısa ninni veya şarkı → yatır. Her seferinde aynı sıra. Gündüz mini rutini gece rutininin sade bir kopyası olsun.',
      expected: '7–14 gün içinde mini rutin başlayınca bebek kendiliğinden sakinleşmeye başlar.',
      icon: Icons.playlist_play_rounded,
      requiredNights: 5,
    ),
    _CoachStep(
      order: 5,
      title: 'Kısa Uyku Sorununa Müdahale',
      why: 'Bebekler yaklaşık 45 dakikalık uyku döngüsü yaşar ve döngüler arasında hafifçe uyanır. Bu uyanmadan kendi kendine geçiş yapma becerisi zamanla gelişir; ancak ortam ve rutin hazır olduğunda bu süreç çok daha hızlı ilerler.',
      howTo: 'Bebek 40–45 dakikada uyanırsa hemen koşmayın, 5 dakika bekleyin — kendiliğinden tekrar uyuyabilir. Uyuyamazsa şşşt ve sırt sıvazlamayla beşikte destekleyin. Beşikten çıkarmayın — en az 10–15 dakika daha kalmasına fırsat verin. Her deneme öğretir.',
      expected: '5–7 gün içinde kısa uykuluarın bir kısmı kendiliğinden uzamaya başlar.',
      icon: Icons.hourglass_top_rounded,
      requiredNights: 5,
    ),
    _CoachStep(
      order: 6,
      title: 'Gündüz–Gece Dengesini Kur',
      why: 'Gündüz çok az uyku gece aşırı yorgunluğa; çok fazla uyku ise gece geç yatışa ve sık uyanmalara yol açar. Gündüz ve gece uyku sistemleri birbirini doğrudan etkiler; ikisi birlikte ele alınmalıdır.',
      howTo: 'Son gündüz uykusunun bitişiyle gece yatış arasında en az 2–3 saat olsun. Son gündüz uykusu çok geç bitiyorsa gece yatış saatini de geç alırsınız. Gece yatış saati tutarsızsa sabah kalkış saatini sabitleyin — bu değişiklik tüm biyolojik ritmi kısa sürede düzenler.',
      expected: 'Gündüz ve gece uykusu birbirini desteklemeye başlar, toplam uyku ihtiyacı karşılanır. Toplam program süresi 3–5 haftadır.',
      icon: Icons.balance_rounded,
      requiredNights: 4,
    ),
  ],
);

// ─── PROFİL ATAMA ──────────────────────────────────────────────────────────

_CoachProfile _assignProfile(Map<String, String> answers) {
  // Ebeveyn krizi durumunda en hafif profili ver
  if (answers['parent_wellbeing'] == 'crisis') return _profileEnvironment;

  final method   = answers['sleep_method']  ?? '';
  final wakings  = answers['night_wakings'] ?? '';
  final location = answers['sleep_location'] ?? '';
  final problem  = answers['main_problem']  ?? '';

  // 5+ uyanma her durumda en acil sorun — önce ele al
  if (wakings == '5plus') return _profileWakings;

  // Gündüz uykusu sorunu — bağımsız profil gerektirir
  if (problem == 'no_naps') return _profileNaps;

  // Uyku yöntemi en güvenilir sinyal
  if (method == 'nursing') return _profileNursing;
  if (method == 'rocking' || method == 'carrying') return _profileMotion;

  // Uyku yeri bağımlılığı
  if (location == 'stroller' || location == 'contact') return _profileEnvironment;

  // Kullanıcının bildirdiği ana sorun da dikkate alın
  if (problem == 'night_wakings') return _profileWakings;

  // Çok erken kalkma → sabah ışığı/sesi ortam sorunudur
  if (problem == 'early_rising') return _profileEnvironment;

  // Varsayılan: uykuya başlatma desteği
  return _profileSleepOnset;
}

// ─── ANA EKRAN ─────────────────────────────────────────────────────────────

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  static const _kAnswers    = 'coach_answers_v2';
  static const _kProfile    = 'coach_profile_id_v2';
  static const _kStarted    = 'coach_program_started_v2';
  static const _kCompleted  = 'coach_completed_steps_v2';
  static const _kNights     = 'coach_night_checkins_v2';
  static const _kSkipped    = 'coach_skipped_nights_v2';

  bool _isLoading    = true;
  bool _isAnalyzing  = false;
  String _babyName   = 'Bebeğiniz';

  // Güvenlik katmanı state
  bool _redFlagChecked = false;
  bool _hasRedFlag     = false;
  int  _babyAgeMonths  = 99;

  // Red flag checkbox state
  final List<bool> _redFlagValues = List.filled(6, false);

  // Onboarding state
  int _questionIndex = 0;
  final Map<String, String> _answers = {};
  String? _selectedChoice;

  // Program state
  _CoachProfile? _profile;
  bool _programStarted = false;
  List<int> _completedSteps = [];
  Map<int, List<String>> _nightCheckins = {};
  Map<int, List<String>> _skippedNights = {};
  int _viewingStepOrder = 1; // hangi adım kartı gösteriliyor

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // Önce lokal BabyService'e bak, yoksa API'ye fallback
    final activeBaby = await BabyService.getActiveBaby();
    final info  = await ApiService.getFamilyInfo();
    final prefs = await SharedPreferences.getInstance();

    if (activeBaby != null && activeBaby.name.isNotEmpty) {
      _babyName = activeBaby.name;
    } else if (info != null) {
      _babyName = info['babyName'] ?? 'Bebeğiniz';
    }

    final babyBirthDateStr = activeBaby?.birthDate?.toIso8601String()
        ?? info?['babyBirthDate'] as String?;
    if (babyBirthDateStr != null) {
      final birthDate = DateTime.tryParse(babyBirthDateStr);
      if (birthDate != null) {
        final now = DateTime.now();
        _babyAgeMonths = (now.year - birthDate.year) * 12 + (now.month - birthDate.month);
      }
    }

    _redFlagChecked = prefs.getBool('coach_red_flag_checked') ?? false;
    _hasRedFlag     = prefs.getBool('coach_red_flag_result')  ?? false;

    final answersJson = prefs.getString(_kAnswers);
    final profileId   = prefs.getString(_kProfile);
    final started     = prefs.getBool(_kStarted) ?? false;
    final stepsJson   = prefs.getString(_kCompleted);

    if (answersJson != null) {
      try {
        final decoded = json.decode(answersJson);
        if (decoded is Map) {
          _answers.addAll(decoded.map((k, v) => MapEntry(k.toString(), v.toString())));
        }
      } catch (_) {}
    }
    if (profileId != null) {
      _profile = [_profileNursing, _profileMotion, _profileEnvironment, _profileWakings, _profileSleepOnset, _profileNaps]
          .firstWhere((p) => p.id == profileId, orElse: () => _profileSleepOnset);
    }
    final nightsJson  = prefs.getString(_kNights);
    final skippedJson = prefs.getString(_kSkipped);
    if (nightsJson != null) {
      final raw = json.decode(nightsJson) as Map<String, dynamic>;
      _nightCheckins = raw.map((k, v) => MapEntry(int.parse(k), List<String>.from(v)));
    }
    if (skippedJson != null) {
      final raw = json.decode(skippedJson) as Map<String, dynamic>;
      _skippedNights = raw.map((k, v) => MapEntry(int.parse(k), List<String>.from(v)));
    }
    _programStarted = started;
    if (stepsJson != null) _completedSteps = List<int>.from(json.decode(stepsJson));

    // Yerel veri yoksa API'dan geri yüklemeyi dene (cihaz değişikliği / yeni kurulum)
    if (_completedSteps.isEmpty) {
      final apiData = await ApiService.loadCoachData();
      if (apiData != null) {
        final apiProfileId = apiData['profileId'] as String?;
        if (apiProfileId != null && apiProfileId.isNotEmpty && _profile == null) {
          _profile = [_profileNursing, _profileMotion, _profileEnvironment, _profileWakings, _profileSleepOnset, _profileNaps]
              .firstWhere((p) => p.id == apiProfileId, orElse: () => _profileSleepOnset);
          await prefs.setString(_kProfile, apiProfileId);
        }
        _programStarted = apiData['started'] as bool? ?? false;
        _completedSteps = List<int>.from(apiData['completed'] ?? []);
        final nightsRaw = apiData['nights'] as Map<String, dynamic>? ?? {};
        _nightCheckins = nightsRaw.map((k, v) => MapEntry(int.parse(k), List<String>.from(v)));
        // Yerel depolamaya da yaz
        await prefs.setBool(_kStarted, _programStarted);
        await prefs.setString(_kCompleted, json.encode(_completedSteps));
        await prefs.setString(_kNights, json.encode(nightsRaw));
      }
    }

    _viewingStepOrder = _currentStepOrder;

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveAnswer(String key, String value) async {
    _answers[key] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAnswers, json.encode(_answers));
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isAnalyzing = true);
    await Future.delayed(const Duration(milliseconds: 1800));
    final profile = _assignProfile(_answers);
    final prefs   = await SharedPreferences.getInstance();
    await prefs.setString(_kProfile, profile.id);
    if (mounted) setState(() { _profile = profile; _isAnalyzing = false; });
  }

  Future<void> _startProgram() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kStarted, true);
    if (mounted) setState(() => _programStarted = true);
    _syncProgressToApi();
  }

  Future<void> _resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAnswers);
    await prefs.remove(_kProfile);
    await prefs.remove(_kStarted);
    await prefs.remove(_kCompleted);
    await prefs.remove(_kNights);
    await prefs.remove(_kSkipped);
    await prefs.remove('coach_red_flag_checked');
    await prefs.remove('coach_red_flag_result');
    if (mounted) {
      setState(() {
        _answers.clear();
        _profile = null;
        _programStarted = false;
        _completedSteps = [];
        _nightCheckins = {};
        _skippedNights = {};
        _viewingStepOrder = 1;
        _questionIndex = 0;
        _selectedChoice = null;
        _redFlagChecked = false;
        _hasRedFlag     = false;
        for (int i = 0; i < _redFlagValues.length; i++) {
          _redFlagValues[i] = false;
        }
      });
    }
  }

  // Bugünü "YYYY-MM-DD" olarak döndürür
  String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  int _nightsDone(int stepOrder) => (_nightCheckins[stepOrder] ?? []).length;

  bool _checkedInTonight(int stepOrder) => (_nightCheckins[stepOrder] ?? []).contains(_today);

  bool _canAdvanceStep(int stepOrder, int requiredNights) => _nightsDone(stepOrder) >= requiredNights;

  Future<void> _checkinNight(int stepOrder) async {
    if (_checkedInTonight(stepOrder)) return;
    final updated = Map<int, List<String>>.from(_nightCheckins);
    updated[stepOrder] = [...(updated[stepOrder] ?? []), _today];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNights, json.encode(updated.map((k, v) => MapEntry(k.toString(), v))));
    if (mounted) setState(() => _nightCheckins = updated);
    _syncProgressToApi();
  }

  Future<void> _advanceStep(int stepOrder) async {
    if (_completedSteps.contains(stepOrder)) return;
    final updated = List<int>.from(_completedSteps)..add(stepOrder);
    final prefs   = await SharedPreferences.getInstance();
    await prefs.setString(_kCompleted, json.encode(updated));
    if (mounted) {
      setState(() {
        _completedSteps = updated;
        _viewingStepOrder = _currentStepOrder;
      });
    }
    _syncProgressToApi();
  }

  Future<void> _skipNight(int stepOrder) async {
    if (_checkedInTonight(stepOrder)) return;
    final updated = Map<int, List<String>>.from(_skippedNights);
    updated[stepOrder] = [...(updated[stepOrder] ?? []), _today];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSkipped, json.encode(updated.map((k, v) => MapEntry(k.toString(), v))));
    if (mounted) {
      setState(() => _skippedNights = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu gece atlandı. Yarın kaldığınız yerden devam edin.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // İlerlemeyi API'ya arka planda senkronize eder
  void _syncProgressToApi() {
    ApiService.saveCoachData({
      'profileId': _profile?.id ?? '',
      'started': _programStarted,
      'completed': _completedSteps,
      'nights': _nightCheckins.map((k, v) => MapEntry(k.toString(), v)),
    });
  }

  // Sıradaki tamamlanmamış adım
  int get _currentStepOrder {
    if (_profile == null) return 1;
    for (final s in _profile!.steps) {
      if (!_completedSteps.contains(s.order)) return s.order;
    }
    return _profile!.steps.last.order;
  }

  bool get _allDone => _profile != null && _completedSteps.length >= _profile!.steps.length;

  // ─── BUILD ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: colors.primary)));
    }
    if (_isAnalyzing) return _buildAnalyzingScreen(colors);

    // 2A: Kırmızı bayrak kontrolü (program henüz başlamamışsa)
    if (_profile == null && !_redFlagChecked) {
      return _buildRedFlagCheck(colors, isDark);
    }
    if (_hasRedFlag) {
      return _buildRedFlagWarning(colors, isDark);
    }

    // 2B: Yaş < 4 ay kontrolü
    if (_babyAgeMonths < 4) {
      return _buildUnder4MonthsInfo(colors, isDark);
    }

    if (_profile == null) return _buildOnboarding(colors, isDark);
    if (!_programStarted) return _buildProfileReveal(colors, isDark);
    return _buildActiveProgram(colors, isDark);
  }

  // ─── GÜVENLİK KATMANLARI ─────────────────────────────────────────────────

  static const _redFlagLabels = [
    'Uyurken horlama veya nefes duraklaması',
    'Aşırı terleme (normal olmayan)',
    'Beslenmeyi reddetme',
    'Kilo alımı konusunda endişe',
    'Ani ve açıklanamayan uyku düzeni bozulması',
    'Sürekli ve yoğun huzursuzluk',
  ];

  Widget _buildRedFlagCheck(ColorScheme colors, bool isDark) {
    final anySelected = _redFlagValues.any((v) => v);
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1425) : const Color(0xFFF4F0F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width > 600 ? (MediaQuery.of(context).size.width - 560) / 2 : 24.0,
            vertical: 24.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('Önce Birkaç Önemli Soru',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: colors.onSurface, height: 1.2)),
              const SizedBox(height: 12),
              Text(
                'Uyku koçluğu programına başlamadan önce bebeğinizde aşağıdakilerden herhangi biri var mı?',
                style: TextStyle(fontSize: 15, height: 1.55, color: isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(height: 24),
              ...List.generate(_redFlagLabels.length, (i) {
                return StatefulBuilder(builder: (ctx, setLocal) {
                  return CheckboxListTile(
                    value: _redFlagValues[i],
                    onChanged: (val) {
                      setState(() => _redFlagValues[i] = val ?? false);
                    },
                    title: Text(_redFlagLabels[i],
                        style: TextStyle(fontSize: 14, color: colors.onSurface)),
                    activeColor: colors.primary,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                });
              }),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final hasFlag = _redFlagValues.any((v) => v);
                    final prefs   = await SharedPreferences.getInstance();
                    await prefs.setBool('coach_red_flag_checked', true);
                    await prefs.setBool('coach_red_flag_result', hasFlag);
                    if (mounted) setState(() { _redFlagChecked = true; _hasRedFlag = hasFlag; });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: anySelected ? Colors.red.shade600 : colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    anySelected ? 'Doktora Başvurun' : 'Devam Et',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRedFlagWarning(ColorScheme colors, bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1425) : const Color(0xFFF4F0F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width > 600 ? (MediaQuery.of(context).size.width - 560) / 2 : 24.0,
            vertical: 32.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
              const SizedBox(height: 20),
              Text(
                'Lütfen önce bir çocuk doktoruna görünün',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: colors.onSurface, height: 1.3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Bu belirtiler uyku koçluğundan önce tıbbi değerlendirme gerektirebilir. Doktorunuz size yol gösterdikten sonra programı başlatabilirsiniz.',
                style: TextStyle(fontSize: 15, height: 1.6, color: isDark ? Colors.white70 : Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('coach_red_flag_checked', false);
                    await prefs.setBool('coach_red_flag_result', false);
                    if (mounted) {
                      setState(() {
                        _redFlagChecked = false;
                        _hasRedFlag     = false;
                        for (int i = 0; i < _redFlagValues.length; i++) {
                          _redFlagValues[i] = false;
                        }
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Tekrar Değerlendir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnder4MonthsInfo(ColorScheme colors, bool isDark) {
    const items = [
      '0–3 aylık bebekler gece 2–4 kez uyanmak için biyolojik olarak programlanmıştır.',
      'Bu dönemde tutarlı bir ritim oluşturmak en büyük hedefiniz olsun — katı bir takvim değil.',
      'Beyaz gürültü, tam karanlık ve sarmalama bu yaşta çok etkilidir.',
      'Yaklaşık 4 aylık olduğunda bu programı yeniden değerlendirin.',
    ];
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1425) : const Color(0xFFF4F0F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width > 600 ? (MediaQuery.of(context).size.width - 560) / 2 : 24.0,
            vertical: 24.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('Bebeğiniz Henüz Çok Küçük',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: colors.onSurface, height: 1.2)),
              const SizedBox(height: 12),
              Text(
                '4 aydan küçük bebekler için yapılandırılmış uyku eğitimi henüz uygun değildir. Bu yaşta bebeğinizin uykusu hakkında bilmeniz gerekenler:',
                style: TextStyle(fontSize: 15, height: 1.55, color: isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: colors.primary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(item, style: TextStyle(fontSize: 14, height: 1.55, color: isDark ? Colors.white70 : Colors.black54))),
                      ],
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Bu bilgiler genel rehberliktir, tıbbi tavsiye değildir.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ─── ONBOARDING ──────────────────────────────────────────────────────────

  Widget _buildOnboarding(ColorScheme colors, bool isDark) {
    final q = _questions[_questionIndex];
    _selectedChoice ??= _answers[q.key];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1425) : const Color(0xFFF4F0F6),
      body: SafeArea(
        child: Column(
          children: [
            // Üst bar: geri butonu + ilerleme noktaları
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  if (_questionIndex > 0)
                    GestureDetector(
                      onTap: () => setState(() { _questionIndex--; _selectedChoice = _answers[_questions[_questionIndex].key]; }),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: colors.surface, shape: BoxShape.circle),
                        child: Icon(Icons.arrow_back_rounded, color: colors.primary, size: 20),
                      ),
                    )
                  else
                    const SizedBox(width: 36),
                  const Spacer(),
                  Row(
                    children: List.generate(_questions.length, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width:  _questionIndex == i ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i <= _questionIndex ? colors.primary : colors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                  const Spacer(),
                  const SizedBox(width: 36),
                ],
              ),
            ),

            // Soru içeriği
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: _buildQuestionBody(q, colors, isDark),
              ),
            ),

            // İleri butonu
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedChoice == null
                      ? null
                      : () async {
                          await _saveAnswer(q.key, _selectedChoice!);
                          if (_questionIndex < _questions.length - 1) {
                            if (mounted) setState(() { _questionIndex++; _selectedChoice = _answers[_questions[_questionIndex].key]; });
                          } else {
                            await _finishOnboarding();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: colors.primary.withValues(alpha: 0.3),
                    disabledForegroundColor: Colors.white54,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                    _questionIndex < _questions.length - 1 ? 'Devam Et' : 'Profilimi Oluştur',
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

  Widget _buildQuestionBody(_Question q, ColorScheme colors, bool isDark) {
    return SingleChildScrollView(
      key: ValueKey(q.key),
      padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width > 600 ? (MediaQuery.of(context).size.width - 560) / 2 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(q.question, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colors.onSurface, height: 1.3)),
          const SizedBox(height: 8),
          Text(q.subtitle, style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : Colors.black45)),
          const SizedBox(height: 28),
          ...q.choices.map((c) => _buildChoiceCard(c, colors, isDark)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildChoiceCard(_Choice c, ColorScheme colors, bool isDark) {
    final isSelected = _selectedChoice == c.value;
    return GestureDetector(
      onTap: () => setState(() => _selectedChoice = c.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.08)
              : colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? colors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            if (!isDark && !isSelected)
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? colors.primary.withValues(alpha: 0.15) : (isDark ? const Color(0xFF2C223A) : const Color(0xFFEBE3EE)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(c.icon, color: colors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.onSurface)),
                  if (c.sublabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(c.sublabel, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
                  ],
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? colors.primary : Colors.transparent,
                border: Border.all(color: isSelected ? colors.primary : (isDark ? Colors.white24 : Colors.black26), width: 2),
              ),
              child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 13) : null,
            ),
          ],
        ),
      ),
    );
  }

  // ─── ANALİZ EKRANI ───────────────────────────────────────────────────────

  Widget _buildAnalyzingScreen(ColorScheme colors) {
    return Scaffold(
      backgroundColor: const Color(0xFF5C4B71),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            const SizedBox(height: 32),
            const Text('Profiliniz oluşturuluyor', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Cevaplarınız analiz ediliyor...', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ─── GÜVENLİ UYKU VE SORUMLULUK REDDİ ───────────────────────────────────

  Widget _safeSleepItem(String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(children: [
      Icon(Icons.check_circle_outline, size: 16, color: Colors.blue.shade600),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: Colors.blue.shade800))),
    ]),
  );

  Widget _buildSafeSleepBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.shield_rounded, color: Colors.blue.shade700, size: 20),
            const SizedBox(width: 8),
            Text('Güvenli Uyku Hatırlatmaları',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
          ]),
          const SizedBox(height: 8),
          _safeSleepItem('Her zaman sırt üstü yatırın'),
          _safeSleepItem('Sert ve düz bir uyku yüzeyi kullanın'),
          _safeSleepItem('Beşikte yastık, yorgan veya oyuncak bırakmayın'),
          _safeSleepItem('Oda sıcaklığını 16–20°C tutun'),
        ],
      ),
    );
  }

  Widget _buildDisclaimerText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        'Bu uygulama tıbbi tavsiye vermez ve herhangi bir yazar, yayınevi veya sağlık kuruluşuyla bağlantısı yoktur. Bebeğinizle ilgili sağlık endişeleriniz için bir çocuk doktoruna danışın.',
        style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ─── PROFİL GÖSTERİMİ ────────────────────────────────────────────────────

  Widget _buildProfileReveal(ColorScheme colors, bool isDark) {
    final p = _profile!;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1425) : const Color(0xFFF4F0F6),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width > 600 ? (MediaQuery.of(context).size.width - 560) / 2 : 24.0,
            vertical: 24.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('Profiliniz Hazır', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.primary)),
              const SizedBox(height: 8),
              Text('$_babyName için kişisel plan', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: colors.onSurface, height: 1.2)),
              const SizedBox(height: 28),

              // Profil kartı
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5C4B71), Color(0xFF836FA9)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    if (!isDark) BoxShadow(color: const Color(0xFF5C4B71).withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                      child: Icon(p.icon, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 20),
                    Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(p.tagline, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Açıklama
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Text(p.description, style: TextStyle(fontSize: 15, height: 1.65, color: isDark ? Colors.white70 : Colors.black54)),
              ),
              const SizedBox(height: 20),

              // Adım önizlemesi
              Text('${p.steps.length} Adımlık Kişisel Planınız', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.onSurface)),
              const SizedBox(height: 14),
              ...p.steps.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Center(child: Text('${s.order}', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 13))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface))),
                  ],
                ),
              )),
              const SizedBox(height: 24),

              // 2D: Güvenli uyku hatırlatmaları
              _buildSafeSleepBanner(),

              // 2C: Ebeveyn krizi banner
              if (_answers['parent_wellbeing'] == 'crisis') ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💛', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Kendinize de iyi bakın', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text(
                              'Yoğun bir dönemdesiniz. Bu program en hafif adımlarla başlayacak. Destek için sevdiklerinizden yardım istemekten çekinmeyin.',
                              style: TextStyle(fontSize: 13, height: 1.5, color: Colors.amber.shade900),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _startProgram,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: const Text('Programa Başla', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('Soruları Sıfırla', style: TextStyle(fontWeight: FontWeight.bold)),
                        content: const Text('Profil silinecek ve soruları yeniden cevaplamanız gerekecek.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C4B71), foregroundColor: Colors.white),
                            child: const Text('Sıfırla'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) _resetAll();
                  },
                  child: Text('Soruları Yeniden Cevapla', style: TextStyle(color: colors.primary.withValues(alpha: 0.6), fontSize: 13)),
                ),
              ),
              const SizedBox(height: 8),

              // 2E: Sorumluluk reddi
              _buildDisclaimerText(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── AKTİF PROGRAM ───────────────────────────────────────────────────────

  Widget _buildActiveProgram(ColorScheme colors, bool isDark) {
    final p = _profile!;
    final currentOrder  = _currentStepOrder;
    final viewingOrder  = _viewingStepOrder;
    final currentStep   = p.steps.firstWhere((s) => s.order == viewingOrder);
    final isCompleted   = _completedSteps.contains(viewingOrder);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1425) : const Color(0xFFF4F0F6),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF5C4B71), Color(0xFF836FA9)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text(_allDone ? 'Program Tamamlandı 🎉' : 'Adım $currentOrder / ${p.steps.length}',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.restart_alt_rounded, color: Colors.white.withValues(alpha: 0.7)),
                        tooltip: 'Baştan Başla',
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Text('Baştan Başla', style: TextStyle(fontWeight: FontWeight.bold)),
                              content: const Text('Tüm ilerleme ve profil silinecek. Soruları yeniden cevaplayacaksınız.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5C4B71), foregroundColor: Colors.white),
                                  child: const Text('Sıfırla'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) _resetAll();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _completedSteps.length / p.steps.length,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      color: Colors.white,
                      minHeight: 7,
                    ),
                  ),
                ],
              ),
            ),

            // İçerik
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width > 600 ? (MediaQuery.of(context).size.width - 560) / 2 : 24.0,
                  vertical: 24.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2D: Güvenli uyku hatırlatmaları
                    _buildSafeSleepBanner(),

                    // 2C: Ebeveyn krizi banner
                    if (_answers['parent_wellbeing'] == 'crisis') ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('💛', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Kendinize de iyi bakın', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Yoğun bir dönemdesiniz. Bu program en hafif adımlarla başlayacak. Destek için sevdiklerinizden yardım istemekten çekinmeyin.',
                                    style: TextStyle(fontSize: 13, height: 1.5, color: Colors.amber.shade900),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_allDone && viewingOrder == currentOrder) ...[
                      _buildCompletionCard(p, colors, isDark),
                    ] else ...[
                      _buildCurrentStepCard(currentStep, isCompleted, viewingOrder, colors, isDark, p, isActiveStep: viewingOrder == currentOrder && !_allDone),
                      const SizedBox(height: 24),
                    ],
                    _buildStepsList(p, colors, isDark),
                    const SizedBox(height: 24),
                    _buildLibraryCard(colors, isDark),
                    const SizedBox(height: 8),

                    // 2E: Sorumluluk reddi
                    _buildDisclaimerText(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepCard(_CoachStep step, bool isCompleted, int currentOrder, ColorScheme colors, bool isDark, _CoachProfile profile, {bool isActiveStep = true}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık satırı
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(step.icon, color: colors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('Adım $currentOrder', style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 4),
                    Text(step.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: colors.onSurface)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Neden?
          _buildInfoSection('Neden?', step.why, Icons.lightbulb_rounded, colors, isDark),
          const SizedBox(height: 16),

          // Nasıl?
          _buildInfoSection('Nasıl yapacaksınız?', step.howTo, Icons.edit_note_rounded, colors, isDark, highlight: true),
          const SizedBox(height: 16),

          // Beklenen Sonuç
          _buildInfoSection('Beklenen sonuç', step.expected, Icons.trending_up_rounded, colors, isDark),
          const SizedBox(height: 22),

          // İlerleme ve buton
          if (step.isPreparation) ...[
            // Hazırlık adımı — tek tıkla geç
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isCompleted ? null : () => _advanceStep(step.order),
                icon: Icon(isCompleted ? Icons.check_circle_rounded : Icons.check_rounded, size: 20),
                label: Text(isCompleted ? 'Hazırlandı ✓' : 'Hazırladım, sonraki adıma geç →',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCompleted ? Colors.green.withValues(alpha: 0.12) : Colors.green,
                  foregroundColor: isCompleted ? Colors.green : Colors.white,
                  disabledBackgroundColor: Colors.green.withValues(alpha: 0.12),
                  disabledForegroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ] else
            Builder(builder: (_) {
            final nightsDone = _nightsDone(step.order);
            final canAdvance = _canAdvanceStep(step.order, step.requiredNights);
            final checkedInTonight = _checkedInTonight(step.order);
            final label = profile.checkInLabel;

            // Tamamlanmış adım görüntüleniyorsa sadece özet göster
            if (isCompleted) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text('Tamamlandı ($nightsDone gece)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha: 0.12),
                    foregroundColor: Colors.green,
                    disabledBackgroundColor: Colors.green.withValues(alpha: 0.12),
                    disabledForegroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ...List.generate(step.requiredNights, (i) => Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < nightsDone
                            ? colors.primary
                            : colors.primary.withValues(alpha: 0.18),
                      ),
                    )),
                    const SizedBox(width: 8),
                    Text(
                      '$nightsDone / ${step.requiredNights}',
                      style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: canAdvance
                      ? ElevatedButton.icon(
                          onPressed: () => _advanceStep(step.order),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                          label: const Text('Sonraki Adıma Geç →', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        )
                      : !isActiveStep
                          ? ElevatedButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.lock_outline_rounded, size: 20),
                              label: const Text('Önce aktif adımı tamamlayın', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.onSurface.withValues(alpha: 0.06),
                                foregroundColor: colors.onSurface.withValues(alpha: 0.35),
                                disabledBackgroundColor: colors.onSurface.withValues(alpha: 0.06),
                                disabledForegroundColor: colors.onSurface.withValues(alpha: 0.35),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                            )
                          : checkedInTonight
                              ? ElevatedButton.icon(
                                  onPressed: null,
                                  icon: const Icon(Icons.check_rounded, size: 20),
                                  label: const Text('Bugün Uygulandı ✓', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colors.primary.withValues(alpha: 0.12),
                                    foregroundColor: colors.primary,
                                    disabledBackgroundColor: colors.primary.withValues(alpha: 0.12),
                                    disabledForegroundColor: colors.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () => _checkinNight(step.order),
                                  icon: Icon(profile.id == 'nap_difficulties' ? Icons.wb_sunny_rounded : Icons.nightlight_round, size: 20),
                                  label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                ),
                ),
                if (isActiveStep && !checkedInTonight && !canAdvance) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _skipNight(step.order),
                      icon: Icon(Icons.next_plan_outlined, size: 16, color: colors.onSurface.withValues(alpha: 0.35)),
                      label: Text(
                        'Bu geceyi atla (hastalık / seyahat)',
                        style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35)),
                      ),
                    ),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String label, String text, IconData icon, ColorScheme colors, bool isDark, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: colors.primary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.primary)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: highlight
                ? colors.primary.withValues(alpha: 0.06)
                : (isDark ? const Color(0xFF2C223A) : const Color(0xFFF4F0F6)),
            borderRadius: BorderRadius.circular(14),
            border: highlight ? Border.all(color: colors.primary.withValues(alpha: 0.2), width: 1.5) : null,
          ),
          child: Text(text, style: TextStyle(fontSize: 13, height: 1.65, color: isDark ? Colors.white70 : Colors.black54)),
        ),
      ],
    );
  }

  Widget _buildStepsList(_CoachProfile p, ColorScheme colors, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tüm Adımlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colors.onSurface)),
        const SizedBox(height: 14),
        ...p.steps.map((s) {
          final done     = _completedSteps.contains(s.order);
          final isActive = s.order == _currentStepOrder && !_allDone;
          final viewing  = s.order == _viewingStepOrder;
          return GestureDetector(
            onTap: () => setState(() => _viewingStepOrder = s.order),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: viewing ? colors.primary.withValues(alpha: 0.07) : colors.surface,
                borderRadius: BorderRadius.circular(14),
                border: viewing
                    ? Border.all(color: colors.primary, width: 1.5)
                    : Border.all(color: Colors.transparent, width: 1.5),
                boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? colors.primary : (viewing ? colors.primary.withValues(alpha: 0.12) : Colors.transparent),
                      border: done ? null : Border.all(color: viewing ? colors.primary : (isDark ? Colors.white24 : Colors.black26), width: 1.5),
                    ),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                          : Text('${s.order}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: viewing ? colors.primary : (isDark ? Colors.white38 : Colors.black38))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: viewing ? FontWeight.bold : FontWeight.w500,
                            color: done ? (isDark ? Colors.white38 : Colors.black38) : colors.onSurface,
                            decoration: done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (isActive && !done) ...[
                          const SizedBox(height: 2),
                          Text('Aktif adım', style: TextStyle(fontSize: 11, color: colors.primary, fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(s.isPreparation ? 'Hazırlık' : '${s.requiredNights} gece', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCompletionCard(_CoachProfile p, ColorScheme colors, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF5C4B71), Color(0xFF836FA9)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [if (!isDark) BoxShadow(color: const Color(0xFF5C4B71).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          const Icon(Icons.celebration_rounded, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text('Programı Tamamladınız!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('${p.name} programının tüm adımlarını başarıyla uyguladınız.', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, height: 1.5), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _resetAll,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF5C4B71), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
            child: const Text('Yeni Program Başlat', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryCard(ColorScheme colors, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: const Text('Uyku Kütüphanesi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: const GuideScreen(),
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.menu_book_rounded, color: colors.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Uyku Kütüphanesi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.onSurface)),
                  const SizedBox(height: 3),
                  Text('Tüm teknikler ve interaktif asistanlar', style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white24 : Colors.black26),
          ],
        ),
      ),
    );
  }
}
