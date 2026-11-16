import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';
import 'shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _hide = true;
  bool _remember = false;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _email.text = app.savedEmail;
    _remember = app.rememberMe;
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim().toLowerCase();
    if (email.isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await app.login(email, _pass.text, _remember);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()));
    } on AppError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String hint, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        hintStyle: t(13, c: AppColors.muted),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.blue, width: 1.5)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Frame(
        child: ColoredBox(
          color: AppColors.bg,
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppTopBar(showAvatar: false),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome back', style: t(28, w: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text(
                    'Sign in to monitor traffic, view live feeds and manage alerts.',
                    style: t(14, c: AppColors.muted, h: 1.5),
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email address',
                            style: t(13, w: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          style: t(14),
                          decoration: _dec('Enter your email address'),
                        ),
                        const SizedBox(height: 18),
                        Text('Password', style: t(13, w: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _pass,
                          obscureText: _hide,
                          style: t(14),
                          decoration: _dec(
                            'Enter your password',
                            suffix: IconButton(
                              icon: Icon(
                                  _hide
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.muted),
                              onPressed: () =>
                                  setState(() => _hide = !_hide),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _remember = !_remember),
                              child: Row(children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: _remember
                                        ? AppColors.blue
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: _remember
                                            ? AppColors.blue
                                            : const Color(0xFFB0B8C6)),
                                  ),
                                  child: _remember
                                      ? const Icon(Icons.check,
                                          size: 14, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Text('Remember me',
                                    style: t(12, c: AppColors.muted)),
                              ]),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => showInfo(
                                  context,
                                  'Forgot password?',
                                  'Passwords are managed by your system administrator. Please contact them to reset your password.'),
                              child: Text('Forgot password?',
                                  style: t(12,
                                      w: FontWeight.w600, c: AppColors.blue)),
                            ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!,
                              style: t(12, c: AppColors.red)),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _busy ? null : _signIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.blue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : Text('Sign in',
                                    style: t(14,
                                        w: FontWeight.w600, c: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text.rich(
                      TextSpan(
                        style: t(12.5, c: AppColors.muted, h: 1.6),
                        children: [
                          const TextSpan(text: 'Test account credentials\n'),
                          const TextSpan(text: 'Email: '),
                          TextSpan(
                              text: 'free@gmail.com',
                              style: t(12.5, w: FontWeight.w700)),
                          const TextSpan(text: '   Password: '),
                          TextSpan(
                              text: 'freeaccount',
                              style: t(12.5, w: FontWeight.w700)),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: AppColors.blueSoft,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined,
                            size: 20, color: AppColors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Use the account provided by your system administrator to access your workspace.',
                            style: t(12, c: AppColors.muted, h: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: Column(children: [
                      Text('Need access to Smart Traffic?',
                          style: t(13, c: AppColors.muted)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => showInfo(
                            context,
                            'Contact your administrator',
                            'Accounts are created by your system administrator. There is no self sign-up for Smart Traffic.'),
                        child: Text('Contact your administrator',
                            style: t(13,
                                w: FontWeight.w600, c: AppColors.blue)),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}
