import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class BiomechanicsEngine {
  static final BiomechanicsEngine instance = BiomechanicsEngine._internal();
  BiomechanicsEngine._internal();

  bool _isDown = false;

  void reset() {
    _isDown = false;
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
      'repTriggered': false,
      'formState': 0,
      'feedback': "Position yourself in frame.",
      'activeJoints': <PoseLandmarkType>{},
      'faultyJoints': <PoseLandmarkType>{}, // NEW: Tracks the exact failing limbs
      'formScore': 1.0,                     // NEW: Float between 0.0 and 1.0 for the thermometer
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
      return {'repTriggered': false, 'formState': 0, 'feedback': "Full body not visible.", 'activeJoints': <PoseLandmarkType>{}, 'faultyJoints': <PoseLandmarkType>{}, 'formScore': 0.0};
    }

    final bool isLeftVisible = leftShoulder.likelihood > rightShoulder.likelihood;

    final shoulder = isLeftVisible ? landmarks[PoseLandmarkType.leftShoulder] : landmarks[PoseLandmarkType.rightShoulder];
    final elbow = isLeftVisible ? landmarks[PoseLandmarkType.leftElbow] : landmarks[PoseLandmarkType.rightElbow];
    final wrist = isLeftVisible ? landmarks[PoseLandmarkType.leftWrist] : landmarks[PoseLandmarkType.rightWrist];
    final hip = isLeftVisible ? landmarks[PoseLandmarkType.leftHip] : landmarks[PoseLandmarkType.rightHip];
    final ankle = isLeftVisible ? landmarks[PoseLandmarkType.leftAnkle] : landmarks[PoseLandmarkType.rightAnkle];

    final activeJoints = <PoseLandmarkType>{
      PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow, PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist, PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip, PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle,
    };

    if (shoulder == null || elbow == null || wrist == null || hip == null || ankle == null ||
        shoulder.likelihood < 0.5 || hip.likelihood < 0.5 || ankle.likelihood < 0.5) {
      return {'repTriggered': false, 'formState': 0, 'feedback': "Align side profile to camera.", 'activeJoints': activeJoints, 'faultyJoints': <PoseLandmarkType>{}, 'formScore': 0.0};
    }

    // 1. Angles
    final coreAngle = _calculateAngle(shoulder, hip, ankle);
    final elbowAngle = _calculateAngle(shoulder, elbow, wrist);
    final shoulderAngle = _calculateAngle(hip, shoulder, elbow);

    // 2. Continuous Math (The Thermometer)
    // Core perfect = 160+. Fails at 140.
    double coreScore = ((coreAngle - 140.0) / 20.0).clamp(0.0, 1.0);
    // Shoulder perfect = 90. Fails at 110.
    double shoulderScore = ((110.0 - shoulderAngle) / 20.0).clamp(0.0, 1.0);
    
    // The total form score takes the lowest (worst) metric.
    double formScore = math.min(coreScore, shoulderScore);

    // 3. Heuristic Enforcement & Limb Coloring
    Set<PoseLandmarkType> faultyJoints = {};
    int formState = 1; 
    String feedback = "Good posture. Lower to 90 degrees.";

    if (coreAngle < 160.0) {
      formState = -1;
      feedback = "Keep your spine rigid! Hips are sagging.";
      // Color the Torso & Legs RED
      faultyJoints.addAll([PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftAnkle, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, PoseLandmarkType.rightAnkle]);
    } else if (shoulderAngle > 100.0) {
      formState = -1;
      feedback = "Hands too far forward. Stack wrists under shoulders.";
      // Color the Arm & Torso RED
      faultyJoints.addAll([PoseLandmarkType.leftHip, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.rightHip, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow]);
    }

    // 4. Rep Logic
    bool repTriggered = false;
    if (_isDown) {
      feedback = formState == -1 ? feedback : "Push up!";
      if (elbowAngle >= 160.0) {
        _isDown = false; 
        repTriggered = true; 
        feedback = "Perfect rep!";
      }
    } else {
      if (elbowAngle <= 90.0) {
        _isDown = true; 
        feedback = formState == -1 ? feedback : "Depth reached. Push!";
      } else {
        feedback = formState == -1 ? feedback : "Lower... hit 90 degrees.";
      }
    }

    return {
      'repTriggered': repTriggered,
      'formState': formState,
      'feedback': feedback,
      'activeJoints': activeJoints,
      'faultyJoints': faultyJoints, // Passes exactly which limbs to paint red
      'formScore': formScore,       // Passes the thermometer percentage
    };
  }

  Map<String, dynamic> _evaluateBicepCurl(Pose pose) {
    final landmarks = pose.landmarks;
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];

    if (leftShoulder == null || rightShoulder == null) {
      return {'repTriggered': false, 'formState': 0, 'feedback': "Full body not visible.", 'activeJoints': <PoseLandmarkType>{}, 'faultyJoints': <PoseLandmarkType>{}, 'formScore': 0.0};
    }

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
      return {'repTriggered': false, 'formState': 0, 'feedback': "Align side profile to camera.", 'activeJoints': activeJoints, 'faultyJoints': <PoseLandmarkType>{}, 'formScore': 0.0};
    }

    final elbowAngle = _calculateAngle(shoulder, elbow, wrist);
    final shoulderSwingAngle = _calculateAngle(hip, shoulder, elbow);

    // Form Score Math: Swing perfect = 15. Fails at 35.
    double formScore = ((35.0 - shoulderSwingAngle) / 20.0).clamp(0.0, 1.0);

    Set<PoseLandmarkType> faultyJoints = {};
    int formState = 1; 
    String feedback = "Good posture.";

    if (shoulderSwingAngle > 35.0) {
      formState = -1;
      feedback = "Keep elbows tucked! Stop swinging.";
      faultyJoints.addAll([PoseLandmarkType.leftHip, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.rightHip, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow]);
    }

    bool repTriggered = false;
    if (_isDown) {
      feedback = formState == -1 ? feedback : "Curl it up!";
      if (elbowAngle < 50.0) {
        _isDown = false; 
        repTriggered = true; 
        feedback = "Good squeeze!";
      }
    } else {
      if (elbowAngle > 150.0) {
        _isDown = true; 
        feedback = formState == -1 ? feedback : "Fully extended. Curl!";
      } else {
        feedback = formState == -1 ? feedback : "Lower the weight fully.";
      }
    }

    return {
      'repTriggered': repTriggered,
      'formState': formState,
      'feedback': feedback,
      'activeJoints': activeJoints,
      'faultyJoints': faultyJoints,
      'formScore': formScore,
    };
  }
}