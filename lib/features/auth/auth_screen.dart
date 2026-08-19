import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../services/app_state.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _createAccount = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await context.read<AppState>().authenticate(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      createAccount: _createAccount,
    );
  }

  void _toggleMode() {
    final state = context.read<AppState>();
    state.clearAuthError();
    setState(() => _createAccount = !_createAccount);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.record_voice_over_rounded,
                      size: 64,
                      color: AppTheme.green,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Canto',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(color: AppTheme.greenDark),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _createAccount
                          ? 'Create your learning account'
                          : 'Welcome back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      key: const Key('usernameField'),
                      controller: _usernameController,
                      enabled: !state.authLoading,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter your username'
                          : value.trim().length < 3
                          ? 'Use at least 3 characters'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('passwordField'),
                      controller: _passwordController,
                      enabled: !state.authLoading,
                      autofillHints: [
                        _createAccount
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter your password'
                          : value.length < 8
                          ? 'Use at least 8 characters'
                          : null,
                    ),
                    if (state.authError != null) ...[
                      const SizedBox(height: 14),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          state.authError!,
                          key: const Key('authError'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.red,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      key: const Key('authSubmitButton'),
                      onPressed: state.authLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppTheme.green,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      child: state.authLoading
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(_createAccount ? 'CREATE ACCOUNT' : 'SIGN IN'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      key: const Key('authModeButton'),
                      onPressed: state.authLoading ? null : _toggleMode,
                      child: Text(
                        _createAccount
                            ? 'I ALREADY HAVE AN ACCOUNT'
                            : 'CREATE NEW ACCOUNT',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
