import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart'; // Required for HapticFeedback

class AudioService {
  static final AudioService instance = AudioService._internal();
  AudioService._internal();

  final AudioPlayer _chimePlayer = AudioPlayer();
  final AudioPlayer _tickPlayer = AudioPlayer();
  final AudioPlayer _beepPlayer = AudioPlayer();
  final AudioPlayer _uiPlayer = AudioPlayer(); 
  
  // NEW: Text-to-Speech Engine
  final FlutterTts _tts = FlutterTts();
  final Random _random = Random();

  bool _masterSoundEnabled = true;
  bool _leadInBeepsEnabled = true;
  bool _repChimeEnabled = true;     
  bool _metronomeEnabled = true;    
  double _volume = 0.5;

  // NEW: Cooldown Timer Tracker
  DateTime _lastSpokenTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _cooldownSeconds = 4;
  String _lastSpokenPhrase = "";

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _masterSoundEnabled = prefs.getBool('master_sound') ?? true;
    _leadInBeepsEnabled = prefs.getBool('leadin_beeps') ?? true;
    _repChimeEnabled = prefs.getBool('rep_chime') ?? true;       
    _metronomeEnabled = prefs.getBool('metronome') ?? true;      
    _volume = prefs.getDouble('audio_volume') ?? 0.5;

    await _chimePlayer.setVolume(_volume);
    await _tickPlayer.setVolume(_volume);
    await _beepPlayer.setVolume(_volume);
    await _uiPlayer.setVolume(_volume); 

    // Initialize TTS Settings
    await _tts.setVolume(_volume);
    await _tts.setSpeechRate(0.5); // 0.5 is usually a natural, conversational speed
    await _tts.setPitch(1.0);
  }

  // --- TTS LOGIC ---

  /// Speaks a phrase immediately (used for setup/prep)
  Future<void> speakPriority(List<String> variations) async {
    if (!_masterSoundEnabled) return;
    
    String phrase;
    do {
      phrase = variations[_random.nextInt(variations.length)];
    } while (phrase == _lastSpokenPhrase && variations.length > 1);
    
    _lastSpokenPhrase = phrase;
    await _tts.speak(phrase);
    _lastSpokenTime = DateTime.now(); 
  }

  /// Speaks a form correction with a 4-second Guaranteed Silence and Haptics
  Future<void> speakCorrection(List<String> variations) async {
    if (!_masterSoundEnabled) return;

    final now = DateTime.now();
    if (now.difference(_lastSpokenTime).inSeconds >= _cooldownSeconds) {
      
      String phrase;
      do {
        phrase = variations[_random.nextInt(variations.length)];
      } while (phrase == _lastSpokenPhrase && variations.length > 1);
      
      _lastSpokenPhrase = phrase;

      HapticFeedback.heavyImpact();
      await _tts.speak(phrase);
      
      // Clock starts ONLY after the voice finishes
      _lastSpokenTime = DateTime.now(); 
    }
  }

  // --- STANDARD AUDIO PLAYERS ---

  Future<void> _playOnChannel(AudioPlayer channel, String fileName) async {
    if (!_masterSoundEnabled) return; 
    if (channel.state == PlayerState.playing) {
      await channel.stop();
    }
    await channel.play(AssetSource('sounds/$fileName'));
  }

  void playChime() { if (_repChimeEnabled) _playOnChannel(_chimePlayer, 'chime.mp3'); }
  void playTick() { if (_metronomeEnabled) _playOnChannel(_tickPlayer, 'tick.mp3'); }
  void playLeadInBeep() { if (_leadInBeepsEnabled) _playOnChannel(_beepPlayer, 'beep.mp3'); }
  void playGoBeep() { if (_leadInBeepsEnabled) _playOnChannel(_beepPlayer, 'go.mp3'); }
  void playPauseSound() => _playOnChannel(_uiPlayer, 'pause.mp3');
  void playResumeSound() => _playOnChannel(_uiPlayer, 'resume.mp3');
  void playFinishSound() => _playOnChannel(_uiPlayer, 'finish.mp3');
  void playAbortSound() => _playOnChannel(_uiPlayer, 'abort.mp3');
}