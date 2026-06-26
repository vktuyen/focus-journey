// Deterministic unit tests for the real (channel-backed) visibility controller.
//
// Scope: the snapshot decode (start → initial per-surface readings), the
// EventChannel stream decode + de-dup (NFR-1), malformed-payload safety (a bad
// event is ignored, never throws/feeds a wrong type), and the
// missing-plugin/unsupported-build fallback (start does not throw; defaults to
// visible so the scene animates). Drives both channels via the test binary
// messenger so no real OS is touched.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_journey/features/window_visibility/data/method_channel_window_visibility_controller.dart';
import 'package:focus_journey/features/window_visibility/domain/surface_visibility.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel(
    MethodChannelWindowVisibilityController.methodChannelName,
  );
  const eventChannel = EventChannel(
    MethodChannelWindowVisibilityController.eventChannelName,
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late MethodChannelWindowVisibilityController controller;

  setUp(() {
    controller = MethodChannelWindowVisibilityController();
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockStreamHandler(eventChannel, null);
    await controller.dispose();
  });

  /// Feeds one event up the EventChannel as the native side would.
  void sendEvent(MockStreamHandlerEventSink sink, Object? payload) {
    sink.success(payload);
  }

  test('start ingests the snapshot list into per-surface readings', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      expect(call.method, MethodChannelWindowVisibilityController.methodStart);
      return <Object?>[
        <Object?, Object?>{'surface': 'main', 'visible': true},
        <Object?, Object?>{'surface': 'pip', 'visible': false},
      ];
    });

    await controller.start();

    expect(controller.isVisible(WindowSurface.main), isTrue);
    expect(controller.isVisible(WindowSurface.pip), isFalse);
  });

  test(
    'decodes + de-dups EventChannel stream emissions (AC-4/NFR-1)',
    () async {
      messenger.setMockMethodCallHandler(
        methodChannel,
        (call) async => <Object?>[],
      );

      late MockStreamHandlerEventSink sink;
      messenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (args, eventSink) => sink = eventSink,
        ),
      );

      final events = <SurfaceVisibility>[];
      final sub = controller.changes.listen(events.add);

      await controller.start();
      await Future<void>.delayed(Duration.zero);

      sendEvent(sink, <Object?, Object?>{'surface': 'main', 'visible': false});
      sendEvent(sink, <Object?, Object?>{
        'surface': 'main',
        'visible': false,
      }); // dup
      sendEvent(sink, <Object?, Object?>{'surface': 'main', 'visible': true});
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      expect(
        events.map((e) => e.visible).toList(),
        <bool>[false, true],
        reason: 'duplicate consecutive readings must not re-emit',
      );
      expect(controller.isVisible(WindowSurface.main), isTrue);
    },
  );

  test('ignores malformed events without throwing', () async {
    messenger.setMockMethodCallHandler(
      methodChannel,
      (call) async => <Object?>[],
    );

    late MockStreamHandlerEventSink sink;
    messenger.setMockStreamHandler(
      eventChannel,
      MockStreamHandler.inline(onListen: (args, s) => sink = s),
    );

    final events = <SurfaceVisibility>[];
    final sub = controller.changes.listen(events.add);
    await controller.start();
    await Future<void>.delayed(Duration.zero);

    sendEvent(sink, 'not-a-map');
    sendEvent(sink, <Object?, Object?>{'surface': 'unknown', 'visible': true});
    sendEvent(sink, <Object?, Object?>{'surface': 'pip', 'visible': 'nope'});
    sendEvent(sink, <Object?, Object?>{
      'surface': 'pip',
      'visible': true,
    }); // valid
    await Future<void>.delayed(Duration.zero);

    await sub.cancel();
    expect(events.length, 1);
    expect(events.single.surface, WindowSurface.pip);
  });

  test('missing plugin: start does not throw; defaults to visible', () async {
    messenger.setMockMethodCallHandler(methodChannel, null); // → MissingPlugin

    await controller.start(); // must not throw

    // Unobserved surfaces default to visible so the scene errs toward animating.
    expect(controller.isVisible(WindowSurface.main), isTrue);
    expect(controller.isVisible(WindowSurface.pip), isTrue);
  });

  test('start is idempotent', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      calls++;
      return <Object?>[];
    });
    await controller.start();
    await controller.start();
    expect(calls, 1);
  });
}
