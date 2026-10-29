import 'dart:js_interop';

@JS('susuLumaTurnstileToken')
external JSPromise<JSString> _requestTurnstileToken(JSString siteKey);

class CaptchaClient {
  static Future<String?> getToken(String siteKey) async {
    if (siteKey.isEmpty) return null;
    try {
      final token = await _requestTurnstileToken(siteKey.toJS).toDart;
      return token.toDart;
    } on Object {
      return null;
    }
  }
}
