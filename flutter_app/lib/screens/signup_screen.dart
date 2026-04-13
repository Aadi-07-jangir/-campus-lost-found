import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import 'home_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameC = TextEditingController();
  final _emailC = TextEditingController();
  final _phoneC = TextEditingController();
  final _collegeC = TextEditingController();
  final _passC = TextEditingController();
  bool _obscure = true;

  @override void dispose() { _nameC.dispose(); _emailC.dispose(); _phoneC.dispose(); _collegeC.dispose(); _passC.dispose(); super.dispose(); }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.signUp(name: _nameC.text.trim(), email: _emailC.text.trim(), password: _passC.text, phone: _phoneC.text.trim(), collegeName: _collegeC.text.trim());
    if (ok && mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Build your lost-and-found identity.', style: Theme.of(context).textTheme.headlineLarge, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text('A clean profile makes every recovery feel faster and smoother.', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg.withOpacity(0.86),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.26),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(controller: _nameC, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline_rounded)),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                        const SizedBox(height: 14),
                        TextFormField(controller: _emailC, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
                          validator: (v) { if (v == null || v.isEmpty) return 'Required'; if (!v.contains('@')) return 'Invalid'; return null; }),
                        const SizedBox(height: 14),
                        TextFormField(controller: _phoneC, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)', prefixIcon: Icon(Icons.call_outlined))),
                        const SizedBox(height: 14),
                        TextFormField(controller: _collegeC, decoration: const InputDecoration(labelText: 'College Name', prefixIcon: Icon(Icons.school_outlined)),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                        const SizedBox(height: 14),
                        TextFormField(controller: _passC, obscureText: _obscure,
                          decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded), onPressed: () => setState(() => _obscure = !_obscure))),
                          validator: (v) { if (v == null || v.isEmpty) return 'Required'; if (v.length < 8) return 'Min 8 chars'; return null; }),
                        if (auth.error != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.danger.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.danger.withOpacity(0.25)),
                            ),
                            child: Text(auth.error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13), textAlign: TextAlign.center),
                          ),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(height: 54, child: ElevatedButton(onPressed: auth.isLoading ? null : _handleSignUp, child: auth.isLoading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Create Account'))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Already have an account? ', style: Theme.of(context).textTheme.bodyMedium),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Text('Login', style: TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w700))),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
