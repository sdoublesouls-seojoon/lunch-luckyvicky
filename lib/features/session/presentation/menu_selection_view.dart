import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunch_lucky/features/auth/data/auth_repository.dart';
import 'package:lunch_lucky/features/group/domain/menu_item.dart';
import 'package:lunch_lucky/features/group/domain/restaurant.dart';
import 'package:lunch_lucky/features/group/presentation/group_providers.dart';
import 'package:lunch_lucky/features/session/domain/session.dart';
import 'package:lunch_lucky/features/session/presentation/session_providers.dart';
import 'package:lunch_lucky/features/session/presentation/widgets/countdown_timer_widget.dart';

class MenuSelectionView extends ConsumerStatefulWidget {
  final Session session;
  final Restaurant restaurant;

  const MenuSelectionView({
    super.key,
    required this.session,
    required this.restaurant,
  });

  @override
  ConsumerState<MenuSelectionView> createState() => _MenuSelectionViewState();
}

class _MenuSelectionViewState extends ConsumerState<MenuSelectionView> {
  final Set<String> _selectedMenus = {};
  bool _isSubmitting = false;
  bool _didAutoSkip = false;

  static const int _budgetLimit = 15000;

  int get _totalPrice {
    int total = 0;
    for (final menuName in _selectedMenus) {
      final menu = widget.restaurant.menus.firstWhere(
        (m) => m.name == menuName,
      );
      total += menu.priceAsInt ?? 0;
    }
    return total;
  }

  bool _canAddMenu(MenuItem menu) {
    if (_selectedMenus.contains(menu.name)) return true; // already selected
    final menuPrice = menu.priceAsInt ?? 0;
    return _totalPrice + menuPrice <= _budgetLimit;
  }

  String _formatPrice(int price) {
    final str = price.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return '${buffer.toString()}원';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateChangesProvider).value;
    final currentGroupId = ref.watch(currentGroupIdProvider);
    final userId = user?.uid;

    final allMenus = widget.restaurant.menus;

    // Auto-skip if no menus with parseable prices
    final hasAffordableMenu = allMenus.any((m) => m.priceAsInt != null && m.priceAsInt! <= _budgetLimit);
    if (!hasAffordableMenu && !_didAutoSkip) {
      _didAutoSkip = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && currentGroupId != null) {
          ref.read(sessionRepositoryProvider).skipMenuSelection(
                currentGroupId,
                widget.session.id,
              );
        }
      });
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('15,000원 이하 메뉴가 없어 건너뜁니다...'),
          ],
        ),
      );
    }

    // Auto-select if only 1 affordable menu item
    final affordableMenus = allMenus.where((m) => m.priceAsInt != null && m.priceAsInt! <= _budgetLimit).toList();
    final hasSelected =
        userId != null && widget.session.menuSelections.containsKey(userId);
    if (affordableMenus.length == 1 && !hasSelected && !_didAutoSkip && userId != null && currentGroupId != null) {
      _didAutoSkip = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(sessionRepositoryProvider).selectMenu(
                currentGroupId,
                widget.session.id,
                userId,
                [affordableMenus.first.name],
              );
        }
      });
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              '${affordableMenus.first.name} 자동 선택!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '메뉴가 1개뿐이라 자동으로 선택되었습니다.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final mySelections =
        userId != null ? widget.session.menuSelections[userId] : null;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Restaurant info
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.restaurant, size: 32, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.restaurant.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.restaurant.category != null)
                          Text(
                            widget.restaurant.category!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Selection status
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '메뉴 선택: ${widget.session.menuSelections.length} / ${widget.session.attendingUserIds.length}명 완료',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              if (!hasSelected)
                CountdownTimerWidget(
                  expiresAt: widget.session.expiresAt?.toLocal() ??
                      DateTime.now().add(const Duration(seconds: 10)),
                  onTimeout: () {
                    if (mounted && currentGroupId != null) {
                      ref.read(sessionRepositoryProvider).skipMenuSelection(
                            currentGroupId,
                            widget.session.id,
                          );
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Menu list
          if (hasSelected)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 64, color: Colors.green),
                    const SizedBox(height: 16),
                    const Text(
                      '선택 완료',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...mySelections!.map((name) => Text(
                          '- $name',
                          style: const TextStyle(fontSize: 16),
                        )),
                    const SizedBox(height: 12),
                    Text(
                      '다른 참여자들의 선택을 기다리고 있습니다...',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '합계 ',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        _formatPrice(_totalPrice),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _totalPrice > _budgetLimit
                              ? Colors.red
                              : Colors.orange,
                        ),
                      ),
                      Text(
                        ' / ${_formatPrice(_budgetLimit)}',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '여러 메뉴를 선택할 수 있어요 (합계 15,000원 이내)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: allMenus.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        final menu = allMenus[index];
                        final isSelected = _selectedMenus.contains(menu.name);
                        final canAdd = _canAddMenu(menu);
                        final isDisabled = !isSelected && !canAdd;

                        return ListTile(
                          leading: Icon(
                            isSelected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: isSelected
                                ? Colors.orange
                                : isDisabled
                                    ? Colors.grey.shade300
                                    : Colors.grey,
                          ),
                          title: Text(
                            menu.name,
                            style: TextStyle(
                              color: isDisabled ? Colors.grey.shade400 : null,
                            ),
                          ),
                          trailing: Text(
                            menu.price,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDisabled ? Colors.grey.shade400 : null,
                            ),
                          ),
                          selected: isSelected,
                          selectedTileColor: Colors.orange.shade50,
                          onTap: isDisabled
                              ? null
                              : () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedMenus.remove(menu.name);
                                    } else {
                                      _selectedMenus.add(menu.name);
                                    }
                                  });
                                },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _selectedMenus.isEmpty || _isSubmitting
                          ? null
                          : () async {
                              setState(() => _isSubmitting = true);
                              try {
                                await ref
                                    .read(sessionRepositoryProvider)
                                    .selectMenu(
                                      currentGroupId!,
                                      widget.session.id,
                                      userId!,
                                      _selectedMenus.toList(),
                                    );
                              } finally {
                                if (mounted) {
                                  setState(() => _isSubmitting = false);
                                }
                              }
                            },
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _selectedMenus.isEmpty
                                  ? '메뉴를 선택해주세요'
                                  : '선택 완료 (${_selectedMenus.length}개)',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
