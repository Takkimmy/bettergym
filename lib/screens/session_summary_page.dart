import 'package:flutter/material.dart';

import '../main.dart'; // Inherit global colors
import 'main_layout.dart';
import 'progress_report_page.dart';

class SessionSummaryPage extends StatefulWidget {
  final int totalReps;
  final int durationMinutes;
  final int formWarnings;
  final bool isCompleted; // NEW: Tracks if they finished or quit

  const SessionSummaryPage({
    super.key, 
    this.totalReps = 142,
    this.durationMinutes = 45,
    this.formWarnings = 3,
    this.isCompleted = true, // Defaults to true
  });

  @override
  State<SessionSummaryPage> createState() => _SessionSummaryPageState();
}

class _SessionSummaryPageState extends State<SessionSummaryPage> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1200)
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.5, 1.0, curve: Curves.easeIn))
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkSlate,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.0)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // NEW: Dynamic UI mapping based on completion status
    final Color themeColor = widget.isCompleted ? mintGreen : Colors.orange;
    final IconData heroIcon = widget.isCompleted ? Icons.check_rounded : Icons.stop_rounded;
    final String titleText = widget.isCompleted ? 'SESSION COMPLETE' : 'SESSION ABORTED';
    final String subText = widget.isCompleted ? 'Biomechanical data successfully logged.' : 'Partial session data saved to history.';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.5, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: child,
                  );
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: themeColor, width: 4),
                    boxShadow: [
                      BoxShadow(color: themeColor.withOpacity(0.3), blurRadius: 30, spreadRadius: 5),
                    ]
                  ),
                  child: Icon(heroIcon, color: themeColor, size: 64),
                ),
              ),
              
              const SizedBox(height: 32),
              
              Text(
                titleText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 3.0),
              ),
              const SizedBox(height: 8),
              Text(
                subText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              
              const SizedBox(height: 48),

              Row(
                children: [
                  Expanded(child: _buildStatBox('TOTAL REPS', widget.totalReps.toString(), Icons.fitness_center, themeColor)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatBox('MINUTES', widget.durationMinutes.toString(), Icons.timer, Colors.blueAccent)),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatBox('FORM WARNINGS', widget.formWarnings.toString(), Icons.warning_amber_rounded, widget.formWarnings > 5 ? neonRed : Colors.orange),

              const Spacer(),

              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: navyBlue,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const ProgressReportPage()),
                        );
                      },
                      child: const Text('VIEW DETAILED REPORT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.grey),
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const MainLayout()),
                          (route) => false,
                        );
                      },
                      child: const Text('RETURN TO DASHBOARD', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}