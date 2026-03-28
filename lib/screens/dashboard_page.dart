import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../main.dart'; 
import 'session_setup_page.dart'; 
import '../services/local_db_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = true;
  bool _transportActive = false; // Gimmick for transporting latest activity
  int _enduranceLookback = 7;

  Map<String, dynamic> _data = {};
  Map<String, List<double>> _fatigueCurves = {};
  String? _selectedFatigueExercise;
  
  List<int> _weeklyHeatmap = [0, 0, 0, 0, 0, 0, 0];
  final List<String> _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // --- 1. NEW COLOR SOP ---
  Color _getScoreColor(double score) {
    if (score >= 100) return const Color(0xFF8B00FF); // Violet
    if (score >= 75) return mintGreen; // Green
    if (score >= 50) return Colors.yellow; // Yellow
    if (score >= 25) return Colors.orange; // Orange
    return neonRed; // Red
  }

  Future<void> _loadDashboardData() async {
    try {
      final aggregates = await LocalDBService.instance.getDashboardAggregates();
      final rawEndurance = await LocalDBService.instance.getRawTelemetryForPeriod(_enduranceLookback);
      
      _processEndurance(rawEndurance);
      _generateHeatmap(List<Map<String, dynamic>>.from(aggregates['timeline'] ?? []));

      if (mounted) {
        setState(() {
          _data = aggregates;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Dashboard Hydration Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _generateHeatmap(List<Map<String, dynamic>> timeline) {
    List<int> generated = [0, 0, 0, 0, 0, 0, 0];
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));

    for (var s in timeline) {
      final date = DateTime.parse(s['created_at']).toLocal();
      final score = s['global_score'] as int;
      if (date.isAfter(startOfWeek.subtract(const Duration(seconds: 1)))) {
        int dayIndex = date.weekday - 1; 
        generated[dayIndex] = score; // Store the exact score to color it later
      }
    }
    _weeklyHeatmap = generated;
  }

  void _processEndurance(List<Map<String, dynamic>> telemetry) {
    Map<String, List<List<double>>> rawArrays = {};
    for (var row in telemetry) {
      try {
        List<double> scores = List<double>.from(jsonDecode(row['rep_scores_array']).map((e) => (e as num).toDouble()));
        rawArrays.putIfAbsent(row['exercise_name'], () => []).add(scores);
      } catch (_) {}
    }
    Map<String, List<double>> averaged = {};
    rawArrays.forEach((name, sets) {
      int maxLen = sets.map((s) => s.length).reduce(math.max);
      List<double> curve = [];
      for (int i = 0; i < maxLen; i++) {
        double sum = 0; int count = 0;
        for (var s in sets) { if (i < s.length) { sum += s[i]; count++; } }
        curve.add(sum / count);
      }
      averaged[name] = curve;
    });
    setState(() {
      _fatigueCurves = averaged;
      if (_fatigueCurves.isNotEmpty && _selectedFatigueExercise == null) {
        _selectedFatigueExercise = _fatigueCurves.keys.first;
      }
    });
  }

  String _formatTotalTime(int? totalSeconds) {
    if (totalSeconds == null || totalSeconds == 0) return "0m";
    int h = totalSeconds ~/ 3600;
    int m = (totalSeconds % 3600) ~/ 60;
    return h > 0 ? "${h}h ${m}m" : "${m}m";
  }

  String _getRelativeDate(String sqlDate) {
    final date = DateTime.parse(sqlDate).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final compare = DateTime(date.year, date.month, date.day);
    final diff = today.difference(compare).inDays;
    
    if (diff == 0) return "Today";
    if (diff == 1) return "Yesterday";
    return "$diff Days ago";
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkSlate, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: navyBlue, body: Center(child: CircularProgressIndicator(color: mintGreen)));
    }

    final bento = _data['bento'] ?? {};
    double wAvg = (bento['weekly_avg'] as num?)?.toDouble() ?? 0.0;
    double mAvg = (bento['monthly_avg'] as num?)?.toDouble() ?? 0.0;
    
    final lastKnown = _data['last_known'];
    final bool workedToday = lastKnown != null && lastKnown['relative_date'] == 'TODAY';
    
    final timeline = List<Map<String, dynamic>>.from(_data['timeline'] ?? []);

    return Scaffold(
      backgroundColor: navyBlue,
      appBar: AppBar(
        backgroundColor: navyBlue, elevation: 0,
        title: const Text('TELEMETRY DASHBOARD', style: TextStyle(color: mintGreen, fontWeight: FontWeight.bold, letterSpacing: 2.0, fontSize: 16)), 
      ),
      body: timeline.isEmpty 
        ? _buildZeroState()
        : RefreshIndicator(
            color: mintGreen, backgroundColor: darkSlate, onRefresh: _loadDashboardData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // --- GIMMICK: Transport Latest Activity to Top ---
                if (_transportActive && timeline.isNotEmpty) ...[
                  _buildTimelineNode(timeline.first),
                  const SizedBox(height: 24),
                ],

                // --- 1. COMPARATIVE BENTO BOXES ---
                Row(
                  children: [
                    Expanded(child: _buildBentoRing("Weekly Average", wAvg)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildBentoRing("Monthly Progress", mAvg)),
                  ],
                ),
                const SizedBox(height: 24),

                // --- 2. CONSISTENCY HEATMAP ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) => _buildHeatmapDay(_days[index], _weeklyHeatmap[index])),
                ),
                const SizedBox(height: 24),

                // --- 3. ACTION HUB (If no workout today) ---
                if (!workedToday) ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: mintGreen, foregroundColor: navyBlue, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionSetupPage())),
                    child: const Text("SETUP A SESSION", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 24),
                ],

                // --- 4. TODAY'S INTEL (Fallback Logic) ---
                if (lastKnown != null) ...[
                  _buildContextualCard(lastKnown),
                  const SizedBox(height: 24),
                ],

                // --- 5. WEEKLY VOLUME ---
                if (_data['weekly_volume'] != null && _data['weekly_volume']['total_reps'] != null) ...[
                  _buildWeeklySection(_data['weekly_volume']),
                  const SizedBox(height: 24),
                ],

                // --- 6. SWIPABLE TREND GRAPHS ---
                _buildSwipableGraphs(),
                const SizedBox(height: 24),

                // --- 7. FORM DIAGNOSTICS ---
                _buildDiagnostics(),
                const SizedBox(height: 24),

                // --- 8. FORM ENDURANCE ---
                _buildEnduranceSection(),
                const SizedBox(height: 24),

                // --- 9. LATEST ACTIVITY ---
                if (!_transportActive && timeline.isNotEmpty) ...[
                  const Text('LATEST ACTIVITY', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  ...timeline.take(5).map((session) => _buildTimelineNode(session)),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildBentoRing(String label, double score) {
    Color col = score == 0.0 ? Colors.white10 : _getScoreColor(score);
    return _buildGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              height: 80, width: 80,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(value: score == 0.0 ? 1.0 : score / 100, strokeWidth: 8, backgroundColor: Colors.black26, color: col),
                  Center(child: Text(score == 0.0 ? "--" : "${score.toInt()}%", style: TextStyle(color: score == 0.0 ? Colors.grey : Colors.white, fontWeight: FontWeight.bold, fontSize: 20))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapDay(String day, int score) {
    Color blockColor = score == 0 ? Colors.black26 : _getScoreColor(score.toDouble());
    return Column(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: blockColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: score == 0 ? Colors.white10 : Colors.transparent)),
        ),
        const SizedBox(height: 8),
        Text(day, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildContextualCard(Map<String, dynamic> last) {
    String title = last['relative_date'] == 'TODAY' ? "TODAY'S INTEL" : "LAST SESSION (${last['relative_date']})";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        _buildGlassCard(
          child: Column(
            children: [
              _infoRow(Icons.bolt, "Avg Score", "${last['global_score']}%", valColor: _getScoreColor((last['global_score'] as num).toDouble())),
              const Divider(color: Colors.white10, height: 24),
              _infoRow(Icons.timer, "Duration", _formatTotalTime(last['duration_seconds'])),
              const Divider(color: Colors.white10, height: 24),
              // We don't have total_reps purely for ONE session in the raw DB return easily, so we can display relative date instead.
              _infoRow(Icons.calendar_today, "Recorded", _getRelativeDate(last['created_at'])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklySection(Map<String, dynamic> v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("THIS WEEK'S VOLUME", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        _buildGlassCard(
          child: Column(
            children: [
              _infoRow(Icons.calendar_month, "Active Days", "${v['active_days']} / 7"),
              const Divider(color: Colors.white10, height: 24),
              _infoRow(Icons.timer_outlined, "Total Duration", _formatTotalTime(v['total_time'] as int?)),
              const Divider(color: Colors.white10, height: 24),
              _infoRow(Icons.fitness_center, "Total Reps", "${v['total_reps'] ?? 0}"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String val, {Color? valColor}) {
    return Row(
      children: [
        Icon(icon, color: mintGreen, size: 18),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const Spacer(),
        Text(val, style: TextStyle(color: valColor ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildSwipableGraphs() {
    List<dynamic> g7 = _data['graph_7'] ?? [];
    List<dynamic> g30 = _data['graph_30'] ?? [];
    
    if (g7.isEmpty && g30.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 220,
      child: PageView(
        children: [
          if (g7.isNotEmpty) _buildTrendChart("7-DAY TREND", g7),
          if (g30.isNotEmpty) _buildTrendChart("30-DAY TREND", g30),
        ],
      ),
    );
  }

  Widget _buildTrendChart(String title, List<dynamic> data) {
    List<FlSpot> spots = [];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), (data[i]['avg_score'] as num).toDouble()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        _buildGlassCard(
          padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
          child: SizedBox(
            height: 140,
            child: LineChart(LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              minY: 0, maxY: 100,
              lineBarsData: [
                LineChartBarData(
                  spots: spots, isCurved: true, color: mintGreen, barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: _getScoreColor(spot.y), strokeWidth: 0),
                  ),
                  belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [mintGreen.withOpacity(0.2), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                )
              ],
            )),
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnostics() {
    final diag = List<Map<String, dynamic>>.from(_data['diagnostics'] ?? []);
    if (diag.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("FORM DIAGNOSTICS", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        _buildGlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ...diag.take(2).map((e) => _diagRow(e)),
              if (diag.length > 2) ...[
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Colors.white10)),
                ...diag.skip(diag.length - 2).map((e) => _diagRow(e)),
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _diagRow(Map<String, dynamic> e) {
    double score = (e['avg_score'] as num).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Text(e['exercise_name'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
          const Spacer(), 
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: _getScoreColor(score).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _getScoreColor(score).withOpacity(0.5))),
            child: Text("${score.toInt()}%", style: TextStyle(color: _getScoreColor(score), fontWeight: FontWeight.bold)),
          )
        ]
      ),
    );
  }

  Widget _buildEnduranceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("FORM ENDURANCE", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            DropdownButton<int>(
              value: _enduranceLookback,
              dropdownColor: darkSlate, underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down, color: mintGreen, size: 16),
              style: const TextStyle(color: mintGreen, fontSize: 12, fontWeight: FontWeight.bold),
              items: [7, 14, 30].map((e) => DropdownMenuItem(value: e, child: Text("$e Days"))).toList(),
              onChanged: (v) { setState(() { _enduranceLookback = v!; _loadDashboardData(); }); },
            )
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedFatigueExercise != null) _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButton<String>(
                value: _selectedFatigueExercise,
                dropdownColor: darkSlate, isExpanded: true, underline: const Divider(color: Colors.white10),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                items: _fatigueCurves.keys.map((String key) => DropdownMenuItem(value: key, child: Text(key.toUpperCase()))).toList(),
                onChanged: (val) => setState(() => _selectedFatigueExercise = val),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: LineChart(LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (val) => FlLine(color: Colors.white10, strokeWidth: 1)),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10)))),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0, maxY: 1.0,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _fatigueCurves[_selectedFatigueExercise]!.asMap().entries.map((e) => FlSpot(e.key.toDouble() + 1, e.value)).toList(),
                      isCurved: true, color: mintGreen, barWidth: 3, dotData: const FlDotData(show: false),
                    )
                  ]
                )),
              )
            ],
          )
        ) else _buildGlassCard(child: const Center(child: Text("No endurance data available.", style: TextStyle(color: Colors.grey)))),
      ],
    );
  }

  Widget _buildTimelineNode(Map<String, dynamic> session) {
    double score = (session['global_score'] as num).toDouble();
    String timeStr = _getRelativeDate(session['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: darkSlate, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _getScoreColor(score), width: 2), color: Colors.black.withOpacity(0.2)),
          child: Center(child: Text(score.toInt().toString(), style: TextStyle(color: _getScoreColor(score), fontWeight: FontWeight.bold, fontSize: 16))),
        ),
        title: Text(timeStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: const Text('Tap to view report', style: TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        onTap: () {
          // Future Connection: Pass the session['id'] here when linking to SessionSummaryPage/ProgressReportPage
          debugPrint("Transporting to Session ID: ${session['id']}");
        },
      ),
    );
  }

  Widget _buildZeroState() {
     return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
       const Icon(Icons.analytics, size: 64, color: Colors.white10),
       const SizedBox(height: 16),
       const Text("NO DATA YET", style: TextStyle(color: Colors.white, letterSpacing: 2, fontWeight: FontWeight.bold)),
       const SizedBox(height: 24),
       Padding(
         padding: const EdgeInsets.symmetric(horizontal: 40),
         child: ElevatedButton(
           style: ElevatedButton.styleFrom(backgroundColor: mintGreen, foregroundColor: navyBlue, minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
           onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionSetupPage())), 
           child: const Text("SETUP A SESSION", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2))
         ),
       )
     ]));
  }
}