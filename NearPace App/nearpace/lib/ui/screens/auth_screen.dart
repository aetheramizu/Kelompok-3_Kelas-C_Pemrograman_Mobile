import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../config/firebase_bootstrap.dart';
import '../../state/nearpace_controller.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';
import '../widgets/nearpace_card.dart';

enum _AuthMode { signIn, signUp }

/// Entry and authentication screen supporting email/password sign-in, sign-up
/// with display name and optional city, and honest local preview mode when
/// Firebase is not configured.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _obscurePassword = true;
  String? _formErrorSummary;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _switchMode(_AuthMode mode) {
    if (_mode == mode) return;
    _formKey.currentState?.reset();
    setState(() {
      _mode = mode;
      _formErrorSummary = null;
    });
  }

  Future<void> _submit(NearPaceController controller) async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      setState(() {
        _formErrorSummary = 'Check the highlighted fields before continuing.';
      });
      return;
    }

    setState(() => _formErrorSummary = null);
    try {
      if (_mode == _AuthMode.signIn) {
        await controller.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await controller.signUp(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _nameController.text,
          city: _cityController.text,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _formErrorSummary = controller.authError ?? e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NearPaceController>();
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;

    final (
      statusTitle,
      statusDetail,
      statusColor,
      statusBg,
    ) = switch (controller.firebaseStatus) {
      FirebaseReady() => (
        'Firebase ready',
        'Connected to Firebase. Sign in or sign up with your account.',
        colors.performanceGreen,
        colors.deepGreenSurface,
      ),
      FirebaseUnconfigured(:final missingKeys) => (
        'Firebase not configured (local preview)',
        missingKeys.isEmpty
            ? 'Provide Firebase --dart-define values to connect backend '
                  'auth and Firestore.'
            : 'Missing keys: ${missingKeys.join(', ')}. Forms run in '
                  'local preview mode without cloud sign-in.',
        colors.textSecondary,
        colors.surfaceElevated,
      ),
      FirebaseInitFailed(:final message) => (
        'Firebase initialization failed',
        '$message. You can still test the UI in local preview mode.',
        colors.danger,
        colors.dangerSurface,
      ),
    };

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gutter = NearPaceSpacing.pageGutter(constraints.maxWidth);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: NearPaceSpacing.maxContentWidth,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    NearPaceSpacing.xl,
                    gutter,
                    NearPaceSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand mark & concise value statement.
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: CustomPaint(
                              painter: _NearPaceMarkPainter(
                                strokeColor: colors.onAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: NearPaceSpacing.sm),
                          Text(
                            'NearPace',
                            style: textTheme.headlineMedium?.copyWith(
                              letterSpacing: -0.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: NearPaceSpacing.md),
                      Text(
                        'Record runs on your phone, keep your history private, '
                        'and optionally join a weekly city leaderboard.',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: NearPaceSpacing.lg),

                      // Honest Firebase bootstrap readout.
                      NearPaceCard(
                        backgroundColor: statusBg,
                        borderColor: statusColor.withValues(alpha: 0.35),
                        padding: const EdgeInsets.all(NearPaceSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              controller.firebaseStatus is FirebaseReady
                                  ? Icons.cloud_done_outlined
                                  : Icons.info_outline_rounded,
                              size: 18,
                              color: statusColor,
                            ),
                            const SizedBox(width: NearPaceSpacing.xs),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    statusTitle,
                                    style: textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    statusDetail,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: NearPaceSpacing.lg),

                      // Mode switch + Auth form card.
                      NearPaceCard(
                        padding: const EdgeInsets.all(NearPaceSpacing.lg),
                        child: Form(
                          key: _formKey,
                          child: AutofillGroup(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SegmentedButton<_AuthMode>(
                                  showSelectedIcon: false,
                                  segments: const [
                                    ButtonSegment(
                                      value: _AuthMode.signIn,
                                      label: Text('Sign in'),
                                    ),
                                    ButtonSegment(
                                      value: _AuthMode.signUp,
                                      label: Text('Sign up'),
                                    ),
                                  ],
                                  selected: {_mode},
                                  onSelectionChanged: (selection) {
                                    if (selection.isNotEmpty) {
                                      _switchMode(selection.first);
                                    }
                                  },
                                ),
                                const SizedBox(height: NearPaceSpacing.lg),

                                if (_formErrorSummary != null) ...[
                                  Semantics(
                                    liveRegion: true,
                                    child: Container(
                                      padding: const EdgeInsets.all(
                                        NearPaceSpacing.sm,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.dangerSurface,
                                        borderRadius: BorderRadius.circular(
                                          NearPaceSpacing.radiusSm,
                                        ),
                                        border: Border.all(
                                          color: colors.danger.withValues(
                                            alpha: 0.45,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        _formErrorSummary!,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colors.danger,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: NearPaceSpacing.md),
                                ],

                                if (_mode == _AuthMode.signUp) ...[
                                  TextFormField(
                                    controller: _nameController,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [AutofillHints.name],
                                    maxLength: 40,
                                    onFieldSubmitted: (_) =>
                                        _submit(controller),
                                    decoration: const InputDecoration(
                                      labelText: 'Display name (optional)',
                                      hintText: 'e.g. Alief Pratama',
                                      counterText: '',
                                    ),
                                    validator: (value) {
                                      if (_mode != _AuthMode.signUp) {
                                        return null;
                                      }
                                      final trimmed = value?.trim() ?? '';
                                      if (trimmed.isNotEmpty &&
                                          trimmed.length < 2) {
                                        return 'Use at least 2 characters.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: NearPaceSpacing.sm),
                                  TextFormField(
                                    controller: _cityController,
                                    textInputAction: TextInputAction.next,
                                    maxLength: 60,
                                    onFieldSubmitted: (_) =>
                                        _submit(controller),
                                    decoration: const InputDecoration(
                                      labelText: 'City (optional)',
                                      hintText:
                                          'Used only for city leaderboard',
                                      counterText: '',
                                    ),
                                  ),
                                  const SizedBox(height: NearPaceSpacing.sm),
                                ],

                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.email],
                                  onFieldSubmitted: (_) => _submit(controller),
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    hintText: 'runner@example.com',
                                  ),
                                  validator: (value) {
                                    final trimmed = value?.trim() ?? '';
                                    if (trimmed.isEmpty) {
                                      return 'Enter your email address.';
                                    }
                                    if (!trimmed.contains('@') ||
                                        !trimmed.contains('.')) {
                                      return 'Enter a valid email address.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: NearPaceSpacing.sm),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: _mode == _AuthMode.signIn
                                      ? const [AutofillHints.password]
                                      : const [AutofillHints.newPassword],
                                  onFieldSubmitted: (_) => _submit(controller),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    hintText: 'At least 6 characters',
                                    suffixIcon: IconButton(
                                      tooltip: _obscurePassword
                                          ? 'Show password'
                                          : 'Hide password',
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    final text = value ?? '';
                                    if (text.isEmpty) {
                                      return 'Enter your password.';
                                    }
                                    if (text.length < 6) {
                                      return 'Password must be at least 6 '
                                          'characters.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: NearPaceSpacing.lg),
                                FilledButton(
                                  onPressed: controller.isAuthBusy
                                      ? null
                                      : () => _submit(controller),
                                  child: controller.isAuthBusy
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _mode == _AuthMode.signIn
                                              ? (controller.isLocalPreview
                                                    ? 'Sign in (preview)'
                                                    : 'Sign in')
                                              : (controller.isLocalPreview
                                                    ? 'Sign up (preview)'
                                                    : 'Sign up'),
                                        ),
                                ),
                                const SizedBox(height: NearPaceSpacing.xs),
                                Center(
                                  child: TextButton(
                                    onPressed: () => _switchMode(
                                      _mode == _AuthMode.signIn
                                          ? _AuthMode.signUp
                                          : _AuthMode.signIn,
                                    ),
                                    child: Text(
                                      _mode == _AuthMode.signIn
                                          ? "Don't have an account? Sign up"
                                          : 'Already have an account? Sign in',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colors.accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: NearPaceSpacing.md),

                      // Direct preview entry without typing credentials.
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: controller.enterQuickPreview,
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          label: const Text('Explore UI with sample runs'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NearPaceMarkPainter extends CustomPainter {
  const _NearPaceMarkPainter({required this.strokeColor});

  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.68)
      ..lineTo(size.width * 0.38, size.height * 0.34)
      ..lineTo(size.width * 0.56, size.height * 0.62)
      ..lineTo(size.width * 0.78, size.height * 0.28);

    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.28),
      3.0,
      Paint()..color = strokeColor,
    );
  }

  @override
  bool shouldRepaint(covariant _NearPaceMarkPainter oldDelegate) =>
      oldDelegate.strokeColor != strokeColor;
}
