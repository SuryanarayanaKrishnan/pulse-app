/// Hybrid logical clock timestamp: wall milliseconds, a counter that breaks
/// ties inside one millisecond (or when the wall clock stalls or goes back),
/// and the id of the device that issued it. The device id makes every
/// timestamp globally unique, so ordering is total and merges converge.
class Hlc implements Comparable<Hlc> {
  const Hlc(this.wall, this.counter, this.device);

  final int wall;
  final int counter;
  final String device;

  static const maxCounter = 0xFFFF;

  /// Fixed-width so plain string comparison equals [compareTo].
  @override
  String toString() =>
      '${wall.toString().padLeft(13, '0')}-${counter.toRadixString(16).padLeft(4, '0')}-$device';

  static Hlc parse(String s) {
    final a = s.indexOf('-');
    final b = a < 0 ? -1 : s.indexOf('-', a + 1);
    if (a != 13 || b != 18 || b + 1 >= s.length) {
      throw FormatException('Bad timestamp');
    }
    return Hlc(
      int.parse(s.substring(0, a)),
      int.parse(s.substring(a + 1, b), radix: 16),
      s.substring(b + 1),
    );
  }

  @override
  int compareTo(Hlc other) {
    final o = other;
    final w = wall.compareTo(o.wall);
    if (w != 0) return w;
    final c = counter.compareTo(o.counter);
    if (c != 0) return c;
    return device.compareTo(o.device);
  }

  bool operator >(Hlc other) => compareTo(other) > 0;
  bool operator <(Hlc other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      other.wall == wall &&
      other.counter == counter &&
      other.device == device;

  @override
  int get hashCode => Object.hash(wall, counter, device);
}

/// The clock of one device. Pure: the caller passes the wall time.
class HlcClock {
  // ignore_for_file: prefer_initializing_formals
  HlcClock(this.device, {int wall = 0, int counter = 0})
    : _wall = wall,
      _counter = counter;

  final String device;
  int _wall;
  int _counter;

  /// A remote clock this far ahead of ours is clamped, so one device with a
  /// wrong clock cannot push every later write of the others into the future.
  static const maxDrift = Duration(days: 1);

  int get wall => _wall;
  int get counter => _counter;

  /// A fresh timestamp for a local event; strictly greater than every
  /// timestamp this clock has issued or observed.
  Hlc tick(int nowMs) {
    if (nowMs > _wall) {
      _wall = nowMs;
      _counter = 0;
    } else {
      _counter++;
      if (_counter > Hlc.maxCounter) {
        _wall++;
        _counter = 0;
      }
    }
    return Hlc(_wall, _counter, device);
  }

  /// Moves the clock past a timestamp seen on another device.
  void observe(Hlc remote, int nowMs) {
    final limit = nowMs + maxDrift.inMilliseconds;
    final rw = remote.wall > limit ? limit : remote.wall;
    final rc = remote.wall > limit ? 0 : remote.counter;
    if (rw > _wall) {
      _wall = rw;
      _counter = rc;
    } else if (rw == _wall && rc > _counter) {
      _counter = rc;
    }
  }
}
