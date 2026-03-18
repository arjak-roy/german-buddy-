import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/app_providers.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    await ref.read(authControllerProvider.notifier).signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );

    final state = ref.read(authControllerProvider);
    state.whenOrNull(
      error: (error, _) {
        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
      },
    );
  }

  Future<void> _sendPasswordReset() async {
    final messenger = ScaffoldMessenger.of(context);
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter your email to reset password.')),
      );
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .sendPasswordResetEmail(email: email);

    final state = ref.read(authControllerProvider);
    state.when(
      loading: () {},
      data: (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Password reset link sent.')),
        );
      },
      error: (error, _) {
        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
      },
    );
  }

  Future<void> _onGoogleSignInSlide() async {
    final messenger = ScaffoldMessenger.of(context);

    await ref.read(authControllerProvider.notifier).signInWithGoogle();

    final state = ref.read(authControllerProvider);
    state.whenOrNull(
      error: (error, _) {
        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
      },
    );
  }

  Future<void> _onSignUpSlide() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SignupScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authAction = ref.watch(authControllerProvider);
    final isLoading = authAction.isLoading;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3F5FA), Color(0xFFECEFF8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const horizontalPadding = 20.0;
              final verticalPadding =
                  constraints.maxHeight < 760 ? 12.0 : 20.0;
              final availableWidth =
                  (constraints.maxWidth - (horizontalPadding * 2))
                      .clamp(280.0, 520.0);

              return Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: availableWidth,
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D4ED8),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x442563EB),
                                    blurRadius: 16,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Center(
                            child: Text(
                              'Kumpel Ai',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Center(
                            child: Text(
                              'Welcome back!',
                              style: TextStyle(
                                fontSize: 18,
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              hintText: 'name@example.com',
                            ),
                            validator: (value) {
                              final email = (value ?? '').trim();
                              if (email.isEmpty) return 'Email is required';
                              final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                              if (!regex.hasMatch(email)) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Text(
                                'Password',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: isLoading ? null : _sendPasswordReset,
                                child: const Text('Forgot password?'),
                              ),
                            ],
                          ),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              hintText: '........',
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if ((value ?? '').isEmpty) {
                                return 'Password is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: const Color(0xFF1D4ED8),
                                foregroundColor: Colors.white,
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Sign in',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'OR CONTINUE WITH',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _RollingSlideButton(
                            idleText: 'Slide to continue with Google',
                            activeText: 'Release to continue with Google',
                            onCompleted: _onGoogleSignInSlide,
                            thumbChild: const Text(
                              'G',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _onSignUpSlide,
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text(
                                'Create account',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                side: const BorderSide(color: Color(0xFF1D4ED8)),
                                foregroundColor: const Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: Text(
                              'Use Google slider or tap create account.',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RollingSlideButton extends StatefulWidget {
  final String idleText;
  final String activeText;
  final Widget thumbChild;
  final Future<void> Function() onCompleted;

  const _RollingSlideButton({
    required this.idleText,
    required this.activeText,
    required this.thumbChild,
    required this.onCompleted,
  });

  @override
  State<_RollingSlideButton> createState() => _RollingSlideButtonState();
}

class _RollingSlideButtonState extends State<_RollingSlideButton> {
  double _slideProgress = 0;
  bool _isTriggeringSlide = false;

  void _onSlideUpdate(DragUpdateDetails details, double maxTrackTravel) {
    if (_isTriggeringSlide || maxTrackTravel <= 0) return;
    final delta = details.delta.dx / maxTrackTravel;
    setState(() {
      _slideProgress = (_slideProgress + delta).clamp(0.0, 1.0);
    });
  }

  Future<void> _onSlideEnd() async {
    if (_isTriggeringSlide) return;
    if (_slideProgress < 0.9) {
      setState(() {
        _slideProgress = 0;
      });
      return;
    }

    setState(() {
      _isTriggeringSlide = true;
      _slideProgress = 1;
    });

    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    await widget.onCompleted();
    if (!mounted) return;

    setState(() {
      _isTriggeringSlide = false;
      _slideProgress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        const thumbSize = 46.0;
        final trackWidth = constraints.maxWidth;
        final maxTrackTravel =
            (trackWidth - thumbSize - 12).clamp(0.0, double.infinity);
        final left = 6 + (_slideProgress * maxTrackTravel);

        return Container(
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFCFD9EC),
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Center(
                child: Text(
                  _slideProgress < 0.9 ? widget.idleText : widget.activeText,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                left: left,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) =>
                      _onSlideUpdate(details, maxTrackTravel),
                  onHorizontalDragEnd: (_) => _onSlideEnd(),
                  child: Transform.rotate(
                    angle: _slideProgress * math.pi * 2.0,
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D4ED8),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x3A1D4ED8),
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(child: widget.thumbChild),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
