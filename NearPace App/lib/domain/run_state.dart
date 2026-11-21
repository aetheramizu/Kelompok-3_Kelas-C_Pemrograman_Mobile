/// Recording state machine. Sealed so every UI switch must handle every state.
sealed class RunState {
  const RunState();
}

final class RunIdle extends RunState {
  const RunIdle();
}

final class RunPreparing extends RunState {
  const RunPreparing();
}

final class RunActive extends RunState {
  const RunActive({required this.paused});

  final bool paused;
}

final class RunStopping extends RunState {
  const RunStopping();
}

final class RunFailed extends RunState {
  const RunFailed(this.message);

  final String message;
}
