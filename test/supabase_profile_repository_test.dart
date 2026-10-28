import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:e_health_app/features/profile/data/repositories/supabase_profile_repository.dart';
import 'package:e_health_app/features/profile/domain/models/setup_progress.dart';
import 'package:e_health_app/features/profile/domain/models/profile_failure.dart';

const userId = 'a1000000-0000-0000-0000-000000000001';
Map<String, dynamic> row() => {
  'id': userId,
  'full_name': 'Sara',
  'weight_kg': '65',
  'profile_complete': true,
  'consent_complete': true,
  'device_complete': false,
  'pairing_step': 6,
  'permissions': {'Bluetooth': true},
};
Future<SupabaseClient> clientFor(
  Future<http.Response> Function(http.Request) respond,
) async {
  final client = SupabaseClient(
    'https://test.supabase.co',
    'public-test-key',
    httpClient: MockClient((request) async {
      final response = await respond(request);
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }),
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
  );
  await client.auth.setInitialSession(
    jsonEncode({
      'access_token': 'test-access-token',
      'refresh_token': 'test-refresh-token',
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
      'user': {
        'id': userId,
        'aud': 'authenticated',
        'email': 'test@example.invalid',
        'created_at': '2026-10-06T00:00:00Z',
        'app_metadata': {},
        'user_metadata': {},
      },
    }),
  );
  return client;
}

void main() {
  test(
    'Successful profile read maps setup and filters by authenticated ID',
    () async {
      final client = await clientFor((request) async {
        expect(request.method, 'GET');
        expect(request.url.queryParameters['id'], 'eq.$userId');
        return http.Response(jsonEncode(row()), 200);
      });
      addTearDown(client.dispose);
      final profile = await SupabaseProfileRepository(client).load(userId);
      expect(profile.name, 'Sara');
      expect(profile.pairingStep, 6);
      expect(profile.consentComplete, isTrue);
    },
  );
  test(
    'Database error propagates without attempting profile creation',
    () async {
      var requests = 0;
      final client = await clientFor((request) async {
        requests++;
        expect(request.method, 'GET');
        return http.Response(
          jsonEncode({'code': 'PGRST205', 'message': 'Schema unavailable'}),
          404,
        );
      });
      addTearDown(client.dispose);
      await expectLater(
        SupabaseProfileRepository(client).load(userId),
        throwsA(
          isA<ProfileFailure>().having(
            (failure) => failure.message,
            'message',
            contains('profile storage has not been set up'),
          ),
        ),
      );
      expect(requests, 1);
    },
  );
  test(
    'Missing profile creates only own ID with ignore-duplicate policy',
    () async {
      var requests = 0;
      final client = await clientFor((request) async {
        requests++;
        if (requests == 1) return http.Response('null', 200);
        if (requests == 2) {
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {'id': userId});
          expect(
            request.headers['Prefer'],
            contains('resolution=ignore-duplicates'),
          );
          return http.Response('', 201);
        }
        return http.Response(jsonEncode(row()), 200);
      });
      addTearDown(client.dispose);
      expect(
        (await SupabaseProfileRepository(client).load(userId)).name,
        'Sara',
      );
      expect(requests, 3);
    },
  );
  test(
    'Update persists profile and setup but never ID or timestamps',
    () async {
      final client = await clientFor((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.queryParameters['id'], 'eq.$userId');
        final body = jsonDecode(request.body) as Map;
        expect(body['pairing_step'], 6);
        expect(body['full_name'], 'Sara');
        expect(body.containsKey('id'), isFalse);
        expect(body.containsKey('updated_at'), isFalse);
        return http.Response(jsonEncode({'id': userId}), 200);
      });
      addTearDown(client.dispose);
      await SupabaseProfileRepository(client)
          .save(userId, const SetupProgress(name: 'Sara', pairingStep: 6));
    },
  );
  test(
    'Wellness details survive save and load alongside permission choices',
    () async {
      final record = row();
      final client = await clientFor((request) async {
        if (request.method == 'PATCH') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['permissions']['bluetooth'], isTrue);
          expect(body['permissions']['_wellness']['steps'], 8500);
          record.addAll(body);
          return http.Response(jsonEncode({'id': userId}), 200);
        }
        return http.Response(jsonEncode(record), 200);
      });
      addTearDown(client.dispose);
      final repository = SupabaseProfileRepository(client);
      await repository.save(
        userId,
        const SetupProgress(
          name: 'Sara',
          permissions: {'bluetooth': true},
          wellness: {
            'steps': 8500,
            'units': 'imperial',
            'preferences': ['Better Sleep'],
          },
        ),
      );
      final restored = await repository.load(userId);
      expect(restored.wellness['steps'], 8500);
      expect(restored.wellness['preferences'], ['Better Sleep']);
      expect(restored.permissions, {'bluetooth': true});
    },
  );
  test('Another account ID is rejected before any request', () async {
    final client = await clientFor(
      (_) async => throw StateError('No request allowed'),
    );
    addTearDown(client.dispose);
    final profiles = SupabaseProfileRepository(client);
    await expectLater(profiles.load('another-user'), throwsStateError);
    await expectLater(
      profiles.save('another-user', const SetupProgress()),
      throwsStateError,
    );
  });
}
