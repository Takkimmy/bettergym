import 'package:flutter/material.dart';
import '../main.dart';
import 'session_setup_page.dart';

// --- THE TELEMETRY DATA MODEL ---
class ExerciseTelemetry {
  final String name;
  final bool isDuration;
  final int target;
  int goodReps = 0;
  int badReps = 0;
  List<double> repScores = []; // Holds the 0.0 to 1.0 score for every single rep/second

  ExerciseTelemetry({required this.name, required this.isDuration, required this.target});

  // Averages all the attempts (including the 0.0s from bad reps) into a 1-100 score
  int get finalScore {
    if (repScores.isEmpty) return 0;
    double sum = repScores.fold(0, (p, c) => p + c);
    return ((sum / repScores.length) * 100).round();
  }
}

class SessionSummaryPage extends StatelessWidget {
  final bool isCompleted;
  final List<ExerciseTelemetry> telemetryData;
  final Duration totalDuration;

  const SessionSummaryPage({
    super.key, 
    required this.isCompleted,
    required this.telemetryData,
    required this.totalDuration,
  });

  int _calculateGlobalScore() {
    if (telemetryData.isEmpty) return 0;
    
    // Only average the sets that the user actually attempted
    final attemptedSets = telemetryData.where((t) => t.repScores.isNotEmpty).toList();
    if (attemptedSets.isEmpty) return 0;

    int totalScore = attemptedSets.fold(0, (sum, set) => sum + set.finalScore);
    return (totalScore / attemptedSets.length).round();
  }

  int _calculateTotalVolume() {
    return telemetryData.fold(0, (sum, set) => sum + set.goodReps);
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) return "${d.inHours}:$twoDigitMinutes:$twoDigitSeconds";
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final int globalScore = _calculateGlobalScore();
    final int totalSets = telemetryData.length;
    final int attemptedSets = telemetryData.where((t) => t.repScores.isNotEmpty).length;
    final int completedSets = isCompleted ? totalSets : (attemptedSets > 0 ? attemptedSets - 1 : 0);

    return Scaffold(
      backgroundColor: navyBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- HEADER (Strictly Neutral) ---
              Text(
                isCompleted ? "SESSION COMPLETE" : "SESSION ABORTED",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isCompleted ? mintGreen : Colors.orangeAccent,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4.0,
                ),
              ),
              const SizedBox(height: 48),

              // --- THE 1-100 SCORE ---
              Center(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: darkSlate,
                    border: Border.all(color: globalScore > 75 ? mintGreen : (globalScore > 50 ? Colors.orangeAccent : neonRed), width: 6),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, spreadRadius: 5),
                    ]
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          globalScore.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            height: 1.0
                          ),
                        ),
                        const Text("SCORE", style: TextStyle(color: Colors.grey, fontSize: 14, letterSpacing: 2.0)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 64),

              // --- TELEMETRY GRID ---
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: "SETS COMPLETED",
                      value: "$completedSets / $totalSets",
                      icon: Icons.layers,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      title: "TOTAL VOLUME",
                      value: _calculateTotalVolume().toString(),
                      icon: Icons.fitness_center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                title: "TOTAL DURATION",
                value: _formatDuration(totalDuration),
                icon: Icons.timer,
              ),
              
              const Spacer(),

              // --- EXIT BUTTON ---
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: mintGreen,
                  foregroundColor: navyBlue,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.arrow_forward, size: 28),
                label: const Text("CONTINUE", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const SessionSetupPage()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkSlate,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: mintGreen, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}