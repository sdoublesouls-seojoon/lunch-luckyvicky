import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;
import 'package:lunch_lucky/core/network_check.dart';
import 'package:lunch_lucky/core/router.dart';
import 'package:lunch_lucky/core/theme.dart';
import 'package:lunch_lucky/firebase_options.dart';
import 'package:lunch_lucky/features/group/presentation/group_providers.dart';
import 'package:lunch_lucky/features/roulette/presentation/roulette_providers.dart';
import 'package:lunch_lucky/features/session/presentation/session_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(child: LunchLuckyApp()));
}

class LunchLuckyApp extends ConsumerStatefulWidget {
  const LunchLuckyApp({super.key});

  @override
  ConsumerState<LunchLuckyApp> createState() => _LunchLuckyAppState();
}

class _LunchLuckyAppState extends ConsumerState<LunchLuckyApp> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _listenForLuckyLatteMessages();
    }
  }

  void _listenForLuckyLatteMessages() {
    web.window.addEventListener(
      'message',
      ((web.MessageEvent event) {
        try {
          final data = event.data.dartify();
          if (data is! Map) return;
          final message = Map<String, dynamic>.from(data);

          if (message['type'] == 'LUCKY_VICKY_FINISH_SESSION') {
            _handleLuckyLatteSessionEnd(message['winner'] as String?);
          }
        } catch (_) {}
      }).toJS,
    );
  }

  Future<void> _handleLuckyLatteSessionEnd(String? winnerNickname) async {
    final groupId = ref.read(currentGroupIdProvider);
    if (groupId == null) return;

    // 1. gameUrl 클리어
    try {
      await ref.read(rouletteRepositoryProvider).clearGameUrl(groupId);
    } catch (_) {}

    // 2. 룰렛 상태를 completed로 마킹 (세션 완료 표시)
    try {
      await ref.read(rouletteRepositoryProvider).setCompleted(groupId);
    } catch (_) {}

    // 3. 참여 상태 + mustEat 초기화
    try {
      await ref.read(groupRepositoryProvider).clearAllAttendance(groupId);
    } catch (_) {}

    // 4. 점심 식사 평가 자동 완료
    try {
      final recentSessions = ref.read(recentSessionsProvider).value;
      if (recentSessions != null && recentSessions.isNotEmpty) {
        final lastSession = recentSessions.first;
        final now = DateTime.now();
        if (lastSession.status == 'completed' &&
            lastSession.createdAt.year == now.year &&
            lastSession.createdAt.month == now.month &&
            lastSession.createdAt.day == now.day &&
            lastSession.ratings.isEmpty) {
          await ref
              .read(sessionRepositoryProvider)
              .autoRateAll(groupId, lastSession.id);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Lunch-Luckvicky',
      theme: appTheme,
      routerConfig: router,
      builder: (context, child) {
        return _NetworkAwareBanner(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

class _NetworkAwareBanner extends StatefulWidget {
  final Widget child;
  const _NetworkAwareBanner({required this.child});

  @override
  State<_NetworkAwareBanner> createState() => _NetworkAwareBannerState();
}

class _NetworkAwareBannerState extends State<_NetworkAwareBanner> {
  bool _isOffline = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkConnection(),
    );
  }

  Future<void> _checkConnection() async {
    final isOnline = await checkNetworkConnectivity();
    if (mounted) {
      setState(() => _isOffline = !isOnline);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: widget.child),
        if (_isOffline)
          MaterialBanner(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            backgroundColor: Colors.red.shade50,
            content: Row(
              children: [
                Icon(Icons.wifi_off, size: 18, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  '네트워크 연결을 확인해주세요',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _checkConnection,
                child: const Text('재시도'),
              ),
            ],
          ),
      ],
    );
  }
}
