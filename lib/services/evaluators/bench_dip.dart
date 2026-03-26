import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../audio_service.dart';
import '../biomechanics_engine.dart';

class BenchDipEvaluator extends BaseEvaluator {
  @override
  Map<String, dynamic> evaluate(Pose pose) {
    final landmarks = pose.landmarks;
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];

    if (leftShoulder == null || rightShoulder == null) return {'goodRepTriggered': false, 'badRepTriggered': false, 'formState': 0, 'feedback': "Full body not visible.", 'activeJoints': <PoseLandmarkType>{}, 'faultyJoints': <PoseLandmarkType>{}, 'formScore': 0.0};

    final bool isLeftVisible = leftShoulder.likelihood > rightShoulder.likelihood;
    
    final shoulder = isLeftVisible ? landmarks[PoseLandmarkType.leftShoulder] : landmarks[PoseLandmarkType.rightShoulder];
    final elbow = isLeftVisible ? landmarks[PoseLandmarkType.leftElbow] : landmarks[PoseLandmarkType.rightElbow];
    final wrist = isLeftVisible ? landmarks[PoseLandmarkType.leftWrist] : landmarks[PoseLandmarkType.rightWrist];
    final hip = isLeftVisible ? landmarks[PoseLandmarkType.leftHip] : landmarks[PoseLandmarkType.rightHip];
    final knee = isLeftVisible ? landmarks[PoseLandmarkType.leftKnee] : landmarks[PoseLandmarkType.rightKnee]; 

    final activeJoints = <PoseLandmarkType>{
      PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftElbow, PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist, PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftHip, PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee,
    };

    if (shoulder == null || elbow == null || wrist == null || hip == null || knee == null || 
        shoulder.likelihood < 0.5 || hip.likelihood < 0.5) {
      return {'goodRepTriggered': false, 'badRepTriggered': false, 'formState': 0, 'feedback': "Align side profile to camera.", 'activeJoints': activeJoints, 'faultyJoints': <PoseLandmarkType>{}, 'formScore': 0.0};
    }

    // 1. Math & Geometry
    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    final torsoLength = math.sqrt(math.pow(shoulder.x - hip.x, 2) + math.pow(shoulder.y - hip.y, 2));
    final horizontalDrift = (hip.x - wrist.x).abs(); 

    // Calculate Trunk Angle from absolute vertical
    final trunkDx = (shoulder.x - hip.x).abs();
    final trunkDy = (shoulder.y - hip.y).abs();
    final trunkAngle = math.atan2(trunkDx, trunkDy) * 180 / math.pi;

    final elbowAngle = calculateAngle(shoulder, elbow, wrist); 
    if (elbowAngle < lowestElbowAngle) lowestElbowAngle = elbowAngle;

    // 2. Thermometer Smoothing
    double elbowScore = ((elbowAngle - 100.0) / 60.0).clamp(0.0, 1.0);
    double rawFormScore = elbowScore;
    smoothedFormScore = (smoothedFormScore * 0.8) + (rawFormScore * 0.2);

    int rawFormState = 1; 
    String rawFormError = "";
    Set<PoseLandmarkType> rawFaultyJoints = {};
    List<String> ttsVariations = [];
    bool triggerInstantKill = false;

    // --- 3. CLINICAL HEURISTICS ---

    // A. Strict Sideways Profile (Tightened to 0.45)
    if (shoulderWidth > torsoLength * 0.45) {
      rawFormState = -1;
      triggerInstantKill = true; // Instantly flags if they turn to the front
      rawFaultyJoints.addAll(activeJoints); 
      if (rawFormError.isEmpty) {
        rawFormError = "Turn sideways.";
        ttsVariations = [
          "Strict side profile required.", 
          "Please face the side completely.",
          "Turn 90 degrees."
        ];
      }
    } 
    // B. Torso Lean (Massively relaxed from 45 to 60 degrees)
    else if (trunkAngle > 60.0) {
      rawFormState = -1;
      rawFaultyJoints.addAll([PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip]);
      if (rawFormError.isEmpty) {
        rawFormError = "Torso leaning too far.";
        ttsVariations = [
          "Keep your chest up.", 
          "Don't lean so far forward.",
          "Sit up straighter."
        ];
      }
    } 
    // C. Hips Drifting (Relaxed from 0.55 to 0.80 to allow varied foot placements)
    else if (horizontalDrift > torsoLength * 0.80) { 
      rawFormState = -1;
      rawFaultyJoints.addAll([PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip]);
      if (rawFormError.isEmpty) {
        rawFormError = "Hips drifting forward.";
        ttsVariations = [
          "Stay closer to the bench.", 
          "Don't drift forward.", 
          "Keep your back near the bench."
        ];
      }
    }

    processFormState(
      rawFormState: rawFormState, 
      rawFormError: rawFormError, 
      rawFaultyJoints: rawFaultyJoints, 
      ttsVariations: ttsVariations, 
      amnesiaConditionMet: elbowAngle >= 145.0,
      isInstantFault: triggerInstantKill
    );

    // --- START THE STOPWATCH ---
    if (elbowAngle < 145.0 && repMovementStartTime == null) {
      repMovementStartTime = DateTime.now();
    }

    // --- STRICT REP LOGIC ---
    bool goodRep = false;
    bool badRep = false;
    String repFeedback = "";

    if (isDown) {
      repFeedback = "Push up!";
      if (elbowAngle >= 155.0) {
        isDown = false; 
        
        bool isRushed = false;
        if (repMovementStartTime != null) {
          final durationMs = DateTime.now().difference(repMovementStartTime!).inMilliseconds;
          if (durationMs < 1500) isRushed = true; 
        }
        repMovementStartTime = null; 
        
        if (isRushed) {
          badRep = true; 
          repFeedback = "Too fast! Control the rep.";
          AudioService.instance.speakCorrection([
            "Slow down.", 
            "Don't bounce out of the bottom.",
            "Control your speed."
          ]);
        } else if (hasFormBrokenThisRep) {
          badRep = true; 
          repFeedback = "Rep invalid. Watch your form!";
        } else {
          goodRep = true; 
          repFeedback = "Perfect rep!";
        }
        lowestElbowAngle = 180.0; 
      }
    } else {
      if (elbowAngle <= 100.0) {
        isDown = true; 
        repFeedback = "Depth reached. Push!";
      } else {
        repFeedback = "Lower yourself.";

        // Half-rep detection
        if (elbowAngle >= 145.0 && lowestElbowAngle < 120.0) {
          if (publishedFormState != -1) {
            AudioService.instance.speakCorrection([
              "Partial repetition. Go lower.", 
              "Not deep enough.", 
              "Drop your hips more."
            ]);
          }
          lowestElbowAngle = 180.0; 
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