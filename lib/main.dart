import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/ledger_controller.dart';
import 'firebase_options.dart';
import 'services/firestore_service.dart';
import 'theme.dart';
import 'views/setup_needed_view.dart';
import 'views/shell_view.dart';
import 'views/sign_in_view.dart';

Future<void> main() async {
  // Lecture 09: the binding must be initialised before any plugin is touched.
  WidgetsFlutterBinding.ensureInitialized();

  String? startupError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirestoreService.enableOfflinePersistence();
  } catch (e) {
    // Failing softly here means a missing firebase_options.dart produces a
    // screen with instructions rather than a black screen on stage.
    startupError = e.toString();
  }

  runApp(SavingsPadApp(startupError: startupError));
}

class SavingsPadApp extends StatelessWidget {
  const SavingsPadApp({super.key, this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) {
    if (startupError != null) {
      return MaterialApp(
        title: 'Savings Pad',
        theme: SavingsTheme.light,
        darkTheme: SavingsTheme.dark,
        home: SetupNeededView(message: startupError!),
      );
    }

    // Provider owns the controller for the lifetime of the app and disposes
    // its stream subscriptions automatically.
    return ChangeNotifierProvider<LedgerController>(
      create: (_) => LedgerController()..init(),
      child: MaterialApp(
        title: 'Savings Pad',
        debugShowCheckedModeBanner: false,
        theme: SavingsTheme.light,
        darkTheme: SavingsTheme.dark,
        home: const _AuthGate(),
      ),
    );
  }
}

/// Chooses between the sign-in screen and the app itself. Watching the
/// controller means sign-in and sign-out swap the screen with no navigation
/// code anywhere else.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final signedIn = context.select<LedgerController, bool>((c) => c.isSignedIn);
    return signedIn ? const ShellView() : const SignInView();
  }
}
