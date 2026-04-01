import 'dart:math' as math;
import 'dart:ui';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
// AUDIO SERVICE IMPORT DELETED
import '../biomechanics_engine.dart';

class BenchDipEvaluator extends BaseEvaluator {
  @override
  Map<String, dynamic> evaluate(Pose pose) {
    final landmarks = pose.landmarks;
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];

    // INJECTION: Added 'audioCue': null
    if (leftShoulder == null || rightShoulder == null) return {'goodRepTriggered': false, 'badRepTriggered': false, 'formState': 0, 'feedback': "Full body not visible.", 'activeJoints': <PoseLandmarkType>{}, 'faultyJoints': <PoseLandmarkType>{}, 'formScore': 0.0, 'audioCue': null};

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

    // INJECTION: Added 'audioCue': null
    if (shoulder == null || elbow == null || wrist == null || hip == null || knee == null || 
        shoulder.likelihood < 0.5 || hip.likelihood < 0.5) {
      return {'goodRepTriggered': false, 'badRepTriggered': false, 'formState': 0, 'feedback': "Align side profile to camera.", 'activeJoints': activeJoints, 'faultyJoints': <PoseLandmarkType>{}, 'formScore': 0.0, 'audioCue': null};
    }

    // --- 1. MATH & GEOMETRY ---
    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    final torsoLength = math.sqrt(math.pow(shoulder.x - hip.x, 2) + math.pow(shoulder.y - hip.y, 2));
    
    final horizontalDrift = (hip.x - wrist.x).abs(); 

    final trunkDx = (shoulder.x - hip.x).abs();
    final trunkDy = (shoulder.y - hip.y).abs();
    final trunkAngle = math.atan2(trunkDx, trunkDy) * 180 / math.pi;

    final elbowAngle = calculateAngle(shoulder, elbow, wrist); 
    if (elbowAngle < lowestElbowAngle) lowestElbowAngle = elbowAngle;

    double elbowScore = ((elbowAngle - 90.0) / 65.0).clamp(0.0, 1.0);
    double rawFormScore = elbowScore;
    smoothedFormScore = (smoothedFormScore * 0.8) + (rawFormScore * 0.2);

    int rawFormState = 1; 
    String rawFormError = "";
    Set<PoseLandmarkType> rawFaultyJoints = {};
    List<String> ttsVariations = [];
    bool triggerInstantKill = false;

    // --- 2. CLINICAL HEURISTICS ---

    if (shoulderWidth > torsoLength * 0.45) {
      rawFormState = -1;
      triggerInstantKill = true; 
      rawFaultyJoints.addAll(activeJoints); 
      if (rawFormError.isEmpty) {
        rawFormError = "Turn sideways.";
        ttsVariations = ["Strict side profile required.", "Please face the side completely."];
      }
    } 
    else if (horizontalDrift > torsoLength * 0.50) { 
      rawFormState = -1;
      rawFaultyJoints.addAll([PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftWrist, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, PoseLandmarkType.rightWrist]);
      if (rawFormError.isEmpty) {
        rawFormError = "Hips drifting forward.";
        ttsVariations = [
          "Keep your back close to the bench.", 
          "Don't let your hips drift forward.", 
          "Slide your back down the bench."
        ];
      }
    }
    else if (elbowAngle < 80.0) {
      rawFormState = -1;
      rawFaultyJoints.addAll([PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow]);
      if (rawFormError.isEmpty) {
        rawFormError = "Going too deep.";
        ttsVariations = [
          "Too deep! Protect your shoulders.", 
          "Stop at 90 degrees.", 
          "Don't drop below your elbows."
        ];
      }
    }
    else if (trunkAngle > 55.0) {
      rawFormState = -1;
      rawFaultyJoints.addAll([PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip]);
      if (rawFormError.isEmpty) {
        rawFormError = "Torso leaning too far.";
        ttsVariations = ["Keep your chest up.", "Sit up straighter."];
      }
    } 

    // INJECTION: Capture the audio cue payload
    List<String>? audioCuePayload = processFormState(
      rawFormState: rawFormState, 
      rawFormError: rawFormError, 
      rawFaultyJoints: rawFaultyJoints, 
      ttsVariations: ttsVariations, 
      amnesiaConditionMet: elbowAngle >= 150.0,
      isInstantFault: triggerInstantKill
    );

    // --- START THE STOPWATCH ---
    if (elbowAngle < 145.0 && repMovementStartTime == null) {
      repMovementStartTime = DateTime.now();
    }

    // --- 3. STRICT REP LOGIC ---
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
          // AUDIO INJECTION NO. 1
          audioCuePayload ??= ["Slow down.", "Control your speed."];
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

        if (elbowAngle >= 155.0 && lowestElbowAngle <= 130.0 && lowestElbowAngle > 100.0) {
          if (publishedFormState != -1) {
            // AUDIO INJECTION NO. 2
            audioCuePayload ??= [
              "Partial repetition. Go lower.", 
              "Not deep enough.", 
              "Break 90 degrees."
            ];
          }
          lowestElbowAngle = 180.0; 
        }
      }
    }

    // INJECTION: Final pipeline completion
    return {
      'goodRepTriggered': goodRep, 'badRepTriggered': badRep,
      'formState': publishedFormState, 'feedback': publishedFormState == -1 ? publishedFormError : repFeedback,
      'activeJoints': activeJoints, 'faultyJoints': publishedFaultyJoints, 'formScore': smoothedFormScore,
      'audioCue': audioCuePayload,
    };
  }
}