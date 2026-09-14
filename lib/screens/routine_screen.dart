import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoutineStep {
  final String name;
  final int durationMinutes;
  final IconData icon;

  const RoutineStep({
    required this.name,
    required this.durationMinutes,
    required this.icon,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'durationMinutes': durationMinutes,
        'iconCodePoint': icon.codePoint,
      };

  factory RoutineStep.fromJson(Map<String, dynamic> json) => RoutineStep(
        name: json['name'] as String? ?? '',
        durationMinutes: (json['durationMinutes'] as num? ?? 1).toInt(),
        icon: IconData(
          json['iconCodePoint'] as int? ?? Icons.star.codePoint,
          fontFamily: 'MaterialIcons',
        ),
      );
}

class SavedRoutine {
  final String id;
  final String name;
  final List<RoutineStep> steps;

  const SavedRoutine({required this.id, required this.name, required this.steps});

  int get totalMinutes => steps.fold(0, (sum, s) => sum + s.durationMinutes);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  factory SavedRoutine.fromJson(Map<String, dynamic> json) => SavedRoutine(
        id: json['id'],
        name: json['name'],
        steps: ((json['steps'] as List?) ?? []).map((s) => RoutineStep.fromJson(s as Map<String, dynamic>)).toList(),
      );
}

class CompletedRoutineEntry {
  final String routineName;
  final DateTime completedAt;
  final int totalMinutes;

  CompletedRoutineEntry({required this.routineName, required this.completedAt, required this.totalMinutes});

  Map<String, dynamic> toJson() => {
    'routineName': routineName,
    'completedAt': completedAt.toIso8601String(),
    'totalMinutes': totalMinutes,
  };

  factory CompletedRoutineEntry.fromJson(Map<String, dynamic> json) => CompletedRoutineEntry(
    routineName: json['routineName'] as String? ?? '',
    completedAt: DateTime.tryParse(json['completedAt'] as String? ?? '') ?? DateTime.now(),
    totalMinutes: (json['totalMinutes'] as num? ?? 0).toInt(),
  );
}

Future<void> _saveCompletedRoutine(CompletedRoutineEntry entry) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('completed_routines');
  final list = raw != null ? (json.decode(raw) as List).map((e) => CompletedRoutineEntry.fromJson(e)).toList() : <CompletedRoutineEntry>[];
  list.insert(0, entry);
  if (list.length > 50) list.removeLast();
  await prefs.setString('completed_routines', json.encode(list.map((e) => e.toJson()).toList()));
}

final _allPickerIcons = <IconData>[
  Icons.bathtub_rounded,
  Icons.spa_rounded,
  Icons.checkroom_rounded,
  Icons.baby_changing_station_rounded,
  Icons.music_note_rounded,
  Icons.dark_mode_rounded,
  Icons.speaker_rounded,
  Icons.favorite_rounded,
  Icons.layers_rounded,
  Icons.timer_rounded,
];

final _templates = [
  SavedRoutine(
    id: 'tpl_evening',
    name: '30dk Akşam Rutini',
    steps: [
      RoutineStep(name: 'Banyo', durationMinutes: 10, icon: Icons.bathtub_rounded),
      RoutineStep(name: 'Masaj', durationMinutes: 5, icon: Icons.spa_rounded),
      RoutineStep(name: 'Uyku Kıyafeti', durationMinutes: 2, icon: Icons.checkroom_rounded),
      RoutineStep(name: 'Emzirme / Biberon', durationMinutes: 10, icon: Icons.baby_changing_station_rounded),
      RoutineStep(name: 'Ninni & Karartma', durationMinutes: 3, icon: Icons.dark_mode_rounded),
    ],
  ),
  SavedRoutine(
    id: 'tpl_quick',
    name: '15dk Hızlı Rutin',
    steps: [
      RoutineStep(name: 'Kıyafet Değiştirme', durationMinutes: 2, icon: Icons.checkroom_rounded),
      RoutineStep(name: 'Emzirme', durationMinutes: 8, icon: Icons.baby_changing_station_rounded),
      RoutineStep(name: 'Beyaz Gürültü', durationMinutes: 5, icon: Icons.speaker_rounded),
    ],
  ),
  SavedRoutine(
    id: 'tpl_nap',
    name: 'Gündüz Şekerleme Rutini',
    steps: [
      RoutineStep(name: 'Karartma', durationMinutes: 2, icon: Icons.dark_mode_rounded),
      RoutineStep(name: 'Beyaz Gürültü', durationMinutes: 3, icon: Icons.speaker_rounded),
      RoutineStep(name: 'Sarmalama', durationMinutes: 3, icon: Icons.layers_rounded),
      RoutineStep(name: 'Sallama', durationMinutes: 5, icon: Icons.favorite_rounded),
    ],
  ),
];

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  List<SavedRoutine> _routines = [];
  List<CompletedRoutineEntry> _history = [];
  static const _prefsKey = 'saved_routines';

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final list = json.decode(raw) as List;
        if (mounted) setState(() => _routines = list.map((e) => SavedRoutine.fromJson(e)).toList());
      } catch (_) {
        await prefs.remove(_prefsKey);
      }
    }
    final histRaw = prefs.getString('completed_routines');
    if (histRaw != null) {
      try {
        final list = json.decode(histRaw) as List;
        if (mounted) setState(() => _history = list.map((e) => CompletedRoutineEntry.fromJson(e)).toList());
      } catch (_) {}
    }
  }

  Future<void> _saveRoutines() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(_routines.map((r) => r.toJson()).toList()));
  }

  Future<void> _deleteRoutine(String id) async {
    final routine = _routines.firstWhere((r) => r.id == id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rutini Sil', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('"${routine.name}" rutini kalıcı olarak silinecek.'),
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
    if (ok != true) return;
    setState(() => _routines.removeWhere((r) => r.id == id));
    await _saveRoutines();
  }

  void _openCreateSheet({SavedRoutine? prefill}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateRoutineSheet(
        prefill: prefill,
        onSave: (routine) async {
          setState(() => _routines.insert(0, routine));
          await _saveRoutines();
        },
      ),
    );
  }

  void _runRoutine(SavedRoutine routine) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _RoutineRunScreen(routine: routine)))
        .then((_) { if (mounted) _loadRoutines(); });
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1425) : const Color(0xFFF4F0F6),
      floatingActionButton: FloatingActionButton(
        backgroundColor: themeColors.primary,
        foregroundColor: Colors.white,
        onPressed: _openCreateSheet,
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text('Rutinlerim', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: themeColors.onSurface)),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text('Şablonlar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black54)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _templates.length,
                itemBuilder: (context, i) => _buildTemplateCard(_templates[i], themeColors, isDark),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('Kayıtlı Rutinler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black54)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  if (_routines.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(Icons.playlist_add_rounded, size: 60, color: themeColors.primary.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('Henüz rutin yok.', style: TextStyle(fontSize: 16, color: isDark ? Colors.white54 : Colors.black54)),
                          const SizedBox(height: 6),
                          Text('+ butonuyla yeni rutin oluşturun', style: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.black38)),
                        ],
                      ),
                    )
                  else
                    ..._routines.map((r) => _buildRoutineCard(r, themeColors, isDark)),

                  if (_history.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Son Tamamlananlar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black54)),
                    const SizedBox(height: 12),
                    ..._history.take(20).map((e) => _buildHistoryItem(e, themeColors, isDark)),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(CompletedRoutineEntry entry, ColorScheme colors, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(entry.completedAt.year, entry.completedAt.month, entry.completedAt.day);
    final diff = today.difference(entryDay).inDays;
    final dayLabel = diff == 0 ? 'Bugün' : diff == 1 ? 'Dün' : '${entry.completedAt.day}.${entry.completedAt.month.toString().padLeft(2,'0')}';
    final timeLabel = '${entry.completedAt.hour.toString().padLeft(2,'0')}:${entry.completedAt.minute.toString().padLeft(2,'0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C223A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, size: 16, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.routineName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.onSurface)),
                Text('${entry.totalMinutes} dk', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(timeLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colors.primary)),
              Text(dayLabel, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(SavedRoutine template, ColorScheme themeColors, bool isDark) {
    return GestureDetector(
      onTap: () => _openCreateSheet(prefill: template),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [themeColors.primary, const Color(0xFF836FA9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!isDark) BoxShadow(color: themeColors.primary.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(template.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            Text('${template.totalMinutes} dk • ${template.steps.length} adım', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineCard(SavedRoutine routine, ColorScheme themeColors, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: themeColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(routine.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeColors.onSurface)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: Colors.redAccent,
                onPressed: () => _deleteRoutine(routine.id),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${routine.totalMinutes} dk • ${routine.steps.length} adım', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: routine.steps.map((step) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: themeColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(step.icon, size: 14, color: themeColors.primary),
                  const SizedBox(width: 4),
                  Text('${step.name} (${step.durationMinutes}dk)', style: TextStyle(fontSize: 12, color: themeColors.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            )).toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _runRoutine(routine),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Başlat', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateRoutineSheet extends StatefulWidget {
  final SavedRoutine? prefill;
  final Future<void> Function(SavedRoutine) onSave;

  const _CreateRoutineSheet({this.prefill, required this.onSave});

  @override
  State<_CreateRoutineSheet> createState() => _CreateRoutineSheetState();
}

class _CreateRoutineSheetState extends State<_CreateRoutineSheet> {
  final _nameController = TextEditingController();
  List<_StepEdit> _steps = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefill != null) {
      _nameController.text = widget.prefill!.name;
      _steps = widget.prefill!.steps.map((s) => _StepEdit(
        nameController: TextEditingController(text: s.name),
        durationMinutes: s.durationMinutes,
        icon: s.icon,
      )).toList();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final s in _steps) {
      s.nameController.dispose();
    }
    super.dispose();
  }

  void _addStep() {
    setState(() => _steps.add(_StepEdit(
      nameController: TextEditingController(),
      durationMinutes: 5,
      icon: Icons.timer_rounded,
    )));
  }

  void _removeStep(int index) {
    _steps[index].nameController.dispose();
    setState(() => _steps.removeAt(index));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _steps.isEmpty) return;

    setState(() => _saving = true);
    final routine = SavedRoutine(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      steps: _steps.map((s) => RoutineStep(
        name: s.nameController.text.trim().isEmpty ? 'Adım' : s.nameController.text.trim(),
        durationMinutes: s.durationMinutes,
        icon: s.icon,
      )).toList(),
    );
    await widget.onSave(routine);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: themeColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            Text('Yeni Rutin', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: themeColors.onSurface)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Rutin adı (örneğin: Gece Rutini)',
                filled: true,
                fillColor: isDark ? const Color(0xFF2C223A) : const Color(0xFFF4F0F6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Adımlar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: themeColors.onSurface)),
                TextButton.icon(
                  onPressed: _addStep,
                  icon: Icon(Icons.add_rounded, color: themeColors.primary, size: 18),
                  label: Text('Adım Ekle', style: TextStyle(color: themeColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._steps.asMap().entries.map((entry) => _buildStepEditor(entry.key, entry.value, themeColors, isDark)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepEditor(int index, _StepEdit step, ColorScheme themeColors, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C223A) : const Color(0xFFF4F0F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _showIconPicker(index, themeColors),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: themeColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(step.icon, color: themeColors.primary, size: 22),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: step.nameController,
                  decoration: InputDecoration(
                    hintText: 'Adım adı',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1A1425) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                color: Colors.redAccent,
                onPressed: () => _removeStep(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Süre: ', style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54)),
              IconButton(
                icon: const Icon(Icons.remove_rounded, size: 18),
                onPressed: step.durationMinutes > 1
                    ? () => setState(() => step.durationMinutes--)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: themeColors.primary,
              ),
              const SizedBox(width: 8),
              Text('${step.durationMinutes} dk', style: TextStyle(fontWeight: FontWeight.bold, color: themeColors.onSurface)),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_rounded, size: 18),
                onPressed: step.durationMinutes < 60
                    ? () => setState(() => step.durationMinutes++)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: themeColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showIconPicker(int index, ColorScheme themeColors) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('İkon Seç', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _allPickerIcons.map((icon) => GestureDetector(
            onTap: () {
              setState(() => _steps[index].icon = icon);
              Navigator.pop(ctx);
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: themeColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: themeColors.primary, size: 28),
            ),
          )).toList(),
        ),
      ),
    );
  }
}

class _StepEdit {
  final TextEditingController nameController;
  int durationMinutes;
  IconData icon;

  _StepEdit({required this.nameController, required this.durationMinutes, required this.icon});
}

class _RoutineRunScreen extends StatefulWidget {
  final SavedRoutine routine;

  const _RoutineRunScreen({required this.routine});

  @override
  State<_RoutineRunScreen> createState() => _RoutineRunScreenState();
}

class _RoutineRunScreenState extends State<_RoutineRunScreen> {
  int _currentStepIndex = 0;
  int _remainingSeconds = 0;
  bool _isPaused = false;
  bool _isFinished = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initStep();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initStep() {
    _timer?.cancel();
    final step = widget.routine.steps[_currentStepIndex];
    setState(() {
      _remainingSeconds = step.durationMinutes * 60;
      _isPaused = false;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) {
        if (_remainingSeconds > 0) {
          setState(() => _remainingSeconds--);
        } else {
          _onStepComplete();
        }
      }
    });
  }

  void _onStepComplete() {
    _timer?.cancel();
    HapticFeedback.mediumImpact();
    if (_currentStepIndex < widget.routine.steps.length - 1) {
      setState(() => _currentStepIndex++);
      _initStep();
    } else {
      setState(() => _isFinished = true);
      _saveCompletedRoutine(CompletedRoutineEntry(
        routineName: widget.routine.name,
        completedAt: DateTime.now(),
        totalMinutes: widget.routine.totalMinutes,
      ));
    }
  }

  void _skip() {
    _timer?.cancel();
    _onStepComplete();
  }

  void _togglePause() => setState(() => _isPaused = !_isPaused);

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isFinished) return _buildCelebration(themeColors, isDark);

    final step = widget.routine.steps[_currentStepIndex];
    final totalSeconds = step.durationMinutes * 60;
    final progress = totalSeconds > 0 ? (_remainingSeconds / totalSeconds) : 0.0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1425) : const Color(0xFFF4F0F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            _timer?.cancel();
            Navigator.pop(context);
          },
        ),
        title: Text(widget.routine.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Text(
                'Adım ${_currentStepIndex + 1} / ${widget.routine.steps.length}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                  color: themeColors.primary,
                  minHeight: 6,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: themeColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(step.icon, size: 80, color: themeColors.primary),
              ),
              const SizedBox(height: 32),
              Text(step.name, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: themeColors.onSurface), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Text(
                _formatTime(_remainingSeconds),
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: _remainingSeconds <= 10 ? Colors.orange : themeColors.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _togglePause,
                    icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 22),
                    label: Text(_isPaused ? 'Devam' : 'Duraklat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: themeColors.primary,
                      side: BorderSide(color: themeColors.primary.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _skip,
                    icon: const Icon(Icons.skip_next_rounded, size: 22),
                    label: const Text('Atla'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCelebration(ColorScheme themeColors, bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1425) : const Color(0xFFF4F0F6),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(36),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5C4B71), Color(0xFF836FA9)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (!isDark) BoxShadow(color: const Color(0xFF5C4B71).withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: const Icon(Icons.celebration_rounded, size: 72, color: Colors.white),
                ),
                const SizedBox(height: 32),
                Text('Tebrikler!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: themeColors.onSurface)),
                const SizedBox(height: 12),
                Text(
                  '"${widget.routine.name}" rutinini tamamladınız.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.5, color: isDark ? Colors.white70 : Colors.black54),
                ),
                const SizedBox(height: 8),
                Text(
                  'Toplam ${widget.routine.totalMinutes} dakika',
                  style: TextStyle(fontSize: 14, color: themeColors.primary, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Kapat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
