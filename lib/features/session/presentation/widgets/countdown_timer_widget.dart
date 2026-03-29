import 'dart:async';
import 'package:flutter/material.dart';

class CountdownTimerWidget extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback onTimeout;
  final String label;

  const CountdownTimerWidget({
    super.key,
    required this.expiresAt,
    required this.onTimeout,
    this.label = '남은 시간',
  });

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  Timer? _timer;
  late Duration _timeLeft;
  bool _timeoutTriggered = false;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    if (now.isAfter(widget.expiresAt)) {
      _timer?.cancel();
      if (!_timeoutTriggered) {
        _timeoutTriggered = true;
        if (mounted) {
          setState(() {
            _timeLeft = Duration.zero;
          });
          widget.onTimeout();
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _timeLeft = widget.expiresAt.difference(now);
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeoutTriggered) {
      return const Text(
        '자동 찬성됨 ✓',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      );
    }
    final minutes = _timeLeft.inMinutes;
    final seconds = _timeLeft.inSeconds % 60;
    return Text(
      '${widget.label}: $minutes:${seconds.toString().padLeft(2, '0')}',
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.red,
      ),
    );
  }
}
