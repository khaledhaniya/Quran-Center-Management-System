import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_circles_mobile/services/api_service.dart';

String tokenWithExpiry(Object expiry) {
  final payload = base64UrlEncode(utf8.encode(jsonEncode({'exp': expiry})))
      .replaceAll('=', '');
  return 'header.$payload.signature';
}

void main() {
  test('Cached login rejects expired, malformed and missing expiry tokens', () {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    expect(ApiService.isTokenCurrent(tokenWithExpiry(now + 300)), isTrue);
    expect(ApiService.isTokenCurrent(tokenWithExpiry(now - 1)), isFalse);
    expect(ApiService.isTokenCurrent(tokenWithExpiry('not-a-number')), isFalse);
    expect(ApiService.isTokenCurrent('bad.token'), isFalse);
    expect(ApiService.isTokenCurrent(null), isFalse);
  });
}
