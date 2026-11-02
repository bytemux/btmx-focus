import Observation

/// Runs `track` now and again after every change to the observable state it
/// read, handing each non-nil result to `apply`, whose reads aren't tracked.
/// Capture owners weakly in `track` (e.g. `{ [weak self] in self?.draw() }`):
/// once they are gone it reads nothing, so nothing re-arms and the loop ends.
@MainActor
func observeChanges<Value>(
    _ track: @escaping @MainActor () -> Value?,
    apply: @escaping @MainActor (Value) -> Void = { _ in }
) {
    let value = withObservationTracking(track) {
        Task { @MainActor in observeChanges(track, apply: apply) }
    }
    if let value {
        apply(value)
    }
}
