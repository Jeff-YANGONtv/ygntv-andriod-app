import 'package:flutter/material.dart';

import '../widgets/ygntv_brand.dart';

const _ink = Color(0xFF09090D);
const _panel = Color(0xFF17171E);
const _panelRaised = Color(0xFF202028);
const _muted = Color(0xFFA4A1AA);
const _red = Color(0xFFE5454F);
const _gold = Color(0xFFE8C27E);
const _telegramBlue = Color(0xFF229ED9);

typedef SignInCallback = Future<String?> Function(
  String email,
  String password,
);
typedef SignUpCallback = Future<String?> Function(
  String name,
  String email,
  String password,
);
typedef SocialSignInCallback = Future<String?> Function();

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    required this.busy,
    required this.onSignIn,
    required this.onSignUp,
    required this.onGoogle,
    required this.onTelegram,
    super.key,
  });

  final bool busy;
  final SignInCallback onSignIn;
  final SignUpCallback onSignUp;
  final SocialSignInCallback onGoogle;
  final SocialSignInCallback onTelegram;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _isSignUp = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _setMode(bool signUp) {
    if (_isSignUp == signUp) return;
    setState(() {
      _isSignUp = signUp;
      _confirmPassword.clear();
    });
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    final message = _isSignUp
        ? await widget.onSignUp(
            _name.text.trim(),
            _email.text.trim(),
            _password.text,
          )
        : await widget.onSignIn(_email.text.trim(), _password.text);
    if (message != null && mounted) _showMessage(message);
  }

  Future<void> _social(SocialSignInCallback callback) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final message = await callback();
    if (message != null && mounted) _showMessage(message);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: _ink,
      body: Stack(
        children: [
          const Positioned.fill(child: _LaunchGlow()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottomInset),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _BrandHeader(),
                        const SizedBox(height: 27),
                        _buildAuthPanel(),
                        const SizedBox(height: 19),
                        const Text(
                          'Myanmar stories, movies and series — all in one place.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 19),
                        const Text(
                          'UNOFFICIAL ANDROID RELEASE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF696771),
                            fontSize: 9,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 21),
      decoration: BoxDecoration(
        color: _panel.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 44,
            offset: Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _modeButton(
                  'Sign In',
                  selected: !_isSignUp,
                  onTap: () => _setMode(false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _modeButton(
                  'Sign Up',
                  selected: _isSignUp,
                  onTap: () => _setMode(true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Text(
            _isSignUp ? 'Join Yangon TV.' : 'Welcome back.',
            style: const TextStyle(
              fontSize: 31,
              height: 1.03,
              letterSpacing: -1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            _isSignUp
                ? 'Create an account to get started.'
                : 'Sign in to continue watching.',
            style: const TextStyle(color: _muted, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 23),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isSignUp) ...[
                  _InputField(
                    label: 'Display name',
                    hint: 'Your name',
                    icon: Icons.person_outline_rounded,
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Enter your name.'
                        : null,
                  ),
                  const SizedBox(height: 14),
                ],
                _InputField(
                  label: 'Email address',
                  hint: 'you@example.com',
                  icon: Icons.mail_outline_rounded,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Enter your email address.';
                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(email)) {
                      return 'Enter a valid email address.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _InputField(
                  label: 'Password',
                  hint: 'At least 8 characters',
                  icon: Icons.lock_outline_rounded,
                  controller: _password,
                  obscureText: !_showPassword,
                  suffix: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 19,
                      color: _muted,
                    ),
                  ),
                  textInputAction: _isSignUp
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!_isSignUp) _submit();
                  },
                  validator: (value) {
                    final password = value ?? '';
                    if (password.isEmpty) return 'Enter your password.';
                    if (password.length < 8) {
                      return 'Use at least 8 characters.';
                    }
                    return null;
                  },
                ),
                if (_isSignUp) ...[
                  const SizedBox(height: 14),
                  _InputField(
                    label: 'Confirm password',
                    hint: 'Repeat your password',
                    icon: Icons.lock_outline_rounded,
                    controller: _confirmPassword,
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) => value != _password.text
                        ? 'Passwords do not match.'
                        : null,
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: widget.busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _red,
                      disabledBackgroundColor: _red.withValues(alpha: .55),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: widget.busy
                        ? const SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isSignUp ? 'Create account' : 'Sign In',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                const _OrDivider(),
                const SizedBox(height: 16),
                _SocialButton(
                  label: 'Continue with Google',
                  leading: const Text(
                    'G',
                    style: TextStyle(
                      color: Color(0xFF4285F4),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  onPressed: widget.busy
                      ? null
                      : () => _social(widget.onGoogle),
                ),
                const SizedBox(height: 10),
                _SocialButton(
                  label: 'Continue with Telegram',
                  leading: const Icon(
                    Icons.send_rounded,
                    color: _telegramBlue,
                    size: 19,
                  ),
                  onPressed: widget.busy
                      ? null
                      : () => _social(widget.onTelegram),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? _red : _panelRaised,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.busy ? null : onTap,
        child: SizedBox(
          height: 43,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffix,
    this.onFieldSubmitted,
    this.validator,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFE1DEE3),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          autocorrect: false,
          enableSuggestions: !obscureText,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: _muted, size: 19),
            suffixIcon: suffix,
            filled: true,
            fillColor: const Color(0xFF0E0E13),
            hintStyle: const TextStyle(color: Color(0xFF77747D), fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: Color(0xFF35343C)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: Color(0xFF35343C)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _red, width: 1.3),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _red, width: 1.3),
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const YgntvLogoMark(size: 72, radius: 20),
        const SizedBox(height: 12),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
            children: [
              TextSpan(text: 'YANGON '),
              TextSpan(
                text: 'TV',
                style: TextStyle(color: _red),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'YOUR NEXT STORY STARTS HERE',
          style: TextStyle(
            color: _gold,
            fontSize: 9,
            letterSpacing: 2.1,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _LaunchGlow extends StatelessWidget {
  const _LaunchGlow();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.1),
          radius: 1.15,
          colors: [Color(0xFF291317), _ink],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: Colors.white.withValues(alpha: .11), height: 1),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: Colors.white.withValues(alpha: .11), height: 1),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.leading,
    required this.onPressed,
  });

  final String label;
  final Widget leading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 49,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFF121218),
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: .11)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
