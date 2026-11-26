import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../tour/tour_progress.dart';

/// The one question asked on first launch: look around with sample data, or
/// start with an empty ledger. Asked once and remembered.
enum StartChoice {
  sample,
  fresh;

  static StartChoice? parse(String? v) => switch (v) {
    'sample' => StartChoice.sample,
    'fresh' => StartChoice.fresh,
    _ => null,
  };
}

const startChoiceKey = 'start.choice';

class StartChoiceController extends Notifier<StartChoice?> {
  @override
  StartChoice? build() {
    _ready = _load();
    return null;
  }

  late Future<void> _ready;
  Future<void> get ready => _ready;

  Future<void> _load() async {
    try {
      final v = StartChoice.parse(
        await ref.read(tourKvProvider).read(startChoiceKey),
      );
      if (ref.mounted && v != null) state = v;
    } catch (_) {}
  }

  /// Remembers the choice and points the app at the matching data: sample
  /// data runs on the built-in demo stores, fresh on the on-device ledger.
  ///
  /// Returns false only when "fresh" was chosen but there is no on-device
  /// ledger to show (previews, web): the app keeps showing sample data.
  Future<bool> choose(StartChoice c) async {
    state = c;
    final holder = ref.read(databaseHolderProvider.notifier);
    var ok = true;
    if (c == StartChoice.sample) {
      holder.useSample();
    } else {
      ok = holder.useOwn();
    }
    try {
      await ref.read(tourKvProvider).write(startChoiceKey, c.name);
    } catch (_) {}
    return ok;
  }
}

final startChoiceProvider =
    NotifierProvider<StartChoiceController, StartChoice?>(
      StartChoiceController.new,
    );
