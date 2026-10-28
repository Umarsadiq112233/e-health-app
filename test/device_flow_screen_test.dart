import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_health_app/features/device_pairing/presentation/pages/device_flow_screen.dart';
import 'package:e_health_app/features/device_pairing/presentation/cubit/device_cubit.dart';

import 'device_ready_test.dart' show FakeDevices;

void main() {
  testWidgets('All device screens fit narrow phones with honest empty state', (
    tester,
  ) async {
    final repository = FakeDevices();
    final cubit = DeviceCubit(repository);
    addTearDown(() async {
      await cubit.close();
      await repository.dispose();
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 844);
      for (final view in DeviceView.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: DeviceFlowScreen(view: view, controller: cubit),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$view at $width');
        await tester.drag(find.byType(ListView).first, const Offset(0, -650));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$view scrolled at $width',
        );
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
}
