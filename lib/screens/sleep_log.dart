import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'stats_screen.dart';

class SleepLogScreen extends StatefulWidget {
  const SleepLogScreen({super.key});

  @override
  State<SleepLogScreen> createState() => _SleepLogScreenState();
}

class _SleepLogScreenState extends State<SleepLogScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _logs = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    final logs = await ApiService.getLogs();
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  Future<void> _downloadReport() async {
    final Uri url = Uri.parse('${ApiService.baseUrl}/SleepLogs/export/${ApiService.familyId}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Bağlantı açılamıyor';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rapor indirilemedi, bağlantıyı kontrol edin.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteLog(String id) async {
    final success = await ApiService.deleteLog(id);
    if (success) {
      setState(() {
        _logs.removeWhere((l) => l['id'] == id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Uyku kaydı buluttan silindi.', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silme işlemi başarısız oldu!'), backgroundColor: Colors.red),
        );
      }
      _fetchLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Günlük', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: themeColors.onSurface)),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.download_rounded, color: themeColors.primary),
                      onPressed: _downloadReport,
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, color: themeColors.primary),
                      onPressed: _fetchLogs,
                    ),
                    GestureDetector(
                      onTap: () async {
                        final result = await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const ManualSleepEntrySheet(),
                        );
                        if (result == true) _fetchLogs();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C223A) : const Color(0xFFEBE3EE),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add_rounded, color: themeColors.primary, size: 24),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: themeColors.primary,
            unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
            indicatorColor: themeColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: const [
              Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Kayıtlar'),
              Tab(icon: Icon(Icons.insights_rounded, size: 18), text: 'İstatistikler'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLogsTab(themeColors, isDark),
                const StatsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTab(ColorScheme themeColors, bool isDark) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: themeColors.primary));
    }
    if (_logs.isEmpty) {
      return Center(
        child: Text(
          'Henüz uyku kaydı yok.\nManuel eklemek için sağ üstteki + butonunu kullanın.',
          textAlign: TextAlign.center,
          style: TextStyle(color: themeColors.onSurface, fontSize: 16, height: 1.5),
        ),
      );
    }

    List<double> weeklyData = List.filled(7, 0.0);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    for (var log in _logs) {
      final startTime = DateTime.tryParse(log['startTime'] ?? '')?.toLocal();
      if (startTime == null) continue;
      final logDate = DateTime(startTime.year, startTime.month, startTime.day);
      final difference = todayDate.difference(logDate).inDays;
      if (difference >= 0 && difference < 7) {
        weeklyData[6 - difference] += (log['durationInSeconds'] as num? ?? 0) / 3600.0;
      }
    }

    Widget getTitles(double value, TitleMeta meta) {
      final style = TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.bold, fontSize: 12);
      final date = todayDate.subtract(Duration(days: 6 - value.toInt()));
      const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
      return SideTitleWidget(meta: meta, space: 8, child: Text(days[date.weekday - 1], style: style));
    }

    Widget getLeftTitles(double value, TitleMeta meta) {
      if (value == 0 || value == 14) return const SizedBox();
      final style = TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.bold, fontSize: 10);
      return SideTitleWidget(meta: meta, child: Text('${value.toInt()}h', style: style));
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          padding: const EdgeInsets.only(left: 16.0, right: 24.0, top: 24.0, bottom: 24.0),
          decoration: BoxDecoration(
            color: themeColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text('Son 7 Gün', style: TextStyle(color: themeColors.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 14,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) => themeColors.primary,
                        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        tooltipMargin: 8,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            '${rod.toY.toStringAsFixed(1)} sa',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: getTitles, reservedSize: 28)),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: getLeftTitles, reservedSize: 32, interval: 4)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 4,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: isDark ? Colors.white10 : Colors.black12,
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: weeklyData.asMap().entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value,
                            color: themeColors.primary,
                            width: 16,
                            borderRadius: BorderRadius.circular(8),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: 14,
                              color: isDark ? const Color(0xFF2C223A) : const Color(0xFFF4F0F6),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            itemCount: _logs.length,
            itemBuilder: (context, index) {
              final log = _logs[index];
              final logId = log['id'] as String? ?? '';
              final startTime = DateTime.tryParse(log['startTime'] ?? '')?.toLocal() ?? DateTime.now();
              final endTime = DateTime.tryParse(log['endTime'] ?? '')?.toLocal() ?? DateTime.now();
              final duration = Duration(seconds: (log['durationInSeconds'] as num? ?? 0).toInt());
              final hours = duration.inHours;
              final minutes = duration.inMinutes.remainder(60);
              final durationText = hours > 0 ? '${hours}s ${minutes}dk' : '${minutes}dk';

              return Dismissible(
                key: ValueKey(logId),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(color: const Color(0xFFE57373), borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.centerRight,
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                ),
                onDismissed: (direction) => _deleteLog(logId),
                child: GestureDetector(
                  onTap: () async {
                    final result = await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ManualSleepEntrySheet(existingLog: log),
                    );
                    if (result == true) _fetchLogs();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: themeColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.cloud_done_rounded, color: themeColors.primary, size: 20),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${startTime.day.toString().padLeft(2, '0')}/${startTime.month.toString().padLeft(2, '0')}/${startTime.year}',
                                  style: TextStyle(color: themeColors.onSurface, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')} - ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(durationText, style: TextStyle(color: themeColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ManualSleepEntrySheet extends StatefulWidget {
  final Map<String, dynamic>? existingLog;

  const ManualSleepEntrySheet({super.key, this.existingLog});

  @override
  State<ManualSleepEntrySheet> createState() => _ManualSleepEntrySheetState();
}

class _ManualSleepEntrySheetState extends State<ManualSleepEntrySheet> {
  late DateTime _startTime;
  late DateTime _endTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingLog != null) {
      _startTime = DateTime.tryParse(widget.existingLog!['startTime'] ?? '')?.toLocal() ?? DateTime.now().subtract(const Duration(hours: 2));
      _endTime = DateTime.tryParse(widget.existingLog!['endTime'] ?? '')?.toLocal() ?? DateTime.now();
    } else {
      _startTime = DateTime.now().subtract(const Duration(hours: 2));
      _endTime = DateTime.now();
    }
  }

  Future<void> _pickDateTime(bool isStart) async {
    final DateTime initialDate = isStart ? _startTime : _endTime;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: Theme.of(context).colorScheme.primary)),
        child: child!,
      ),
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: Theme.of(context).colorScheme.primary)),
          child: child!,
        ),
      );

      if (pickedTime != null) {
        setState(() {
          final newDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
          if (isStart) {
            _startTime = newDateTime;
            if (_startTime.isAfter(_endTime)) _endTime = _startTime.add(const Duration(hours: 1));
          } else {
            _endTime = newDateTime;
            if (_endTime.isBefore(_startTime)) _startTime = _endTime.subtract(const Duration(hours: 1));
          }
        });
      }
    }
  }

  void _saveManualLog() async {
    final duration = _endTime.difference(_startTime);
    if (duration.inMinutes < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitiş saati başlangıçtan sonra olmalıdır.'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _isSaving = true);
    bool success;

    if (widget.existingLog != null) {
      success = await ApiService.updateLog(widget.existingLog!['id'], _startTime, _endTime, duration.inSeconds);
    } else {
      success = await ApiService.addLog(_startTime, _endTime, duration.inSeconds);
    }

    if (success && mounted) {
      Navigator.pop(context, true);
    } else {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bağlantı hatası!'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  -  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(left: 32.0, right: 32.0, top: 32.0, bottom: MediaQuery.of(context).viewInsets.bottom + 32.0),
      decoration: BoxDecoration(color: themeColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            Text(
              widget.existingLog != null ? 'Kaydı Düzenle' : 'Uyku Kaydı Ekle',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: themeColors.onSurface),
            ),
            const SizedBox(height: 24),
            Text('Uyudu', style: TextStyle(color: themeColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _pickDateTime(true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C223A) : const Color(0xFFF4F0F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDateTime(_startTime), style: TextStyle(color: themeColors.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
                    Icon(Icons.edit_calendar_rounded, color: themeColors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Uyandı', style: TextStyle(color: themeColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _pickDateTime(false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C223A) : const Color(0xFFF4F0F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDateTime(_endTime), style: TextStyle(color: themeColors.onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
                    Icon(Icons.edit_calendar_rounded, color: themeColors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveManualLog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        widget.existingLog != null ? 'Güncelle' : 'Kaydet',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
