import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:lunch_lucky/features/roulette/presentation/roulette_providers.dart';

// Lucky Latte server/client URLs (로컬 테스트용, 배포 시 변경)
const luckyLatteServerUrl = 'http://localhost:8080';
const luckyLatteClientUrl = 'http://localhost:8888';

Future<void> startCoffeeGame(
  BuildContext context,
  WidgetRef ref,
  String groupId,
  String nickname, {
  String? userId,
}) async {
  try {
    // 1. Lucky Latte 서버에 방 예약 요청
    final response = await http.post(
      Uri.parse('$luckyLatteServerUrl/api/rooms'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('커피 게임 서버에 연결할 수 없습니다.')),
        );
      }
      return;
    }

    final data = json.decode(response.body);
    final roomCode = data['code'] as String;

    // 2. Firestore에 방 코드 저장 (설정한 유저 ID 포함)
    final gameUrl = '$luckyLatteClientUrl/quick?code=$roomCode';
    await ref
        .read(rouletteRepositoryProvider)
        .setGameUrl(groupId, gameUrl, userId ?? '');

    // 3. 호스트도 같은 URL로 이동 (닉네임 포함)
    final hostUrl = '$gameUrl&nickname=${Uri.encodeComponent(nickname)}';
    if (context.mounted) {
      await launchUrl(
        Uri.parse(hostUrl),
        mode: LaunchMode.externalApplication,
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류: $e')),
      );
    }
  }
}

/// gameUrl에 닉네임을 붙여서 개인화된 URL 생성
Uri buildPersonalGameUrl(String gameUrl, String nickname) {
  final uri = Uri.parse(gameUrl);
  final newParams = Map<String, String>.from(uri.queryParameters);
  newParams['nickname'] = nickname;
  return uri.replace(queryParameters: newParams);
}
