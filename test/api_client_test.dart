import 'dart:convert';

import 'package:canto_mobile/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('authenticated requests include the persisted bearer token', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({'id': 7, 'username': 'learner'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiClient(client: client)..accessToken = 'jwt-token';

    final user = await api.fetchCurrentUser();

    expect(capturedRequest.url.path, '/auth/me');
    expect(capturedRequest.headers['Authorization'], 'Bearer jwt-token');
    expect(user.username, 'learner');
  });
}
