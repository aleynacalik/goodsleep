import 'package:flutter/material.dart';

class UniversalCoachScreen extends StatefulWidget {
  final String title;
  final Color color;
  final List<Map<String, dynamic>> steps;

  const UniversalCoachScreen({
    super.key,
    required this.title,
    required this.color,
    required this.steps,
  });

  @override
  State<UniversalCoachScreen> createState() => _UniversalCoachScreenState();
}

class _UniversalCoachScreenState extends State<UniversalCoachScreen> {
  int _currentStep = 0;

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final step = widget.steps[_currentStep];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.steps.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _currentStep == index ? 24 : 8,
                    decoration: BoxDecoration(
                      color: _currentStep >= index ? widget.color : Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Column(
                  key: ValueKey<int>(_currentStep),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(step['icon'], size: 80, color: widget.color),
                    ),
                    const SizedBox(height: 32),
                    Text(step['title'], style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: themeColors.onSurface), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Text(step['desc'], style: TextStyle(fontSize: 16, height: 1.5, color: isDark ? Colors.white70 : Colors.black87), textAlign: TextAlign.center),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _currentStep == 0 ? null : _prevStep,
                    child: Text('Geri', style: TextStyle(color: _currentStep == 0 ? Colors.transparent : widget.color, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  if (_currentStep < widget.steps.length - 1)
                    ElevatedButton(
                      onPressed: _nextStep,
                      style: ElevatedButton.styleFrom(backgroundColor: widget.color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: const Text('Sonraki Adım', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Eğitimi Bitir'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
