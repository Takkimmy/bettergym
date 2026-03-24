import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../services/audio_service.dart';

class BiomechanicsEngine {
  static final BiomechanicsEngine instance = BiomechanicsEngine._internal();
  BiomechanicsEngine._internal();

  // --- REP, DEBOUNCE, & HALF-REP STATE ---
  bool _isDown = false;
  bool _hasFormBrokenThisRep = false;
  double _lowestElbowAngle = 180.0; // NEW: Tracks depth for half-reps
  
  int _consecutiveBadFrames = 0;
  int _consecutiveGoodFrames = 0;
  static const int _debounceThreshold = 5; // FAST DEBOUNCE: Catches late sags instantly

  int _publishedFormState = 1;
  String _publishedFormError = "";
  Set<PoseLandmarkType> _publishedFaultyJoints = {};
  double _smoothedFormScore = 1.0; 

  void reset() {
    _isDown = false;
    _hasFormBrokenThisRep = false;
    _lowestElbowAngle = 180.0;
    _consecutiveBadFrames = 0;
    _consecutiveGoodFrames = 0;
    _publishedFormState = 1;
    _publishedFormError = "";
    _publishedFaultyJoints = {};
    _smoothedFormScore = 1.0;
  }

  double _calculateAngle(PoseLandmark first, PoseLandmark middle, PoseLandmark last) {
    final double radians = math.atan2(last.y - middle.y, last.x - middle.x) -
        math.atan2(first.y - middle.y, first.x - middle.x);

    double degrees = (radians * 180.0 / math.pi).abs();
    if (degrees > 180.0) {
      degrees = 360.0 - degrees;
    }
    return degrees;
  }

  Map<String, dynamic> processFrame({required Pose pose, required String exerciseName}) {
    Map<String, dynamic> result = {
      'goodRepTriggered': false, 
      'badRepTriggered': false,  
      'formState': 1,
      'feedback': "Position yourself in frame.",
      'activeJoints': <PoseLandmarkType>{},
      'faultyJoints': <PoseLandmarkType>{}, 
      'formScore': 1.0,                     
    };

    switch (exerciseName.toLowerCase()) {
      case 'pushup':
      case 'pushups':
      case 'push ups':
        result = _evaluatePushUp(pose);
        break;
      case 'bicep curl':
      case 'bicep curls':
        result = _evaluateBicepCurl(pose);
        break;
      default:
        result['feedback'] = "Tracking not available for $exerciseName.";
    }
    return result;
  }

  Map<String, dynamic> _evaluatePushUp(Pose pose) {
    final landmarks = pose.landmarks;
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];

    if (leftShoulder == null || rightShoulder == null) {
      return {'goodRepTriggered': false, 'badRepTriggered': false, 'formState': 0, 'feedback': "Full body not visible.", 'activeJoints': <PoseLandmarkType>{}, 'faultyJoints': <PoseLandmarkType>{}, 'formScore': 0.0};
    }

    final bool isLeftVisible = leftShoulder.likelihood > rightShoulder.likelihood;

    final shoulder = isLeftVisible ? landmarks[PoseLandmarkType.leftShoulder] : landmarks[PoseLandmarkType.rightShoulder];
    final elbow = isLeftVisible ? landmarks[PoseLandmarkType.leftElbow] : landmarks[PoseLandmarkType.rightElbow];
    final wrist = isLeftVisible ? landmarks[PoseLandmarkType.leftWrist] : landmarks[PoseLandmarkType.rightWrist];
    final hip = isLeftVisible ? landmarks[PoseLandmarkType.leftHip] : landmarks[PoseLandmarkType.rightHip];
    final knee = isLeftVisible ? landmarks[PoseLandmarkType.leftKnee] : landmarks[PoseLandmarkType.rightKnee]; 
    final ankle = isLeftVisible ? landmarks[PoseLandmarkType.leftAnkle] : landmarks[PoseLandmarkType.rightAnkle];

    final activeJoints = <PoseLandmarkType>{
      PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow, PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist, PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip, PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle,
    };

    if (shoulder == null || elbow == null || wrist == null || hip == null || knee == null || ankle == null ||
        shoulder.likelihood < 0.5 || hip.likelihood < 0.5 || knee.likelihood < 0.5 || ankle.likelihood < 0.5) {
      return {'goodRepTriggered': false, 'badRepTriggered': false, 'formState': 0, 'feedback': "Align side profile to camera.", 'activeJoints': activeJoints, 'faultyJoints': <PoseLandmarkType>{}, 'formScore': 0.0};
    }

    // 1. Kinetic Chain & Depth Tracking
    final hipHingeAngle = _calculateAngle(shoulder, hip, knee); 
    final kneeFlexionAngle = _calculateAngle(hip, knee, ankle); 
    final elbowAngle = _calculateAngle(shoulder, elbow, wrist); 
    final shoulderAngle = _calculateAngle(hip, shoulder, elbow); 

    // Track lowest depth for half-rep detection
    if (elbowAngle < _lowestElbowAngle) {
      _lowestElbowAngle = elbowAngle;
    }

    // 2. Thermometer Smoothing
    double coreScore = ((hipHingeAngle - 155.0) / 20.0).clamp(0.0, 1.0);
    double kneeScore = ((kneeFlexionAngle - 155.0) / 20.0).clamp(0.0, 1.0);
    double handScore = ((100.0 - shoulderAngle) / 20.0).clamp(0.0, 1.0);
    double rawFormScore = math.min(coreScore, math.min(kneeScore, handScore));
    _smoothedFormScore = (_smoothedFormScore * 0.8) + (rawFormScore * 0.2);

    // 3. Raw Heuristic Checks (INDEPENDENT ACCUMULATION)
    int rawFormState = 1; 
    String rawFormError = "";
    Set<PoseLandmarkType> rawFaultyJoints = {};
    List<String> ttsVariations = [];

    // Math prep for heuristics
    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    final torsoLength = math.sqrt(math.pow(shoulder.x - hip.x, 2) + math.pow(shoulder.y - hip.y, 2));
    double expectedHipY = shoulder.y + (hip.x - shoulder.x) * ((knee.y - shoulder.y) / (knee.x - shoulder.x == 0 ? 0.001 : knee.x - shoulder.x));
    bool isSagging = hip.y > expectedHipY;

    // Check A: Perspective Lock (Priority 1)
    if (shoulderWidth > torsoLength * 0.55) {
      rawFormState = -1;
      rawFaultyJoints.addAll(activeJoints); // Flash entire skeleton
      if (rawFormError.isEmpty) {
        rawFormError = "Turn sideways.";
        ttsVariations = ["Turn sideways. Front view is not supported.", "Please face sideways to the camera.", "I need a clear side profile."];
      }
    }

    // Check B: Knees 
    if (kneeFlexionAngle < 160.0) {
      rawFormState = -1;
      rawFaultyJoints.addAll([PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle]);
      if (rawFormError.isEmpty) {
        rawFormError = "Knees bent.";
        ttsVariations = ["Knees are bent, straighten your legs.", "Keep your legs completely straight.", "Lock your knees out."];
      }
    } 

    // Check C: Hips (Stricter: 165)
    if (hipHingeAngle < 165.0) {
      rawFormState = -1;
      rawFaultyJoints.addAll([PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee]);
      if (rawFormError.isEmpty) {
        if (isSagging) {
          rawFormError = "Hips sagging.";
          ttsVariations = ["Hips are dropping. Squeeze your core.", "Keep your back straight. Don't let your hips sag.", "Tighten your core."];
        } else {
          rawFormError = "Butt too high.";
          ttsVariations = ["Lower your hips. Your butt is too high.", "Bring your hips down into a straight plank.", "Flatten your back."];
        }
      }
    } 

    // Check D: Shoulders (Stricter: > 90 indicates hands are forward)
    if (shoulderAngle > 90.0) {
      rawFormState = -1;
      rawFaultyJoints.addAll([PoseLandmarkType.leftHip, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.rightHip, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow]);
      if (rawFormError.isEmpty) {
        rawFormError = "Hands too far forward.";
        ttsVariations = ["Move your hands back. Stack them under your shoulders.", "Your hands are too far forward.", "Stack your wrists directly under your shoulders."];
      }
    }

    // --- AMNESIA PROTOCOL ---
    if (elbowAngle >= 150.0 && rawFormState == 1 && !_isDown) {
      _hasFormBrokenThisRep = false; 
    }

    // --- DEBOUNCE LOGIC ---
    if (rawFormState == -1) {
      _consecutiveBadFrames++;
      _consecutiveGoodFrames = 0;
      if (_consecutiveBadFrames >= _debounceThreshold) {
        _publishedFormState = -1;
        _publishedFormError = rawFormError;
        _publishedFaultyJoints = Set.from(rawFaultyJoints);
        
        if (ttsVariations.isNotEmpty) {
          AudioService.instance.speakCorrection(ttsVariations);
        }
        
        _hasFormBrokenThisRep = true; // Permanently taints rep
      }
    } else {
      _consecutiveGoodFrames++;
      _consecutiveBadFrames = 0;
      if (_consecutiveGoodFrames >= _debounceThreshold) {
        _publishedFormState = 1;
        _publishedFormError = "";
        _publishedFaultyJoints = {};
      }
    }

    // 4. Strict Rep & Half-Rep Logic
    bool goodRep = false;
    bool badRep = false;
    String repFeedback = "";

    if (_isDown) {
      repFeedback = "Push up!";
      if (elbowAngle >= 160.0) {
        _isDown = false; 
        _lowestElbowAngle = 180.0; // Reset depth tracker
        
        if (_hasFormBrokenThisRep) {
          badRep = true; 
          repFeedback = "Rep invalid. Fix your form!";
        } else {
          goodRep = true; 
          repFeedback = "Perfect rep!";
        }
        _hasFormBrokenThisRep = false; 
      }
    } else {
      if (elbowAngle <= 90.0) {
        _isDown = true; 
        repFeedback = "Depth reached. Push!";
      } else {
        repFeedback = "Lower... hit 90 degrees.";

        // --- HALF REP DETECTION ---
        // If they lock out, but they never went low enough to trigger _isDown
        if (elbowAngle >= 150.0 && _lowestElbowAngle < 130.0) {
          AudioService.instance.speakCorrection([
            "Half rep. Go lower next time.",
            "Not low enough. Break 90 degrees.",
            "Chest to the floor. Don't short the rep."
          ]);
          _lowestElbowAngle = 180.0; // Reset to avoid spam
        }
      }
    }

    String finalFeedback = _publishedFormState == -1 ? _publishedFormError : repFeedback;

    return {
      'goodRepTriggered': goodRep,
      'badRepTriggered': badRep,
      'formState': _publishedFormState,
      'feedback': finalFeedback,
      'activeJoints': activeJoints,
      'faultyJoints': _publishedFaultyJoints, 
      'formScore': _smoothedFormScore,       
    };
  }

  Map<String, dynamic> _evaluateBicepCurl(Pose pose) {
    // Left identical for stability
    final landmarks = pose.landmarks;
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];

    if (leftShoulder == null || rightShoulder == null) return {'goodRepTriggered': false, 'badRepTriggered': false, 'formState': 0, 'feedback': "Full body not visible.", 'activeJoints': <PoseLandmarkType>{}, 'faultyJoints': <PoseLandmarkType>{}, 'formScore': 0.0};

    final bool isLeftVisible = leftShoulder.likelihood > rightShoulder.likelihood;
    final shoulder = isLeftVisible ? landmarks[PoseLandmarkType.leftShoulder] : landmarks[PoseLandmarkType.rightShoulder];
    final elbow = isLeftVisible ? landmarks[PoseLandmarkType.leftElbow] : landmarks[PoseLandmarkType.rightElbow];
    final wrist = isLeftVisible ? landmarks[PoseLandmarkType.leftWrist] : landmarks[PoseLandmarkType.rightWrist];
    final hip = isLeftVisible ? landmarks[PoseLandmarkType.leftHip] : landmarks[PoseLandmarkType.rightHip];

    final activeJoints = <PoseLandmarkType>{
      PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow, PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist, PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip, PoseLandmarkType.rightHip,
    };

    if (shoulder == null || elbow == null || wrist == null || hip == null || shoulder.likelihood < 0.5 || elbow.likelihood < 0.5) {
      return {'goodRepTriggered': false, 'badRepTriggered': false, 'formState': 0, 'feedback': "Align side profile to camera.", 'activeJoints': activeJoints, 'faultyJoints': <PoseLandmarkType>{}, 'formScore': 0.0};
    }

    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    final torsoLength = math.sqrt(math.pow(shoulder.x - hip.x, 2) + math.pow(shoulder.y - hip.y, 2));

    if (shoulderWidth > torsoLength * 0.6) {
      return {'goodRepTriggered': false, 'badRepTriggered': false, 'formState': 0, 'feedback': "Turn sideways! Front view is not supported.", 'activeJoints': activeJoints, 'faultyJoints': <PoseLandmarkType>{}, 'formScore': 0.0};
    }

    final elbowAngle = _calculateAngle(shoulder, elbow, wrist);
    final shoulderSwingAngle = _calculateAngle(hip, shoulder, elbow);

    double rawFormScore = ((35.0 - shoulderSwingAngle) / 20.0).clamp(0.0, 1.0);
    _smoothedFormScore = (_smoothedFormScore * 0.8) + (rawFormScore * 0.2);

    int rawFormState = 1; 
    String rawFormError = "";
    Set<PoseLandmarkType> rawFaultyJoints = {};
    List<String> ttsVariations = [];

    if (shoulderSwingAngle > 35.0) {
      rawFormState = -1;
      rawFormError = "Stop swinging.";
      rawFaultyJoints.addAll([PoseLandmarkType.leftHip, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.rightHip, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow]);
      ttsVariations = ["Keep elbows tucked! Stop swinging.", "Lock your elbows to your side.", "Don't swing the weight."];
    }

    if (elbowAngle >= 150.0 && rawFormState == 1 && !_isDown) {
      _hasFormBrokenThisRep = false; 
    }

    if (rawFormState == -1) {
      _consecutiveBadFrames++;
      _consecutiveGoodFrames = 0;
      if (_consecutiveBadFrames >= _debounceThreshold) {
        _publishedFormState = -1;
        _publishedFormError = rawFormError;
        _publishedFaultyJoints = Set.from(rawFaultyJoints);
        if (ttsVariations.isNotEmpty) AudioService.instance.speakCorrection(ttsVariations);
        _hasFormBrokenThisRep = true; 
      }
    } else {
      _consecutiveGoodFrames++;
      _consecutiveBadFrames = 0;
      if (_consecutiveGoodFrames >= _debounceThreshold) {
        _publishedFormState = 1;
        _publishedFormError = "";
        _publishedFaultyJoints = {};
      }
    }

    bool goodRep = false;
    bool badRep = false;
    String repFeedback = "";

    if (_isDown) {
      repFeedback = "Curl it up!";
      if (elbowAngle < 50.0) {
        _isDown = false; 
        if (_hasFormBrokenThisRep) {
          badRep = true;
          repFeedback = "Rep invalid. Stop swinging!";
        } else {
          goodRep = true;
          repFeedback = "Good squeeze!";
        }
        _hasFormBrokenThisRep = false;
      }
    } else {
      if (elbowAngle > 150.0) {
        _isDown = true; 
        repFeedback = "Fully extended. Curl!";
      } else {
        repFeedback = "Lower the weight fully.";
      }
    }

    String finalFeedback = _publishedFormState == -1 ? _publishedFormError : repFeedback;

    return {
      'goodRepTriggered': goodRep,
      'badRepTriggered': badRep,
      'formState': _publishedFormState,
      'feedback': finalFeedback,
      'activeJoints': activeJoints,
      'faultyJoints': _publishedFaultyJoints,
      'formScore': _smoothedFormScore,
    };
  }
}