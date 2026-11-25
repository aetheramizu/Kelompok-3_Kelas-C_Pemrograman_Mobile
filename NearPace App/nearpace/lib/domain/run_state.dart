/// Recording state machine. Sealed so every UI switch must handle every state.
sealed class RunState {
  const RunState();
}

final class RunIdle extends RunState {
  const RunIdle();
}

final class RunPreparing extends RunState {
  const RunPreparing({this.message = 'Acquiring GPS signal...'});

  final String message;
}

final class RunActive extends RunState {
  const RunActive({required this.paused});

  final bool paused;
}

final class RunStopping extends RunState {
  const RunStopping();
}

enum RunFailureReason {
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  unknown,
}

final class RunFailed extends RunState {
  const RunFailed(this.message, {this.reason = RunFailureReason.unknown});

  final String message;
  final RunFailureReason reason;
}
