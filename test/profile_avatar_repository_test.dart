import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:e_health_app/features/profile/data/repositories/supabase_profile_repository.dart';
import 'package:e_health_app/features/profile/data/services/profile_photo_picker.dart';
import 'package:e_health_app/features/profile/domain/models/account_profile.dart';

import 'supabase_profile_repository_test.dart' as fixture;

AvatarPhoto photo() => AvatarPhoto(
  Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8))),
);
void main() {
  test(
    'Normalization bakes EXIF orientation, resizes and discards metadata',
    () {
      final original = img.Image(width: 1600, height: 800);
      original.exif.imageIfd.orientation = 6;
      final result = prepareAvatar(Uint8List.fromList(img.encodeJpg(original)));
      final decoded = img.decodeJpg(result)!;
      expect(decoded.width, 512);
      expect(decoded.height, 1024);
      expect(result.length, lessThanOrEqualTo(AvatarPhoto.maxBytes));
      expect(
        () => prepareAvatar(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<ProfileEditFailure>()),
      );
      expect(
        () => AvatarPhoto(Uint8List(AvatarPhoto.maxBytes + 1)).validate(),
        throwsA(isA<ProfileEditFailure>()),
      );
    },
  );
  for (final mode in [
    'name',
    'replace',
    'remove',
    'uploadFailure',
    'dbFailure',
    'committedLostResponse',
    'unknownOutcome',
    'oldCleanupFailure',
  ]) {
    test('Supabase profile/storage save: $mode', () async {
      var record = fixture.row()..['avatar_path'] = '${fixture.userId}/old.jpg';
      final events = <String>[];
      String? uploaded;
      var patchFailed = false;
      final client = await fixture.clientFor((request) async {
        final url = request.url.path;
        if (url.contains('/storage/v1/object/sign/')) {
          events.add('sign');
          return http.Response(
            jsonEncode({
              'signedURL':
                  '/object/sign/ehealth-avatars/${record['avatar_path']}?token=ephemeral-test',
            }),
            200,
          );
        }
        if (url.contains('/storage/v1/object/') && request.method == 'POST') {
          uploaded = url.split('/ehealth-avatars/').last;
          events.add('upload');
          expect(uploaded, startsWith('${fixture.userId}/'));
          expect(uploaded, endsWith('.jpg'));
          if (mode == 'uploadFailure') {
            return http.Response(
              jsonEncode({
                'statusCode': '403',
                'message': 'denied',
                'error': 'Forbidden',
              }),
              403,
            );
          }
          return http.Response(
            jsonEncode({
              'Key': 'ehealth-avatars/$uploaded',
              'Id': 'new-object',
            }),
            200,
          );
        }
        if (url.contains('/storage/v1/object/') && request.method == 'DELETE') {
          final prefix = (jsonDecode(request.body)['prefixes'] as List).single;
          events.add('delete:$prefix');
          if (mode == 'oldCleanupFailure' &&
              prefix.toString().endsWith('/old.jpg')) {
            return http.Response(
              jsonEncode({
                'statusCode': '500',
                'message': 'offline',
                'error': 'error',
              }),
              500,
            );
          }
          return http.Response('[]', 200);
        }
        if (request.method == 'PATCH') {
          events.add('patch');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.containsKey('email'), isFalse);
          expect(body.containsKey('profile_complete'), isFalse);
          expect(body.containsKey('permissions'), isFalse);
          if (mode == 'name') expect(body.keys.toSet(), {'full_name'});
          if (mode == 'remove') {
            expect(body, {'avatar_path': null, 'avatar_url': null});
          }
          if (mode == 'dbFailure' || mode == 'unknownOutcome') {
            patchFailed = true;
            return http.Response(
              jsonEncode({'code': '42501', 'message': 'test rejection'}),
              403,
            );
          }
          record = {...record, ...body};
          if (mode == 'committedLostResponse') {
            return http.Response(
              jsonEncode({'code': '503', 'message': 'lost response'}),
              503,
            );
          }
          return http.Response(jsonEncode(record), 200);
        }
        events.add('read');
        if (mode == 'unknownOutcome' && patchFailed) {
          return http.Response(
            jsonEncode({'code': '503', 'message': 'offline'}),
            503,
          );
        }
        return http.Response(jsonEncode(record), 200);
      });
      addTearDown(client.dispose);
      final repository = SupabaseProfileRepository(client);
      final before = await repository.loadAccount(fixture.userId);
      expect(before.email, 'test@example.invalid');
      expect(before.avatarDisplayUrl, contains('ephemeral-test'));
      events.clear();
      final edit = mode == 'name'
          ? AvatarEdit.keep
          : mode == 'remove'
          ? AvatarEdit.remove
          : AvatarEdit.replace;
      final future = repository.saveAccount(
        before,
        name: mode == 'name' ? 'New Name' : before.name,
        weight: before.weight,
        avatarEdit: edit,
        photo: edit == AvatarEdit.replace ? photo() : null,
      );
      if (['dbFailure', 'uploadFailure', 'unknownOutcome'].contains(mode)) {
        await expectLater(future, throwsA(isA<ProfileEditFailure>()));
        expect(events, isNot(contains('delete:${fixture.userId}/old.jpg')));
        if (mode == 'unknownOutcome') {
          expect(events, isNot(contains('delete:$uploaded')));
        } else {
          expect(events, contains('delete:$uploaded'));
        }
        if (mode == 'uploadFailure') expect(events, isNot(contains('patch')));
      } else {
        final result = await future;
        if (mode == 'name') {
          expect(result.profile.name, 'New Name');
          expect(events.where((e) => e.startsWith('delete')), isEmpty);
        }
        if (mode == 'replace' || mode == 'committedLostResponse') {
          expect(result.profile.avatarPath, uploaded);
          expect(
            events.indexOf('patch'),
            lessThan(events.indexOf('delete:${fixture.userId}/old.jpg')),
          );
          expect(events, isNot(contains('delete:$uploaded')));
        }
        if (mode == 'remove') {
          expect(result.profile.avatarPath, isNull);
          expect(events.first, 'patch');
          expect(events.last, 'delete:${fixture.userId}/old.jpg');
        }
        if (mode == 'oldCleanupFailure') {
          expect(
            result.warning,
            contains('previous photo could not be removed'),
          );
        }
      }
    });
  }
  test('Owned object keys reject foreign IDs, traversal and URLs', () {
    expect(SupabaseProfileRepository.ownsAvatar('a', 'a/photo.jpg'), isTrue);
    for (final path in [
      'b/photo.jpg',
      'a/../b/photo.jpg',
      'file:///a/photo.jpg',
      'https://example.com/photo.jpg',
    ]) {
      expect(SupabaseProfileRepository.ownsAvatar('a', path), isFalse);
    }
  });
  test('Email changes call Supabase Auth, never profiles', () async {
    final client = await fixture.clientFor((request) async {
      expect(request.url.path, '/auth/v1/user');
      expect(request.method, 'PUT');
      expect(jsonDecode(request.body)['email'], 'new@example.invalid');
      return http.Response(
        jsonEncode({
          'id': fixture.userId,
          'email': 'test@example.invalid',
          'created_at': '2026-10-06T00:00:00Z',
          'user_metadata': {},
          'app_metadata': {},
        }),
        200,
      );
    });
    addTearDown(client.dispose);
    await SupabaseProfileRepository(client)
        .requestEmailChange(fixture.userId, 'new@example.invalid');
  });
}
