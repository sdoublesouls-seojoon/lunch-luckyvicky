import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunch_lucky/features/auth/presentation/login_screen.dart';
import 'package:lunch_lucky/features/auth/data/auth_repository.dart';
import 'package:lunch_lucky/features/group/presentation/group_home_screen.dart';
import 'package:lunch_lucky/features/session/presentation/suggestion_screen.dart';
import 'package:lunch_lucky/features/roulette/presentation/roulette_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (authState.isLoading || authState.hasError) return null;

      final user = authState.value;
      final loggingIn = state.matchedLocation == '/';

      if (user != null && loggingIn) return '/home';
      if (user == null && !loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/home',
        builder: (context, state) => const GroupHomeScreen(),
      ),
      GoRoute(
        path: '/session',
        builder: (context, state) => const SuggestionScreen(),
      ),
      GoRoute(
        path: '/roulette',
        builder: (context, state) => const RouletteScreen(),
      ),
    ],
  );
});
