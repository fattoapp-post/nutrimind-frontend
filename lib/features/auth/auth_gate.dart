import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/account_service.dart';
import '../../core/app_error.dart';
import '../../core/models.dart';
import '../../core/supabase.dart';
import '../nutritionist/patients_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Sessione assente: login. Sessione presente: carica il profilo e apre
/// l'area del paziente o quella del nutrizionista in base al ruolo.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = supabase.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? auth.currentSession;
        if (session == null) return const LoginScreen();
        return _RoleRouter(key: ValueKey(session.user.id));
      },
    );
  }
}

class _RoleRouter extends StatefulWidget {
  const _RoleRouter({super.key});

  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  late Future<Profile> _profile = AccountService.getProfile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Profile>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(AppError.from(snapshot.error!).message),
                TextButton(
                  onPressed: () => setState(() => _profile = AccountService.getProfile()),
                  child: const Text('Riprova'),
                ),
                TextButton(onPressed: AccountService.signOut, child: const Text('Esci')),
              ]),
            ),
          );
        }
        final profile = snapshot.data!;
        return profile.isNutritionist ? PatientsScreen(profile: profile) : const HomeScreen();
      },
    );
  }
}
