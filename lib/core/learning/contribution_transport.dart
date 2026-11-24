import 'contribution.dart';

/// How a batch leaves the phone. The real HTTP implementation is not part of
/// this build (see `docs/LEARNING.md` for the endpoint contract); until one is
/// configured the app uses [DisabledContributionTransport] and nothing is sent.
abstract class ContributionTransport {
  /// False when no endpoint is configured. A disabled transport is never
  /// asked to send, and queued data is kept (or discarded on opt-out).
  bool get enabled;

  /// Uploads one batch. Returns true only if the server accepted it; any
  /// error returns false so the batch is retried later.
  Future<bool> send(ContributionBatch batch);
}

/// The default: sends nothing.
class DisabledContributionTransport implements ContributionTransport {
  const DisabledContributionTransport();

  @override
  bool get enabled => false;

  @override
  Future<bool> send(ContributionBatch batch) async => false;
}

/// In-memory stand-in for tests: records what would have been uploaded.
class MemoryContributionTransport implements ContributionTransport {
  MemoryContributionTransport({this.accept = true});

  /// Set false to simulate a server or network failure.
  bool accept;
  final received = <Map<String, Object>>[];

  @override
  bool get enabled => true;

  @override
  Future<bool> send(ContributionBatch batch) async {
    if (!accept) return false;
    received.add(batch.toJson());
    return true;
  }
}
