import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/bugreport/shake_detector.dart';

const _rest = (x: 0.0, y: 0.0, z: 9.8);
const _jolt = (x: 30.0, y: 5.0, z: 9.8); // about 3.2 g

void main() {
  late StreamController<Accel> sensor;
  late DateTime clock;
  late int shakes;
  late ShakeListener listener;

  void tick(Accel a, [int ms = 120]) {
    clock = clock.add(Duration(milliseconds: ms));
    sensor.add(a);
  }

  setUp(() {
    sensor = StreamController<Accel>.broadcast(sync: true);
    clock = DateTime(2026, 1, 1);
    shakes = 0;
    listener = ShakeListener(
      source: () => sensor.stream,
      onShake: () => shakes++,
      now: () => clock,
    );
  });
  tearDown(() async {
    listener.stop();
    await sensor.close();
  });

  test('a phone at rest or a slow walk never fires', () {
    listener.start();
    for (var i = 0; i < 100; i++) {
      tick(i.isEven ? _rest : (x: 4.0, y: 2.0, z: 11.0), 50);
    }
    expect(shakes, 0);
  });

  test('one bump is not a shake', () {
    listener.start();
    tick(_jolt);
    tick(_rest);
    expect(shakes, 0);
  });

  test('three jolts inside the window fire once', () {
    listener.start();
    tick(_jolt);
    tick(_jolt);
    tick(_jolt);
    expect(shakes, 1);
  });

  test('jolts spread too far apart do not count', () {
    listener.start();
    tick(_jolt, 700);
    tick(_jolt, 700);
    tick(_jolt, 700);
    expect(shakes, 0);
  });

  test('samples of the same jolt are counted once', () {
    listener.start();
    for (var i = 0; i < 6; i++) {
      tick(_jolt, 20);
    }
    expect(shakes, 0);
  });

  test(
    'debounce: a continued shake fires once, then again after the cooldown',
    () {
      listener.start();
      for (var i = 0; i < 9; i++) {
        tick(_jolt); // 9 jolts over ~1 s
      }
      expect(shakes, 1);
      for (var i = 0; i < 3; i++) {
        tick(_jolt, 200);
      }
      expect(shakes, 1, reason: 'still cooling down');
      clock = clock.add(const Duration(seconds: 4));
      for (var i = 0; i < 3; i++) {
        tick(_jolt);
      }
      expect(shakes, 2);
    },
  );

  test('stopped (app in background) means nothing fires', () {
    listener.start();
    listener.stop();
    expect(listener.running, isFalse);
    for (var i = 0; i < 5; i++) {
      tick(_jolt);
    }
    expect(shakes, 0);
    expect(sensor.hasListener, isFalse, reason: 'sensor released');
  });

  test('start twice listens once; sensor errors are ignored', () {
    listener.start();
    listener.start();
    sensor.addError(StateError('no sensor'));
    for (var i = 0; i < 3; i++) {
      tick(_jolt);
    }
    expect(shakes, 1);
  });

  test('force is in g', () {
    expect(ShakeDetector.force(_rest), closeTo(1.0, 0.01));
  });
}
