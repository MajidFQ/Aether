import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/chat/chat_history_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/flashcards/create_deck_screen.dart';
import 'screens/flashcards/deck_list_screen.dart';
import 'screens/flashcards/study_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/tasks/add_task_screen.dart';
import 'screens/timer/timer_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Load environment variables from assets/.env before the app starts.
  // The API key is read from here by ClaudeService at call time.
  await dotenv.load(fileName: 'assets/.env');

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'Aether',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B4FFF)),
            scaffoldBackgroundColor: const Color(0xFFF5F5F7),
            brightness: Brightness.light,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF5B4FFF),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF1E1E2E),
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          home: const AuthWrapper(),
          routes: {
            '/login': (_) => const LoginScreen(),
            '/chat': (_) => const ChatScreen(),
            '/chat-history': (_) => const ChatHistoryScreen(),
            '/timer': (_) => const TimerScreen(),
            '/flashcards': (_) => const DeckListScreen(),
            '/create-deck': (_) => const CreateDeckScreen(),
            '/study': (_) => const StudyScreen(),
            '/add-task': (_) => const AddTaskScreen(),
            '/profile': (_) => const ProfileScreen(),
            LoginScreenRoutes.home: (_) => const HomeScreen(),
            LoginScreenRoutes.register: (_) => const RegisterScreen(),
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
