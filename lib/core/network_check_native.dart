import 'dart:io';

/// 네이티브: DNS lookup으로 연결 확인
Future<bool> checkNetworkConnectivity() async {
  try {
    final result = await InternetAddress.lookup('google.com')
        .timeout(const Duration(seconds: 3));
    return result.isNotEmpty;
  } catch (_) {
    return false;
  }
}
