import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import 'package:lunch_lucky/features/roulette/presentation/roulette_providers.dart';
import 'package:lunch_lucky/features/group/presentation/group_providers.dart';
import 'package:lunch_lucky/features/session/presentation/session_providers.dart';

class RouletteScreen extends ConsumerStatefulWidget {
  const RouletteScreen({super.key});

  @override
  ConsumerState<RouletteScreen> createState() => _RouletteScreenState();
}

class _RouletteScreenState extends ConsumerState<RouletteScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late ConfettiController _confettiController;
  RouletteParticipant? _winner;
  bool _dialogShown = false;
  bool _isLocalTrigger = false;

  static const _spinDurationMs = 6000;
  static const _spinDuration = Duration(milliseconds: _spinDurationMs);
  static const _rouletteCurve = Cubic(0.1, 1.0, 0.2, 1.0);
  int _lastPegCount = 0;

  final List<Color> _colors = [
    Colors.redAccent.shade100,
    Colors.blueAccent.shade100,
    Colors.greenAccent.shade100,
    Colors.orangeAccent.shade100,
    Colors.purpleAccent.shade100,
    Colors.tealAccent.shade100,
  ];

  Future<void> _handleCompletion() async {
    if (!mounted) return;

    if (_winner != null && !_dialogShown) {
      _dialogShown = true;
      HapticFeedback.heavyImpact();
      _confettiController.play();

      final groupId = ref.read(currentGroupIdProvider);
      if (groupId != null) {
        try {
          // Mark as completed in remote state transactionally
          final isFirstCompletion = await ref
              .read(rouletteRepositoryProvider)
              .setCompleted(groupId);
          if (isFirstCompletion) {
            // Increment local stats only once globally
            try {
              await ref
                  .read(groupRepositoryProvider)
                  .incrementDessertWins(groupId, _winner!.member.userId);
            } catch (e) {
              debugPrint('Error incrementDessertWins: $e');
            }
            // Reset veto counts
            try {
              await ref
                  .read(groupRepositoryProvider)
                  .resetGroupVetoCounts(groupId);
            } catch (e) {
              debugPrint('Error resetGroupVetoCounts: $e');
            }
          }
        } catch (e) {
          debugPrint('Error setCompleted: $e');
        }

        // 룰렛(점심)이 최종 완료되었으므로 전원 참여 상태 + mustEat 초기화
        // isFirstCompletion 밖에서 실행 - 모든 클라이언트에서 확실히 초기화
        try {
          await ref
              .read(groupRepositoryProvider)
              .clearAllAttendance(groupId);

          // 점심 식사 평가 자동 완료 (전원 '좋아요')
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
        } catch (e) {
          debugPrint('Error after roulette completion: $e');
        }
      }

      if (mounted) {
        _showWinnerDialog();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _animationController = AnimationController(
      vsync: this,
      duration: _spinDuration,
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(_animationController);

    _animationController.addListener(() {
      if (_animationController.isAnimating) {
        final currentAngle = _animation.value;
        const pegInterval = (2 * pi) / 36; // 36개의 걸쇠 (10도마다 틱)
        final currentPegCount = (currentAngle / pegInterval).floor();
        if (currentPegCount > _lastPegCount) {
          HapticFeedback.selectionClick();
          _lastPegCount = currentPegCount;
        }
      }
    });

    _animationController.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        HapticFeedback.mediumImpact(); // 멈추는 순간 덜컥
        await Future.delayed(const Duration(milliseconds: 1200)); // 1.2초 뜸 들이기
        await _handleCompletion();
      }
    });

    // 화면 진입 시 이미 'spinning' 상태인 경우 즉시 처리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialSpinState();
    });
  }

  /// ref.listen은 변경 시에만 실행되므로, 화면 진입 시 초기 상태를 직접 확인
  void _checkInitialSpinState() {
    if (!mounted) return;
    final state = ref.read(rouletteStateProvider).value;
    if (state == null) return;

    if (state.status == 'spinning' &&
        state.targetRotation != null &&
        state.winnerId != null) {
      if (_animationController.isAnimating || _dialogShown) return;

      final participants = ref.read(rouletteParticipantsProvider).value;
      if (participants == null || participants.isEmpty) {
        // 아직 참여자가 로딩 중이면 잠시 후 재시도
        Future.delayed(
          const Duration(milliseconds: 500),
          _checkInitialSpinState,
        );
        return;
      }

      _startAnimationFromState(state, participants);
    }
  }

  void _startAnimationFromState(
    dynamic state,
    List<RouletteParticipant> participants,
  ) {
    if (!mounted || _dialogShown) return;

    final matchedWinner = participants.firstWhere(
      (p) => p.member.userId == state.winnerId,
      orElse: () => participants.first,
    );

    final now = DateTime.now();
    final startedAt = state.spinStartedAt ?? now;
    final serverElapsedMs = now.difference(startedAt).inMilliseconds;

    // 이미 당첨 대기가 한참 지나 완료된 경우라면 즉시 당첨 팝업 처리
    if (serverElapsedMs > _spinDurationMs + 2000) {
      setState(() {
        _winner = matchedWinner;
        _animation = AlwaysStoppedAnimation(state.targetRotation!);
        _animationController.value = 1.0;
      });
      if (!_dialogShown) {
        _handleCompletion();
      }
      return;
    }

    // 로컬에서 이미 돌리고 있었다면, 현재 위치에서 자연스럽게 감속 시작
    if (_isLocalTrigger) {
      final currentAngle = _animation.value;
      final currentRotation = (currentAngle / (2 * pi)).floor();
      
      // 현재 바퀴 수 + 추가 바퀴(7~10) + 타겟 각도
      // state.targetRotation은 (여분 바퀴 + 보정 각도) * 2pi 형태임
      // 여기서 targetAngle만 추출
      final targetAngleOnly = (state.targetRotation! / (2 * pi)) % 1.0;
      final finalRotation = (currentRotation + 8 + targetAngleOnly) * 2 * pi;

      setState(() {
        _winner = matchedWinner;
        _isLocalTrigger = false;
        _animationController.stop();
        _animation = Tween<double>(
          begin: currentAngle,
          end: finalRotation,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: _rouletteCurve,
        ));
      });
      _animationController.duration = _spinDuration;
      _animationController.forward(from: 0.0);
    } else {
      // 다른 사람이 돌린 것을 보는 경우 (또는 로컬 트리거가 아닌 경우)
      // 최소 3초는 애니메이션을 보여주도록 보정 (너무 순식간에 멈추는 것 방지)
      final remainingMs = _spinDurationMs - serverElapsedMs;
      final effectiveDuration = remainingMs < 3000 ? 3000 : remainingMs;
      final fromFraction = (1.0 - (effectiveDuration / _spinDurationMs)).clamp(0.0, 0.7);

      setState(() {
        _winner = matchedWinner;
        _animation = Tween<double>(
          begin: 0,
          end: state.targetRotation!,
        ).animate(CurvedAnimation(
          parent: _animationController,
          curve: _rouletteCurve,
        ));
      });
      _animationController.duration = _spinDuration;
      _animationController.forward(from: fromFraction);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _triggerSpin(List<RouletteParticipant> participants) async {
    final groupId = ref.read(currentGroupIdProvider);
    if (groupId == null || participants.isEmpty) return;

    final random = Random();
    final totalWeight = participants.fold<double>(
      0,
      (sum, p) => sum + p.weight,
    );

    double currentSum = 0;
    final Map<RouletteParticipant, double> cumulativeWeights = {};
    for (var p in participants) {
      currentSum += p.weight / totalWeight;
      cumulativeWeights[p] = currentSum;
    }

    final winThreshold = random.nextDouble();

    RouletteParticipant localWinner = participants.first;
    for (var p in participants) {
      if (winThreshold <= cumulativeWeights[p]!) {
        localWinner = p;
        break;
      }
    }

    final winnerIndex = participants.indexOf(localWinner);
    final sliceStart = winnerIndex == 0
        ? 0.0
        : cumulativeWeights[participants[winnerIndex - 1]]!;
    final sliceEnd = cumulativeWeights[localWinner]!;

    // 안전한 랜덤 오프셋 적용 (슬라이스 크기의 최대 ±30%)
    final sliceWidth = sliceEnd - sliceStart;
    final maxOffset = sliceWidth * 0.3;
    final randomOffset =
        (random.nextDouble() - 0.5) * 2 * maxOffset; // -maxOffset ~ +maxOffset
    final randomizedCenter = sliceStart + (sliceWidth / 2) + randomOffset;

    // 목표 각도 보정 (바늘이 12시(0.75)에 있으므로)
    final targetAngle = (0.75 - randomizedCenter + 1.0) % 1.0;

    final extraSpins = 7 + random.nextInt(4); // 7~10바퀴 (회전 시간 증가에 맞춤)
    final totalRotation = (extraSpins + targetAngle) * 2 * pi;

    // 즉각적인 로컬 애니메이션 시작 (등속 회전)
    setState(() {
      _isLocalTrigger = true;
      _animation = Tween<double>(
        begin: 0,
        end: 2 * pi,
      ).animate(_animationController);
    });
    _animationController.duration = const Duration(milliseconds: 1000);
    _animationController.repeat();

    await ref
        .read(rouletteRepositoryProvider)
        .startSpin(groupId, localWinner.member.userId, totalRotation);
  }

  void _showWinnerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '당첨! 🎉',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '오늘 커피는 "${_winner!.member.displayName}"님께서 쏩니다!',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '(거부 이력: ${_winner!.vetoCount}회)',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (context.mounted) {
                context.go('/home');
              }
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final participantsAsync = ref.watch(rouletteParticipantsProvider);

    ref.listen(rouletteStateProvider, (prev, next) {
      final state = next.value;
      if (state == null) return;

      if (state.status == 'spinning' &&
          state.targetRotation != null &&
          state.winnerId != null) {
        final participants = ref.read(rouletteParticipantsProvider).value;
        if (participants == null || participants.isEmpty) return;
        _startAnimationFromState(state, participants);
      } else if (state.status == 'idle' || state.status == 'ready') {
        // 상태 초기화 - 다시 돌릴 수 있도록 리셋
        if (_animationController.isAnimating) {
          _animationController.reset();
        }
        setState(() {
          _winner = null;
          _dialogShown = false;
          _isLocalTrigger = false;
          _lastPegCount = 0;
          _animation = Tween<double>(begin: 0, end: 0).animate(
            _animationController,
          );
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('☕ 후식 뽑기')),
      body: Center(
        child: participantsAsync.when(
          data: (participants) {
            if (participants.isEmpty) {
              return const Text('참여 가능한 멤버가 없습니다.');
            }

            final totalWeight = participants.fold<double>(
              0,
              (sum, p) => sum + p.weight,
            );
            final List<Color> colors = [];
            final List<double> stops = [];

            double currentStop = 0;
            for (var i = 0; i < participants.length; i++) {
              final p = participants[i];
              colors.add(_colors[i % _colors.length]);
              currentStop += p.weight / totalWeight;
              stops.add(currentStop);

              if (i < participants.length - 1) {
                colors.add(_colors[(i + 1) % _colors.length]);
                stops.add(currentStop);
              }
            }

            final rouletteState = ref.watch(rouletteStateProvider).value;
            final isSpinning = rouletteState?.status == 'spinning';
            final isCompleted = rouletteState?.status == 'completed';

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '운명의 룰렛을 돌려보세요!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  '주의: 거부 이력이 많은 멤버는 배율이 높게 설정됩니다!',
                  style: TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 48),

                Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _animation.value,
                            child: Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: colors,
                                  stops: stops,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                    offset: const Offset(0, 10),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    spreadRadius: -5,
                                    offset: const Offset(0, -5),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  ..._buildLabels(participants, totalWeight),
                                  Center(
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down_circle,
                      size: 48,
                      color: Colors.black87,
                    ),
                  ],
                ),

                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: isSpinning || isCompleted
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          _triggerSpin(participants);
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: Text(
                    isSpinning ? '도는 중...' : (isCompleted ? '완료됨' : '지금 돌리기'),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (e, st) => Text('오류: $e'),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerTop,
      floatingActionButton: ConfettiWidget(
        confettiController: _confettiController,
        blastDirectionality: BlastDirectionality.explosive,
        shouldLoop: false,
        colors: const [
          Colors.green,
          Colors.blue,
          Colors.pink,
          Colors.orange,
          Colors.purple,
        ],
      ),
    );
  }

  List<Widget> _buildLabels(
    List<RouletteParticipant> participants,
    double totalWeight,
  ) {
    // Generate text labels along the circle
    final labels = <Widget>[];
    double currentAngle = 0;

    for (var p in participants) {
      final sweepAngle = (p.weight / totalWeight) * 2 * pi;
      final centerAngle = currentAngle + (sweepAngle / 2);

      labels.add(
        Positioned.fill(
          child: Align(
            alignment: Alignment(cos(centerAngle), sin(centerAngle)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Transform.rotate(
                angle: centerAngle + pi / 2, // Text rotation to face outward
                child: Text(
                  p.member.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      currentAngle += sweepAngle;
    }
    return labels;
  }
}
