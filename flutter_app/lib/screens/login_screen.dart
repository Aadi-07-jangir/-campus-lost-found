import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import 'signup_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  bool _obscure = true;
  late AnimationController _anim;

  @override void initState() { super.initState(); _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward(); }
  @override void dispose() { _emailC.dispose(); _passC.dispose(); _anim.dispose(); super.dispose(); }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(email: _emailC.text.trim(), password: _passC.text);
    if (ok && mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: FadeTransition(
              opacity: _anim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: 96,
                      width: 96,
                      decoration: BoxDecoration(
                        gradient: AppTheme.accentGradient,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.35),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.travel_explore_rounded, color: Colors.white, size: 46),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('Find it before it disappears.', style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Text('Campus Lost & Found with a darker, smarter vibe.', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg.withOpacity(0.84),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.28),
                          blurRadius: 30,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Login', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 6),
                        Text('Track lost things, respond fast, and connect instantly.', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 22),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(controller: _emailC, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
                                validator: (v) { if (v == null || v.isEmpty) return 'Required'; if (!v.contains('@')) return 'Invalid'; return null; }),
                              const SizedBox(height: 16),
                              TextFormField(controller: _passC, obscureText: _obscure,
                                decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded), onPressed: () => setState(() => _obscure = !_obscure))),
                                validator: (v) { if (v == null || v.isEmpty) return 'Required'; if (v.length < 8) return 'Min 8 chars'; return null; }),
                            ],
                          ),
                        ),
                        if (auth.error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.danger.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.danger.withOpacity(0.28)),
                            ),
                            child: Text(auth.error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13), textAlign: TextAlign.center),
                          ),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(height: 54, child: ElevatedButton(onPressed: auth.isLoading ? null : _handleLogin, child: auth.isLoading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Enter App'))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text("Don't have an account? ", style: Theme.of(context).textTheme.bodyMedium),
                    GestureDetector(onTap: () { auth.clearError(); Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())); },
                      child: const Text('Create one', style: TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
