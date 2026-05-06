import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nova3d_frontend/features/auth/presentation/forgot_password_page.dart';
import 'package:nova3d_frontend/features/auth/presentation/oauth_callback_page.dart';
import 'package:nova3d_frontend/features/auth/presentation/sign_in_page.dart';
import 'package:nova3d_frontend/features/auth/presentation/sign_up_page.dart';
import 'package:nova3d_frontend/features/auth/state/auth_provider.dart';
import 'package:nova3d_frontend/features/chat/presentation/chat_page.dart';
import 'package:nova3d_frontend/features/home/presentation/home_page.dart';
import 'package:nova3d_frontend/features/home/presentation/model_preview_page.dart';
import 'package:nova3d_frontend/features/home/presentation/settings_page.dart';
import 'package:nova3d_frontend/features/subscription/presentation/subscription_page.dart';
import 'package:nova3d_frontend/shared/widgets/app_layout.dart';
import 'package:nova3d_frontend/shared/widgets/auth_guard.dart';

// Bridges Riverpod auth state into a ChangeNotifier so GoRouter can listen
// via refreshListenable without recreating the router on every auth change.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRefreshNotifier(ref);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      // Read current auth state each time redirect fires — never watch.
      final authState = ref.read(authProvider);
      final isAuthenticated = authState.status == AuthStatus.authenticated;
      final isLoading = authState.status == AuthStatus.loading;
      final path = state.uri.path;

      const publicPaths = {
        '/signin',
        '/signup',
        '/forgot-password',
        '/oauth-callback',
      };

      if (isLoading) return null;
      if (!isAuthenticated && !publicPaths.contains(path)) return '/signin';
      if (isAuthenticated && publicPaths.contains(path)) return '/';
      return null;
    },
    routes: [
      // ── Public routes ────────────────────────────────────────────────────
      GoRoute(
        path: '/signin',
        builder: (_, _) => const SignInPage(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, _) => const SignUpPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/oauth-callback',
        builder: (_, _) => const OAuthCallbackPage(),
      ),

      // ── Authenticated shell ──────────────────────────────────────────────
      ShellRoute(
        builder: (_, _, child) => AuthGuard(
          child: AppLayout(child: child),
        ),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const HomePage(),
          ),
          GoRoute(
            path: '/chat/:id',
            builder: (_, state) => ChatPage(
              conversationId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/subscription',
            builder: (_, _) => const SubscriptionPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) => const SettingsPage(),
          ),
          GoRoute(
            path: '/model-preview',
            builder: (_, _) => const ModelPreviewPage(),
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Center(
        child: Text(
          'Page not found: ${state.uri}',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    ),
  );

  ref.onDispose(() {
    router.dispose();
    notifier.dispose();
  });

  return router;
});
