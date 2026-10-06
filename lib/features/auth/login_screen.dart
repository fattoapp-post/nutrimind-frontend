import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/supabase.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String _role = 'patient';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    final auth = supabase.auth;
    try {
      if (_isSignUp) {
        await auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {'role': _role, 'display_name': _name.text.trim()},
        );
      } else {
        await auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } catch (e) {
      // I campi restano compilati: l'utente può correggere e riprovare.
      if (mounted) _show(AppError.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _show('Inserisci la tua email, poi tocca di nuovo "Password dimenticata?".');
      return;
    }
    setState(() => _loading = true);
    try {
      await supabase.auth.resetPasswordForEmail(email);
      // Stesso messaggio anche se l'email non esiste: non si rivela chi è registrato
      if (mounted) _show('Se l\'email è registrata riceverai un link per reimpostare la password.');
    } catch (e) {
      if (mounted) _show(AppError.from(e).message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('NutriMind',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 32),
                  if (_isSignUp) ...[
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Nome'),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'patient', label: Text('Paziente')),
                        ButtonSegment(value: 'nutritionist', label: Text('Nutrizionista')),
                      ],
                      selected: {_role},
                      onSelectionChanged: (s) => setState(() => _role = s.first),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: Text(_loading
                        ? 'Attendi...'
                        : (_isSignUp ? 'Registrati' : 'Accedi')),
                  ),
                  if (!_isSignUp)
                    TextButton(
                      onPressed: _loading ? null : _resetPassword,
                      child: const Text('Password dimenticata?'),
                    ),
                  TextButton(
                    onPressed: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(_isSignUp
                        ? 'Hai già un account? Accedi'
                        : 'Non hai un account? Registrati'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}