import 'package:flutter/services.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:e_health_app/core/theme/app_theme.dart';
import 'package:e_health_app/features/profile/domain/models/account_profile.dart';
import 'package:e_health_app/features/profile/domain/models/setup_progress.dart';
import 'package:e_health_app/features/profile/data/services/profile_photo_picker.dart';
import 'package:e_health_app/features/profile/presentation/cubit/profile_edit_cubit.dart';
import 'package:e_health_app/features/profile/presentation/pages/edit_profile_screen.dart';

import 'support/fake_profile_repository.dart';

class Picker implements ProfilePhotoPicker {
  AvatarPhoto? result;
  Object? failure;
  Completer<AvatarPhoto?>? pending;
  int calls = 0;
  @override
  Future<AvatarPhoto?> pick(ImageSource source) async {
    calls++;
    if (failure != null) throw failure!;
    return pending != null ? pending!.future : result;
  }

  @override
  Future<AvatarPhoto?> recover() async => null;
}

void main() {
  late FakeProfileRepository repository;
  late Picker picker;
  late ProfileEditCubit cubit;
  setUp(() {
    repository = FakeProfileRepository()
      ..records['a'] = const SetupProgress(
        name: 'Sara',
        weight: '65',
        avatarPath: 'a/old.jpg',
        consentComplete: true,
      );
    picker = Picker();
    cubit = ProfileEditCubit(
      userId: 'a',
      repository: repository,
      picker: picker,
    );
  });
  tearDown(() => cubit.close());
  test('Loads persisted fields, preserves drafts on failure, confirms save and restart', () async {
    await cubit.load();
    expect(cubit.state.name, 'Sara');
    expect(cubit.state.canSave, false);
    cubit.editName('Sara Ahmed');
    repository.failSave = true;
    expect(await cubit.save(), false);
    expect(cubit.state.name, 'Sara Ahmed');
    expect(cubit.state.dirty, true);
    repository.failSave = false;
    expect(await cubit.save(), true);
    expect(cubit.state.dirty, false);
    expect((await repository.loadAccount('a')).name, 'Sara Ahmed');
    expect(repository.records['a']!.consentComplete, true);
  });
  test(
    'Picker cancellation, denial and duplicate actions preserve drafts',
    () async {
      await cubit.load();
      cubit.editName('New name');
      await cubit.selectPhoto(ImageSource.gallery);
      expect(cubit.state.avatarEdit, AvatarEdit.keep);
      picker.failure = const ProfileEditFailure('Access denied');
      await cubit.selectPhoto(ImageSource.camera);
      expect(cubit.state.error, 'Access denied');
      expect(cubit.state.name, 'New name');
      picker.failure = null;
      picker.pending = Completer<AvatarPhoto?>();
      final first = cubit.selectPhoto(ImageSource.gallery);
      await cubit.selectPhoto(ImageSource.gallery);
      expect(picker.calls, 3);
      expect(cubit.state.canSave, false);
      picker.pending!.complete(null);
      await first;
    },
  );
  test(
    'Photo previews stage replacement and removal until confirmed save',
    () async {
      await cubit.load();
      picker.result = AvatarPhoto(
        Uint8List.fromList(img.encodeJpg(img.Image(width: 4, height: 4))),
      );
      await cubit.selectPhoto(ImageSource.gallery);
      expect(cubit.state.photo, isNotNull);
      expect(repository.records['a']!.avatarPath, 'a/old.jpg');
      await cubit.save();
      expect(repository.records['a']!.avatarPath, 'a/test-only.jpg');
      cubit.removePhoto();
      expect(repository.records['a']!.avatarPath, isNotNull);
      await cubit.save();
      expect(repository.records['a']!.avatarPath, isNull);
    },
  );
  for (final width in [320.0, 430.0]) {
    testWidgets(
      'Editor is usable at $width with large text and reduced motion',
      (tester) async {
        if (const bool.fromEnvironment('CAPTURE_QA')) {
          await (FontLoader('EHealth')
                ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
                ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf')))
              .load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        }
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await cubit.load();
        final captureKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.6),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: RepaintBoundary(
              key: captureKey,
              child: EditProfileScreen(controller: cubit),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Edit Profile'), findsOneWidget);
        if (const bool.fromEnvironment('CAPTURE_QA')) {
          await tester.runAsync(() async {
            final image =
                await (captureKey.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory('build/profile_qa').create(recursive: true);
            await File('build/profile_qa/edit_${width.round()}.png')
                .writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.enterText(
          find.byType(TextFormField).first,
          'Updated name',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save Changes'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save Changes'));
        await tester.pumpAndSettle();
        expect(repository.records['a']!.name, 'Updated name');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('Back confirms unsaved changes and keeps editing', (
    tester,
  ) async {
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: EditProfileScreen(controller: cubit),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Unsaved');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(cubit.state.name, 'Unsaved');
    await tester.pumpWidget(const SizedBox());
  });
}
