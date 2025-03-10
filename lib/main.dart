import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:codeflow/screens/dashboard_screen.dart';
import 'package:codeflow/screens/login_screen.dart';
import 'package:codeflow/screens/register_screen.dart';
import 'package:codeflow/auth%20and%20cloud/auth_provider.dart';
import 'package:codeflow/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_transition/page_transition.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Add error handling for mouse tracker issues
  _setupErrorHandling();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  HttpOverrides.global = MyHttpOverrides();
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// Set up error handling to specifically ignore the mouse tracker error
void _setupErrorHandling() {
  FlutterError.onError = (FlutterErrorDetails details) {
    final String error = details.exception.toString();
    if (error.contains('mouse_tracker.dart') &&
        error.contains(
            '(event is PointerAddedEvent) == (lastEvent is PointerRemovedEvent)')) {
      // Ignore this specific mouse tracker error
      print('Ignoring mouse tracker error (harmless in development)');
      return;
    }

    // For all other errors, use the default error handling
    FlutterError.presentError(details);

    // For severe errors in release mode, you might want to log to a service
    if (kReleaseMode) {
      // Log to a service if needed
    }
  };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CodeFlow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: AnimatedSplashScreen(
        splash: Image.asset('assets/2.png'),
        nextScreen: const MyHomePage(),
        splashTransition: SplashTransition.fadeTransition,
        animationDuration: const Duration(milliseconds: 800),
        duration: 1500,
        splashIconSize: 220,
        pageTransitionType: PageTransitionType.fade,
        backgroundColor: Colors.black,
      ),
      routes: {
        '/register': (context) => RegisterScreen(),
        '/login': (context) => LoginScreen(),
      },
    );
  }
}

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (data) {
        if (data != null && data.emailVerified) {
          return const DashboardScreen();
        } else {
          return const LoginScreen();
        }
      },
      error: (error, stackTrace) {
        return Scaffold(
          body: Center(
            child: Text(
              'Error: $error',
              style: const TextStyle(fontSize: 18, color: Colors.red),
            ),
          ),
        );
      },
      loading: () {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
