import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/config.dart';
import 'features/auth/auth_screen.dart';
import 'features/conversation/conversation_screen.dart';
import 'features/lesson/lesson_screen.dart';
import 'features/progress/progress_screen.dart';
import 'features/shell/main_shell.dart';
import 'services/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppTheme.canvas,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppTheme.canvas,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const CantoApp());
}

class CantoApp extends StatelessWidget {
  const CantoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..initializeAuth(),
      child: MaterialApp.router(
        title: 'Canto',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) =>
          const AuthGate(authenticatedChild: MainShell()),
    ),
    GoRoute(
      path: '/lesson/:id',
      builder: (_, state) => AuthGate(
        authenticatedChild: LessonScreen(lessonId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/progress',
      builder: (context, state) =>
          const AuthGate(authenticatedChild: ProgressScreen()),
    ),
    GoRoute(
      path: '/conversation',
      builder: (context, state) =>
          const AuthGate(authenticatedChild: ConversationScreen()),
    ),
  ],
);

class AuthGate extends StatelessWidget {
  const AuthGate({required this.authenticatedChild, super.key});

  final Widget authenticatedChild;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.authResolved) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return state.isAuthenticated ? authenticatedChild : const AuthScreen();
  }
}
