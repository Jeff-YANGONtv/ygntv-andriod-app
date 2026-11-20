import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/ygntv_brand.dart';

const _ink = Color(0xFF09090D);
const _panel = Color(0xE817171E);
const _panelRaised = Color(0xFF202028);
const _muted = Color(0xFFA4A1AA);
const _red = Color(0xFFE5454F);
const _gold = Color(0xFFE8C27E);
const _telegramBlue = Color(0xFF229ED9);

const _footerLinks = <(String, String)>[
  ('Privacy Policy', 'https://ygntv.org/privacy-policy'),
  ('User Guide', 'https://ygntv.org/user-guide'),
  ('24/7 Contact Us', 'https://ygntv.org/contact'),
];

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
  bool _isSignUp = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _setMode(bool signUp) {
    if (_isSignUp == signUp) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSignUp = signUp);
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

  Future<void> _openFooterLink(String url) async {
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) _showMessage('Could not open this YGNTV page.');
    } catch (_) {
      if (mounted) _showMessage('Could not open this YGNTV page.');
    }
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
        fit: StackFit.expand,
        children: [
          const _MovingWaves(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, _) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(18, 22, 18, 22 + bottomInset),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: YgntvLogoMark(size: 82, radius: 21),
                        ),
                        const SizedBox(height: 22),
                        _buildAuthPanel(),
                        const SizedBox(height: 18),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 5,
                          runSpacing: 2,
                          children: [
                            for (var i = 0; i < _footerLinks.length; i++) ...[
                              if (i > 0)
                                const Text(
                                  '·',
                                  style: TextStyle(color: _muted, fontSize: 12),
                                ),
                              TextButton(
                                onPressed: () =>
                                    _openFooterLink(_footerLinks[i].$2),
                                style: TextButton.styleFrom(
                                  foregroundColor: _gold,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 3,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  textStyle: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: Text(_footerLinks[i].$1),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 9),
                        const Text(
                          'Developed by Yangon TV - Dev Team',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF85818B),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 19),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .11)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x77000000),
            blurRadius: 38,
            offset: Offset(0, 18),
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
          const SizedBox(height: 21),
          Text(
            _isSignUp ? 'Create your account' : 'Welcome back.',
            style: const TextStyle(
              fontSize: 25,
              height: 1.08,
              letterSpacing: -.65,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isSignUp
                ? 'Use your name, email, and password to get started.'
                : 'Sign in to continue watching.',
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 19),
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
                  const SizedBox(height: 12),
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
                const SizedBox(height: 12),
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
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) {
                    final password = value ?? '';
                    if (password.isEmpty) return 'Enter your password.';
                    if (password.length < 8) {
                      return 'Use at least 8 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 51,
                  child: FilledButton(
                    onPressed: widget.busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _red,
                      disabledBackgroundColor: _red.withValues(alpha: .55),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
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
                        : Text(
                            _isSignUp ? 'Create account' : 'Sign In',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                if (!_isSignUp) ...[
                  const SizedBox(height: 18),
                  const _OrDivider(),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SocialIconButton(
                        tooltip: 'Continue with Google',
                        onPressed: widget.busy
                            ? null
                            : () => _social(widget.onGoogle),
                        child: const Text(
                          'G',
                          style: TextStyle(
                            color: Color(0xFF4285F4),
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _SocialIconButton(
                        tooltip: 'Continue with Telegram',
                        onPressed: widget.busy
                            ? null
                            : () => _social(widget.onTelegram),
                        child: const Icon(
                          Icons.send_rounded,
                          color: _telegramBlue,
                          size: 21,
                        ),
                      ),
                    ],
                  ),
                ],
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
          height: 42,
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFFE1DEE3),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
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
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF35343C)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF35343C)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _red, width: 1.3),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _red, width: 1.3),
          ),
        ),
      ),
    ],
  );
}

class _SocialIconButton extends StatelessWidget {
  const _SocialIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: SizedBox(
      width: 56,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFF121218),
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: .14)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          padding: EdgeInsets.zero,
        ),
        child: child,
      ),
    ),
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Divider(color: Colors.white.withValues(alpha: .12), height: 1),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          'OR CONTINUE VIA',
          style: TextStyle(
            color: _muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.15,
          ),
        ),
      ),
      Expanded(
        child: Divider(color: Colors.white.withValues(alpha: .12), height: 1),
      ),
    ],
  );
}

class _MovingWaves extends StatefulWidget {
  const _MovingWaves();

  @override
  State<_MovingWaves> createState() => _MovingWavesState();
}

class _MovingWavesState extends State<_MovingWaves>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 15),
  )..repeat();

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    child: const SizedBox.expand(),
    builder: (context, child) =>
        CustomPaint(painter: _WavePainter(_motion.value), child: child),
  );
}

class _WavePainter extends CustomPainter {
  const _WavePainter(this.phase);

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _ink);
    if (size.isEmpty) return;

    final glowRect = Rect.fromCircle(
      center: Offset(size.width * .5, size.height * .72),
      radius: size.width * .78,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0x4D6E101A), Color(0x006E101A)],
          stops: const [0, 1],
        ).createShader(glowRect),
    );

    _drawWave(
      canvas,
      size,
      base: size.height * .79,
      amplitude: size.height * .065,
      offset: phase * math.pi * 2,
      color: const Color(0xFF16090D),
    );
    _drawWave(
      canvas,
      size,
      base: size.height * .85,
      amplitude: size.height * .055,
      offset: phase * math.pi * 2 + 1.9,
      color: const Color(0xFF3A0C13),
    );
    _drawWave(
      canvas,
      size,
      base: size.height * .91,
      amplitude: size.height * .042,
      offset: phase * math.pi * 2 + 3.6,
      color: const Color(0xFF861923),
    );
    _drawWave(
      canvas,
      size,
      base: size.height * .97,
      amplitude: size.height * .028,
      offset: phase * math.pi * 2 + 5.1,
      color: const Color(0xFF2A090E),
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size, {
    required double base,
    required double amplitude,
    required double offset,
    required Color color,
  }) {
    final path = Path()..moveTo(0, base);
    for (var x = 0.0; x <= size.width; x += 8) {
      final angle = (x / size.width) * math.pi * 2.2 + offset;
      final y = base + math.sin(angle) * amplitude;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .78));
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.phase != phase;
}
