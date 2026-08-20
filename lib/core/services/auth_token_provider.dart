/// Holds the active API bearer token for authenticated backend requests.
class AuthTokenProvider {
  String? _token;

  String? get token => _token;

  void setToken(String? token) {
    final value = token?.trim();
    _token = (value == null || value.isEmpty) ? null : value;
  }

  void clear() => _token = null;
}
