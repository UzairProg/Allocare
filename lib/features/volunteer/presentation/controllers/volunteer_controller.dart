import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/volunteer_service.dart';

// Model for Volunteer State
class VolunteerState {
  final bool isOnDuty;
  final String? activeTaskId;
  final List<String> completedTaskIds;

  const VolunteerState({
    this.isOnDuty = true,
    this.activeTaskId,
    this.completedTaskIds = const [],
  });

  VolunteerState copyWith({
    bool? isOnDuty,
    String? activeTaskId,
    List<String>? completedTaskIds,
  }) {
    return VolunteerState(
      isOnDuty: isOnDuty ?? this.isOnDuty,
      activeTaskId: activeTaskId ?? this.activeTaskId,
      completedTaskIds: completedTaskIds ?? this.completedTaskIds,
    );
  }
}

// Controller for managing Volunteer-specific UI states
class VolunteerController extends StateNotifier<VolunteerState> {
  VolunteerController(this._ref) : super(const VolunteerState());

  final Ref _ref;

  Future<void> toggleDutyStatus() async {
    final volunteer = _ref.read(currentVolunteerProvider).asData?.value;
    if (volunteer != null) {
      final newStatus = !volunteer.isActiveOnField;
      await _ref.read(volunteerServiceProvider).toggleActiveOnField(volunteer.uid, newStatus);
    } else {
      state = state.copyWith(isOnDuty: !state.isOnDuty);
    }
  }

  void acceptTask(String taskId) {
    state = state.copyWith(activeTaskId: taskId);
  }

  void completeActiveTask() {
    if (state.activeTaskId != null) {
      state = state.copyWith(
        completedTaskIds: [...state.completedTaskIds, state.activeTaskId!],
        activeTaskId: null,
      );
    }
  }

  void cancelActiveTask() {
    state = state.copyWith(activeTaskId: null);
  }
}

final volunteerControllerProvider = StateNotifierProvider<VolunteerController, VolunteerState>((ref) {
  return VolunteerController(ref);
});

final volunteerTabControllerProvider = StateProvider<int>((ref) => 0);

final hasIncomingTaskProvider = StateProvider<bool>((ref) => false);
