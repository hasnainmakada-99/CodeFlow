import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:codeflow/Testing%20Designs/pod_test1.dart';

import 'package:codeflow/Testing%20Designs/ytPlaylistTest.dart';

import 'package:codeflow/auth%20and%20cloud/auth_provider.dart';
import 'package:codeflow/firebase_options.dart';

// import 'package:codeflow/firebase_options.dart';
import 'package:codeflow/screens/login_screen.dart';

import 'package:codeflow/screens/dashboard_screen.dart';
import 'package:codeflow/screens/register_screen.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:video_player/video_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: AnimatedSplashScreen(
        splash: SvgPicture.asset(
          'assets/2.svg',
        ),
        nextScreen: const MyHomePage(),
        splashTransition: SplashTransition.rotationTransition,
        duration: 1000,
        splashIconSize: 150,
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
            child: Text(error.toString()),
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

// testing
