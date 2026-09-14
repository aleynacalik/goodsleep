import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  List<dynamic> _logs = [];

  // Temel istatistikler
  int _longestSleepSeconds = 0;
  int _nightSleepSeconds = 0;
  int _daySleepSeconds = 0;
  List<double> _weeklyData = List.filled(7, 0.0);

  // İçgörü hesaplamaları
  double _thisWeekTotal = 0;
  double _lastWeekTotal = 0;
  double _avgDailySeconds = 0;
  List<_Insight> _insights = [];

  @override
  void initState() {
    super.initState();
    _fetchAndCalculateStats();
  }

  Future<void> _fetchAndCalculateStats() async {
    setState(() { _isLoading = true; _hasError = false; });
    List<dynamic> logs;
    try {
      logs = await ApiService.getLogs();
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
      return;
    }

    if (logs.isNotEmpty) {
      int maxSleep = 0;
      int nightTotal = 0;
      int dayTotal = 0;
      List<double> weekly = List.filled(7, 0.0);
      double thisWeek = 0;
      double lastWeek = 0;

      // Saat bazlı dağılım (0-23) — en yoğun uyku saatini bulmak için
      final List<double> hourBuckets = List.filled(24, 0.0);

      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);

      for (var log in logs) {
        final duration = (log['durationInSeconds'] as num? ?? 0).toInt();
        final startTime = DateTime.parse(log['startTime']).toLocal();
        final logDate = DateTime(startTime.year, startTime.month, startTime.day);
        final daysAgo = todayDate.difference(logDate).inDays;

        if (duration > maxSleep) maxSleep = duration;

        if (daysAgo >= 0 && daysAgo < 7) {
          weekly[6 - daysAgo] += duration / 3600.0;
          thisWeek += duration / 3600.0;
          hourBuckets[startTime.hour] += duration / 3600.0;
          if (startTime.hour >= 19 || startTime.hour < 7) {
            nightTotal += duration;
          } else {
            dayTotal += duration;
          }
        }

        if (daysAgo >= 7 && daysAgo < 14) {
          lastWeek += duration / 3600.0;
        }
      }

      // Günlük ortalama: son 7 günde kayıt olan gün sayısına böl
      final activeDays = weekly.where((h) => h > 0).length;
      final avgDaily = activeDays > 0 ? (thisWeek / activeDays) * 3600 : 0.0;

      // En yoğun uyku saati
      double maxBucket = 0;
      int peakHour = -1;
      for (int i = 0; i < 24; i++) {
        if (hourBuckets[i] > maxBucket) {
          maxBucket = hourBuckets[i];
          peakHour = i;
        }
      }

      setState(() {
        _logs = logs;
        _longestSleepSeconds = maxSleep;
        _nightSleepSeconds = nightTotal;
        _daySleepSeconds = dayTotal;
        _weeklyData = weekly;
        _thisWeekTotal = thisWeek;
        _lastWeekTotal = lastWeek;
        _avgDailySeconds = avgDaily;
        _insights = _buildInsights(
          thisWeek: thisWeek,
          lastWeek: lastWeek,
          avgDaily: avgDaily,
          peakHour: peakHour,
          nightTotal: nightTotal,
          dayTotal: dayTotal,
          activeDays: activeDays,
        );
      });
    }

    setState(() => _isLoading = false);
  }

  List<_Insight> _buildInsights({
    required double thisWeek,
    required double lastWeek,
    required double avgDaily,
    required int peakHour,
    required int nightTotal,
    required int dayTotal,
    required int activeDays,
  }) {
    final insights = <_Insight>[];

    // 1. Haftalık trend
    if (lastWeek > 0 && thisWeek > 0) {
      final pct = ((thisWeek - lastWeek) / lastWeek * 100).round();
      if (pct > 0) {
        insights.add(_Insight(
          icon: Icons.trending_up_rounded,
          color: const Color(0xFF4CAF50),
          text: 'Bu hafta geçen haftaya göre %$pct daha fazla uyku kaydedildi. Harika bir ilerleme!',
        ));
      } else if (pct < 0) {
        insights.add(_Insight(
          icon: Icons.trending_down_rounded,
          color: Colors.orange,
          text: 'Bu hafta uyku süresi geçen haftaya kıyasla %${pct.abs()} azaldı. Rutini gözden geçirmeye değer.',
        ));
      }
    } else if (thisWeek == 0) {
      insights.add(_Insight(
        icon: Icons.info_outline_rounded,
        color: Colors.grey,
        text: 'Bu hafta henüz uyku kaydı girilmedi. Verileri girmek içgörülerin oluşmasını sağlar.',
      ));
    }

    // 2. Gündüz/gece dengesi — yalnızca bu haftaya ait veriden hesaplanır
    if (thisWeek > 0) {
      final totalSleep = nightTotal + dayTotal;
      if (totalSleep > 0) {
        final nightPct = nightTotal / totalSleep;
        if (nightPct > 0.6) {
          insights.add(_Insight(
            icon: Icons.nights_stay_rounded,
            color: const Color(0xFF5C4B71),
            text: 'Bu hafta gece uykusu toplam uykunun %${(nightPct * 100).round()}\'ini oluşturuyor. Sirkadiyen ritim güçleniyor.',
          ));
        } else if (nightPct < 0.4) {
          insights.add(_Insight(
            icon: Icons.wb_sunny_rounded,
            color: Colors.amber,
            text: 'Bu hafta gündüz uykusu gece uykusunu geride bırakıyor. Akşam rutinini öne almayı deneyebilirsiniz.',
          ));
        }
      }
    }

    // 3. Aktif gün sayısı
    if (activeDays < 4 && thisWeek > 0) {
      insights.add(_Insight(
        icon: Icons.edit_calendar_rounded,
        color: Colors.blueGrey,
        text: 'Bu hafta $activeDays gün kayıt girildi. Düzenli kayıt, örüntüleri daha net ortaya çıkarır.',
      ));
    }

    // 4. En verimli uyku saati — anlamlı olması için en az 3 günlük veri gerekir
    if (peakHour >= 0 && activeDays >= 3) {
      final label = peakHour < 12 ? 'sabah' : (peakHour < 18 ? 'öğleden sonra' : 'akşam/gece');
      insights.add(_Insight(
        icon: Icons.access_time_rounded,
        color: const Color(0xFF836FA9),
        text: 'En uzun uyku periyodları genellikle ${peakHour.toString().padLeft(2, '0')}:00\'da ($label) başlıyor.',
      ));
    }

    return insights;
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds == 0) return '0s 0dk';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    return hours > 0 ? '${hours}s ${minutes}dk' : '${minutes}dk';
  }

  String _formatHours(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    return h > 0 ? '${h}s ${m}dk' : '${m}dk';
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double maxWeeklyHours = _weeklyData.isEmpty ? 0 : _weeklyData.reduce(max);
    double chartMaxY = maxWeeklyHours < 10 ? 12 : maxWeeklyHours + 2;
    double chartInterval = chartMaxY > 15 ? 4 : 2;

    // Haftalık % değişim
    double weekPct = 0;
    bool weekUp = false;
    if (_lastWeekTotal > 0) {
      weekPct = (_thisWeekTotal - _lastWeekTotal) / _lastWeekTotal * 100;
      weekUp = weekPct >= 0;
    }

    return SafeArea(
      child: _isLoading
          ? Center(child: CircularProgressIndicator(color: themeColors.primary))
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 48, color: isDark ? Colors.white38 : Colors.black26),
                      const SizedBox(height: 16),
                      Text('Veriler yüklenemedi.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeColors.onSurface)),
                      const SizedBox(height: 8),
                      Text('İnternet bağlantınızı kontrol edin.', style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _fetchAndCalculateStats,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Tekrar Dene'),
                        style: ElevatedButton.styleFrom(backgroundColor: themeColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      ),
                    ],
                  ),
                )
          : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bar_chart_rounded, size: 48, color: isDark ? Colors.white38 : Colors.black26),
                      const SizedBox(height: 16),
                      const Text('Henüz veri yok.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Uyku kaydı ekledikçe istatistikler burada görünecek.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Uyku İstatistikleri', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: themeColors.onSurface)),
                      const SizedBox(height: 24),

                      // 1. REKOR KARTI
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [themeColors.primary, const Color(0xFF6C5A7D)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [if (!isDark) BoxShadow(color: themeColors.primary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.emoji_events_rounded, color: Colors.white, size: 28),
                                SizedBox(width: 12),
                                Text('Kesintisiz Uyku Rekoru', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(_formatDuration(_longestSleepSeconds), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. HAFTALIK ÖZET — Bu Hafta vs Geçen Hafta
                      Row(
                        children: [
                          Expanded(
                            child: _StatMiniCard(
                              icon: Icons.calendar_today_rounded,
                              label: 'Bu Hafta',
                              value: _formatHours(_thisWeekTotal),
                              badge: _lastWeekTotal > 0
                                  ? _WeekBadge(pct: weekPct, up: weekUp)
                                  : null,
                              themeColors: themeColors,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatMiniCard(
                              icon: Icons.av_timer_rounded,
                              label: 'Günlük Ortalama',
                              value: _formatDuration(_avgDailySeconds.round()),
                              themeColors: themeColors,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // 3. PASTA GRAFİK
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: themeColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 5))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Gece vs Gündüz Dağılımı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeColors.onSurface)),
                            const SizedBox(height: 8),
                            Text('Tüm zamanlar', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 200,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 4,
                                  centerSpaceRadius: 50,
                                  sections: [
                                    PieChartSectionData(
                                      color: const Color(0xFF5C4B71),
                                      value: _nightSleepSeconds.toDouble(),
                                      title: _nightSleepSeconds > 0 ? 'Gece' : '',
                                      radius: 40,
                                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    PieChartSectionData(
                                      color: const Color(0xFFD8CADD),
                                      value: _daySleepSeconds.toDouble(),
                                      title: _daySleepSeconds > 0 ? 'Gündüz' : '',
                                      radius: 40,
                                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5C4B71)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _LegendDot(color: const Color(0xFF5C4B71), label: 'Gece  ${_formatDuration(_nightSleepSeconds)}'),
                                const SizedBox(width: 20),
                                _LegendDot(color: const Color(0xFFD8CADD), label: 'Gündüz  ${_formatDuration(_daySleepSeconds)}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 4. ÇİZGİ GRAFİK
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: themeColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 5))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Son 7 Günlük Trend', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeColors.onSurface)),
                            const SizedBox(height: 32),
                            SizedBox(
                              height: 180,
                              child: LineChart(
                                LineChartData(
                                  minY: 0,
                                  maxY: chartMaxY,
                                  gridData: const FlGridData(show: false),
                                  titlesData: FlTitlesData(
                                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 32,
                                        interval: chartInterval,
                                        getTitlesWidget: (value, meta) => Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: Text('${value.toInt()}h', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
                                          final date = DateTime.now().subtract(Duration(days: 6 - value.toInt()));
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text(days[date.weekday - 1], style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11, fontWeight: FontWeight.bold)),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      preventCurveOverShooting: true,
                                      spots: _weeklyData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                                      isCurved: true,
                                      color: themeColors.primary,
                                      barWidth: 4,
                                      isStrokeCapRound: true,
                                      dotData: const FlDotData(show: true),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: themeColors.primary.withValues(alpha: 0.15),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 5. AKILLI İÇGÖRÜLER
                      if (_insights.isNotEmpty) ...[
                        Text('Akıllı İçgörüler', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeColors.onSurface)),
                        const SizedBox(height: 12),
                        ..._insights.map((insight) => _InsightCard(insight: insight, isDark: isDark, themeColors: themeColors)),
                        const SizedBox(height: 8),
                      ],

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }
}

// --- Yardımcı Veri Modeli ---

class _Insight {
  final IconData icon;
  final Color color;
  final String text;
  const _Insight({required this.icon, required this.color, required this.text});
}

// --- Yardımcı Widget'lar ---

class _StatMiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? badge;
  final ColorScheme themeColors;
  final bool isDark;

  const _StatMiniCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.themeColors,
    required this.isDark,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: themeColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: themeColors.primary, size: 22),
              ?badge,
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: themeColors.onSurface)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
        ],
      ),
    );
  }
}

class _WeekBadge extends StatelessWidget {
  final double pct;
  final bool up;

  const _WeekBadge({required this.pct, required this.up});

  @override
  Widget build(BuildContext context) {
    final color = up ? const Color(0xFF4CAF50) : Colors.orange;
    final icon = up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text('${pct.abs().toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final _Insight insight;
  final ColorScheme themeColors;
  final bool isDark;

  const _InsightCard({required this.insight, required this.themeColors, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: insight.color.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: insight.color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(insight.icon, color: insight.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(insight.text, style: TextStyle(fontSize: 14, height: 1.5, color: isDark ? Colors.white70 : Colors.black87)),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54)),
      ],
    );
  }
}
