import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunch_lucky/core/network_check.dart';
import 'package:lunch_lucky/core/router.dart';
import 'package:lunch_lucky/core/theme.dart';
import 'package:lunch_lucky/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(child: LunchLuckyApp()));
}

class LunchLuckyApp extends ConsumerWidget {
  const LunchLuckyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
