import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../audio_service.dart';
import '../biomechanics_engine.dart';

class SquatEvaluator extends BaseEvaluator {
  double _lowestKneeAngle = 180.0;

  @override
  void reset() {
    super.reset();
    _lowestKneeAngle = 180.0;
  }

  @override
  Map<String, dynamic> evaluate(Pose pose) {
    final landmarks = pose.landmarks;
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];

    if (leftShoulder == null || rightShoulder == null) return {'goodRepTriggered': false, 'badRepTriggered': false, 'formState': 0, 'feedback': "Full body not visible.", 'activeJoints': <PoseLandmarkType>{}, 'faultyJoints': <PoseLandmarkType>{}, 'formScore': 0.0};

    final bool isLeftVisible = leftShoulder.likelihood > rightShoulder.likelihood;
    
    final shoulder = isLeftVisible ? landmarks[PoseLandmarkType.leftShoulder] : landmarks[PoseLandmarkType.rightShoulder];
    final hip = isLeftVisible ? landmarks[PoseLandmarkType.leftHip] : landmarks[PoseLandmarkType.rightHip];
    final knee = isLeftVisible ? landmarks[PoseLandmarkType.leftKnee] : landmarks[PoseLandmarkType.rightKnee];
    final ankle = isLeftVisible ? landmarks[PoseLandmarkType.leftAnkle] : landmarks[PoseLandmarkType.rightAnkle];

    final activeJoints = <PoseLandmarkType>{
      PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip, PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee,
      PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle,
    };

    if (shoulder == null || hip == null || knee == null || ankle == null ||
        shoulder.likelihood < 0.5 || hip.likelihood < 0.5 || knee.likelihood < 0.5 || ankle.likelihood < 0.5) {
      return {'goodRepTriggered': false, 'badRepTriggered': false, 'formState': 0, 'feedback': "Align side profile to camera.", 'activeJoints': activeJoints, 'faultyJoints': <PoseLandmarkType>{}, 'formScore': 0.0};
    }

    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    final torsoLength = math.sqrt(math.pow(shoulder.x - hip.x, 2) + math.pow(shoulder.y - hip.y, 2));

    final kneeFlexionAngle = calculateAngle(hip, knee, ankle);
    if (kneeFlexionAngle < _lowestKneeAngle) _lowestKneeAngle = kneeFlexionAngle;

    // --- NEW MATH: THE PARALLEL RATIO ---
    
    // 1. Trunk Angle from Vertical
    final trunkDx = (shoulder.x - hip.x).abs();
    final trunkDy = (shoulder.y - hip.y).abs();
    final trunkAngle = math.atan2(trunkDx, trunkDy) * 180 / math.pi;

    // 2. Tibia (Shin) Angle from Vertical
    final tibiaDx = (knee.x - ankle.x).abs();
    final tibiaDy = (knee.y - ankle.y).abs();
    final tibiaAngle = math.atan2(tibiaDx, tibiaDy) * 180 / math.pi;

    // 3. The Collapse Differential
    // A positive number means the torso is leaning further forward than the knees are tracking.
    final torsoCollapseDifferential = trunkAngle - tibiaAngle;

    // Smoothing Score (Based on depth)
    double rawFormScore = ((kneeFlexionAngle - 90.0) / 60.0).clamp(0.0, 1.0);
    smoothedFormScore = (smoothedFormScore * 0.8) + (rawFormScore * 0.2);

    int rawFormState = 1; 
    String rawFormError = "";
    Set<PoseLandmarkType> rawFaultyJoints = {};
    List<String> ttsVariations = [];

    // --- CLINICAL HEURISTICS ---
    
    if (shoulderWidth > torsoLength * 0.6) {
      rawFormState = -1;
      rawFaultyJoints.addAll(activeJoints);
      if (rawFormError.isEmpty) {
        rawFormError = "Face sideways.";
        ttsVariations = ["Turn sideways. I need to see your squat depth.", "Face sideways to the camera."];
      }
    }
    // Dynamic Torso Collapse (Replaces the rigid 50-degree rule)
    // Allows up to 20 degrees of natural mechanical variance between shin and torso
    else if (torsoCollapseDifferential > 20.0) {
      rawFormState = -1;
      rawFaultyJoints.addAll([PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee, PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle]);
      if (rawFormError.isEmpty) {
        rawFormError = "Chest is falling.";
        ttsVariations = [
          "Chest up. Keep your back parallel to your shins.", 
          "Don't fold forward.", 
          "Drop your hips, don't just bow forward."
        ];
      }
    }

    processFormState(
      rawFormState: rawFormState, 
      rawFormError: rawFormError, 
      rawFaultyJoints: rawFaultyJoints, 
      ttsVariations: ttsVariations, 
      amnesiaConditionMet: kneeFlexionAngle >= 160.0 
    );

    // --- START THE STOPWATCH ---
    if (kneeFlexionAngle < 150.0 && repMovementStartTime == null) {
      repMovementStartTime = DateTime.now();
    }

    bool goodRep = false;
    bool badRep = false;
    String repFeedback = "";

    if (isDown) {
      repFeedback = "Stand up!";
      if (kneeFlexionAngle >= 160.0) { 
        isDown = false; 
        
        // CHECK THE SPEED LIMIT (1.5s for Squats)
        bool isRushed = false;
        if (repMovementStartTime != null) {
          final durationMs = DateTime.now().difference(repMovementStartTime!).inMilliseconds;
          if (durationMs < 1500) isRushed = true; 
        }
        repMovementStartTime = null; 
        
        if (isRushed) {
          badRep = true;
          repFeedback = "Too fast! Control the rep.";
          AudioService.instance.speakCorrection(["Slow down the descent.", "Don't bounce out of the bottom."]);
        } else if (hasFormBrokenThisRep) {
          badRep = true;
          repFeedback = "Rep invalid. Watch form!";
        } else {
          goodRep = true;
          repFeedback = "Great depth!";
        }
        _lowestKneeAngle = 180.0; 
      }
    } else {
      if (kneeFlexionAngle <= 90.0) { 
        isDown = true; 
        repFeedback = "Depth reached. Stand!";
      } else {
        repFeedback = "Drop lower...";
        
        if (kneeFlexionAngle > 150.0 && _lowestKneeAngle < 130.0) {
          AudioService.instance.speakCorrection([
            "Half rep. Break parallel.",
            "Go lower on the next one.",
            "Squat deeper. Drop your hips."
          ]);
          _lowestKneeAngle = 180.0; 
        }
      }
    }

    return {
      'goodRepTriggered': goodRep, 'badRepTriggered': badRep,
      'formState': publishedFormState, 'feedback': publishedFormState == -1 ? publishedFormError : repFeedback,
      'activeJoints': activeJoints, 'faultyJoints': publishedFaultyJoints, 'formScore': smoothedFormScore,
    };
  }
}