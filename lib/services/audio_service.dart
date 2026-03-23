import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  // Singleton pattern to prevent spawning multiple engines
  static final AudioService instance = AudioService._internal();
  AudioService._internal();

  bool _masterSoundEnabled = true;
  bool _leadInBeepsEnabled = true;
  double _volume = 0.5;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _masterSoundEnabled = prefs.getBool('master_sound') ?? true;
    _leadInBeepsEnabled = prefs.getBool('leadin_beeps') ?? true;
    _volume = prefs.getDouble('audio_volume') ?? 0.5;
  }

  // Spawns a dedicated player for each sound to allow overlapping audio
  Future<void> _playSound(String fileName) async {
    if (!_masterSoundEnabled) return;
    
    final player = AudioPlayer();
    await player.setVolume(_volume);
    
    // Play the file and destroy the player instance when finished to free memory
    player.onPlayerComplete.listen((_) => player.dispose());
    await player.play(AssetSource('sounds/$fileName'));
  }

  void playChime() => _playSound('chime.mp3');
  void playTick() => _playSound('tick.mp3');
  
  void playLeadInBeep() {
    if (_leadInBeepsEnabled) _playSound('beep.mp3');
  }

  void playGoBeep() {
    if (_leadInBeepsEnabled) _playSound('go.mp3');
  }
}