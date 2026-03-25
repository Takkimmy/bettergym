import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _prepTime = 10;
  int _restTime = 30;
  bool _voiceEnabled = true;
  double _volume = 1.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _prepTime = prefs.getInt('prep_time') ?? 10;
      _restTime = prefs.getInt('rest_time') ?? 30;
      _voiceEnabled = prefs.getBool('voice_enabled') ?? true;
      _volume = prefs.getDouble('master_volume') ?? 1.0;
      _isLoading = false;
    });
  }

  Future<void> _saveIntSetting(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<void> _saveBoolSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveDoubleSetting(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  // --- THE ALARM CLOCK SCROLLING WHEEL ---
  void _showScrollPicker({
    required String title,
    required int currentValue,
    required int maxLimit,
    required Function(int) onSelected,
  }) {
    int tempValue = currentValue;

    showModalBottomSheet(
      context: context,
      backgroundColor: darkSlate,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
                    ),
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    TextButton(
                      onPressed: () {
                        onSelected(tempValue);
                        Navigator.pop(context);
                      },
                      child: const Text("SAVE", style: TextStyle(color: mintGreen, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    textTheme: CupertinoTextThemeData(
                      pickerTextStyle: TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ),
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(initialItem: currentValue - 1),
                    itemExtent: 50,
                    onSelectedItemChanged: (index) {
                      tempValue = index + 1;
                    },
                    children: List.generate(maxLimit, (index) {
                      return Center(child: Text('${index + 1} sec'));
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: navyBlue, body: Center(child: CircularProgressIndicator(color: mintGreen)));
    }

    return Scaffold(
      backgroundColor: navyBlue,
      appBar: AppBar(
        backgroundColor: navyBlue,
        title: const Text('SETTINGS', style: TextStyle(color: mintGreen, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- AUDIO CONTROLS RESTORED ---
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8, top: 8),
            child: Text("AUDIO", style: TextStyle(color: mintGreen, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ),
          Container(
            decoration: BoxDecoration(color: darkSlate, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Voice Feedback", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text("AI form corrections and cadence", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  activeColor: mintGreen,
                  value: _voiceEnabled,
                  onChanged: (val) {
                    setState(() => _voiceEnabled = val);
                    _saveBoolSetting('voice_enabled', val);
                  },
                ),
                const Divider(color: Colors.grey, height: 1),
                ListTile(
                  title: const Text("Master Volume", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: mintGreen,
                      inactiveTrackColor: Colors.grey.shade800,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: _volume,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) {
                        setState(() => _volume = val);
                      },
                      onChangeEnd: (val) {
                        _saveDoubleSetting('master_volume', val);
                      },
                    ),
                  ),
                  trailing: Icon(_volume == 0 ? Icons.volume_off : Icons.volume_up, color: mintGreen),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // --- TIMER CONTROLS ---
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8),
            child: Text("TIMERS", style: TextStyle(color: mintGreen, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          ),
          Container(
            decoration: BoxDecoration(color: darkSlate, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  title: const Text("Preparation Time", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Countdown before exercise starts", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: Text("$_prepTime sec", style: const TextStyle(color: mintGreen, fontSize: 16, fontWeight: FontWeight.bold)),
                  onTap: () {
                    _showScrollPicker(
                      title: "PREP TIME",
                      currentValue: _prepTime,
                      maxLimit: 60,
                      onSelected: (val) {
                        setState(() => _prepTime = val);
                        _saveIntSetting('prep_time', val);
                      }
                    );
                  },
                ),
                const Divider(color: Colors.grey, height: 1),
                ListTile(
                  title: const Text("Rest Time", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Cooldown between sets", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: Text("$_restTime sec", style: const TextStyle(color: mintGreen, fontSize: 16, fontWeight: FontWeight.bold)),
                  onTap: () {
                    _showScrollPicker(
                      title: "REST TIME",
                      currentValue: _restTime,
                      maxLimit: 180,
                      onSelected: (val) {
                        setState(() => _restTime = val);
                        _saveIntSetting('rest_time', val);
                      }
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}