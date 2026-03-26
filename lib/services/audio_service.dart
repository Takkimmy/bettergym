import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  // Singleton pattern to prevent multiple audio engines from spawning
  static final AudioService instance = AudioService._internal();
  AudioService._internal();

  final FlutterTts _tts = FlutterTts();
  
  // State tracking
  bool _voiceEnabled = true;
  double _feedbackVolume = 1.0;
  double _beepsVolume = 1.0;
  bool _isSpeaking = false;

  /// Pulls the split volumes from SharedPreferences
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _voiceEnabled = prefs.getBool('voice_enabled') ?? true;
    _feedbackVolume = prefs.getDouble('feedback_volume') ?? 1.0;
    _beepsVolume = prefs.getDouble('beeps_volume') ?? 1.0;

    // Configure the TTS Engine
    await _tts.setSpeechRate(0.5); // Adjust for a natural, coaching pace
    await _tts.setPitch(1.0);
    await _tts.setVolume(_feedbackVolume);

    // Lifecycle hooks to power the Anti-Spam lock
    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((msg) => _isSpeaking = false);
    _tts.setCancelHandler(() => _isSpeaking = false);
  }

  // ==========================================
  // CHANNEL 1: TEXT-TO-SPEECH (FEEDBACK)
  // ==========================================

  /// Priority messages (Prep phases, Rest phases) will STOP any currently playing 
  /// audio and force themselves to the front of the queue.
  Future<void> speakPriority(List<String> variations) async {
    if (!_voiceEnabled || _feedbackVolume <= 0.0) return;
    
    await _tts.stop(); // Nuke whatever is currently playing
    await _tts.setVolume(_feedbackVolume); // Re-apply volume in case it changed

    final text = variations[Random().nextInt(variations.length)];
    await _tts.speak(text);
  }

  /// Correction messages (Form breaks) are subject to the Anti-Spam lock.
  /// If the AI is already speaking, the correction is ignored.
  Future<void> speakCorrection(List<String> variations) async {
    if (!_voiceEnabled || _feedbackVolume <= 0.0 || _isSpeaking) return;

    await _tts.setVolume(_feedbackVolume);
    final text = variations[Random().nextInt(variations.length)];
    await _tts.speak(text);
  }


  // ==========================================
  // CHANNEL 2: SOUND EFFECTS (BEEPS)
  // ==========================================

  /// Fire-and-forget audio player. Spawns a lightweight instance to prevent 
  /// overlapping sounds (like fast reps) from cutting each other off.
  Future<void> _playSound(String assetPath) async {
    if (_beepsVolume <= 0.0) return;
    try {
      final player = AudioPlayer();
      await player.setVolume(_beepsVolume);
      
      // Play the sound, then immediately dispose of the player from memory when done
      player.onPlayerComplete.listen((_) => player.dispose());
      await player.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("AudioSFX Error: Could not play $assetPath - $e");
    }
  }

  // --- STANDARD WORKOUT SFX ---
  
  void playTick() {
    _playSound('sounds/tick.mp3'); // For plank countdowns
  }

  void playChime() {
    _playSound('sounds/chime.mp3'); // For a successful rep
  }

  void playLeadInBeep() {
    _playSound('sounds/beep_low.mp3'); // The "3... 2... 1..." prep sounds
  }

  void playGoBeep() {
    _playSound('sounds/beep_high.mp3'); // The "GO!" prep sound
  }

  // --- SYSTEM SFX ---

  void playPauseSound() {
    _playSound('sounds/pause.mp3'); 
  }

  void playResumeSound() {
    _playSound('sounds/resume.mp3'); 
  }

  void playAbortSound() {
    _playSound('sounds/abort.mp3'); // Error or session cancelled early
  }

  void playFinishSound() {
    _playSound('sounds/finish.mp3'); // Session fully completed
  }
}