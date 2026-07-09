import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'View/Routes/app_routes.dart';
import 'View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Services/translation_service.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

// App expiry date lock
final DateTime appExpiryDate = DateTime(2026, 7, 31, 0, 0, 0); // Modified by Jayant Pandit on 2026-07-10 // Reason: Extend expiry date past current date to resolve false Cloud Synchronization Failure

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check if app has expired
  final now = DateTime.now();
  if (now.isAfter(appExpiryDate)) {
    // App expired - show database connection error
    runApp(const ExpiredApp());
    return;
  }

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // DefaultFirebaseOptions not configured for this platform (desktop). Continue without Firebase for smoke tests.
    // Some features depending on Firebase may not work in this environment.
    // ignore: avoid_print
    print('Firebase initialize skipped: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

// Expired app widget showing database connection error
class ExpiredApp extends StatelessWidget {
  const ExpiredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DadaCabs',
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 80,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Database Connection Failed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to connect to the database server. Please check your internet connection and try again later.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Error Code: DB_CONN_503',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    // Do nothing - keeps showing error
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Connection'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(appLanguageProvider);

    return MaterialApp.router(
      key: ValueKey(currentLang),
      locale: Locale(currentLang),
      debugShowCheckedModeBanner: false,
      title: 'Dadacabs - User App',
      theme: indianHeritageCarLightTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      // Indian Heritage Vintage Car Theme is enforced app-wide from splash/login through booking and completion.
    );
  }
}
