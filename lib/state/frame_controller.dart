import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class FrameState {
  final bool isUserInFrame;
  final int formState;
  final String feedbackMessage;
  final double formScore;
  final Set<PoseLandmarkType> faultyJoints;

  FrameState({
    this.isUserInFrame = false,
    this.formState = 0,
    this.feedbackMessage = "Position yourself in frame.",
    this.formScore = 1.0,
    this.faultyJoints = const {},
  });

  FrameState copyWith({
    bool? isUserInFrame,
    int? formState,
    String? feedbackMessage,
    double? formScore,
    Set<PoseLandmarkType>? faultyJoints,
  }) {
    return FrameState(
      isUserInFrame: isUserInFrame ?? this.isUserInFrame,
      formState: formState ?? this.formState,
      feedbackMessage: feedbackMessage ?? this.feedbackMessage,
      formScore: formScore ?? this.formScore,
      faultyJoints: faultyJoints ?? this.faultyJoints,
    );
  }
}

// UPGRADED TO MODERN NOTIFIER API
class FrameController extends Notifier<FrameState> {
  
  @override
  FrameState build() {
    return FrameState(); // Initial state
  }

  void updateFrameData({
    required bool isUserInFrame,
    required int formState,
    required String feedbackMessage,
    required double formScore,
    required Set<PoseLandmarkType> faultyJoints,
  }) {
    state = state.copyWith(
      isUserInFrame: isUserInFrame,
      formState: formState,
      feedbackMessage: feedbackMessage,
      formScore: formScore,
      faultyJoints: faultyJoints,
    );
  }

  void forceFeedback(String message, int formState) {
    state = state.copyWith(feedbackMessage: message, formState: formState);
  }
}

// UPGRADED TO MODERN NOTIFIERPROVIDER
final frameProvider = NotifierProvider<FrameController, FrameState>(() {
  return FrameController();
});