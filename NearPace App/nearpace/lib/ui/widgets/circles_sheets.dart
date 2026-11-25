import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../domain/run_group.dart';
import '../../state/nearpace_controller.dart';
import '../../theme/nearpace_colors.dart';
import '../../theme/nearpace_spacing.dart';

/// Bottom sheet to create a new running circle with optional description and
/// weekly distance goal. Generates a unique 6-character invite code automatically.
class CreateCircleSheet extends StatefulWidget {
  const CreateCircleSheet({super.key});

  static Future<RunGroup?> show(BuildContext context) {
    return showModalBottomSheet<RunGroup>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateCircleSheet(),
    );
  }

  @override
  State<CreateCircleSheet> createState() => _CreateCircleSheetState();
}

class _CreateCircleSheetState extends State<CreateCircleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _goalController = TextEditingController();

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    final goalText = _goalController.text.trim().replaceAll(',', '.');
    final double? weeklyGoalKm = goalText.isEmpty
        ? null
        : double.tryParse(goalText);

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final controller = context.read<NearPaceController>();
      final created = await controller.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        weeklyGoalKm: weeklyGoalKm,
      );
      if (mounted) {
        Navigator.of(context).pop(created);
      }
    } on GroupRepositoryException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _submitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not create circle: $e';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(NearPaceSpacing.radiusLg),
          ),
          border: Border(
            top: BorderSide(color: colors.border),
            left: BorderSide(color: colors.border),
            right: BorderSide(color: colors.border),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              NearPaceSpacing.md,
              NearPaceSpacing.sm,
              NearPaceSpacing.md,
              MediaQuery.of(context).padding.bottom + NearPaceSpacing.md,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: NearPaceSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Create Circle',
                          style: textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: colors.textSecondary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  Text(
                    'Start a private weekly distance challenge. A unique '
                    '6-character invite code will be generated automatically.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: NearPaceSpacing.md),

                  if (_errorMessage != null) ...[
                    _SheetErrorBanner(message: _errorMessage!),
                    const SizedBox(height: NearPaceSpacing.sm),
                  ],

                  TextFormField(
                    key: const ValueKey('create-circle-name'),
                    controller: _nameController,
                    maxLength: 50,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Circle name',
                      hintText: 'e.g. Losari Morning Pacers',
                    ),
                    validator: (value) {
                      final trimmed = (value ?? '').trim();
                      if (trimmed.isEmpty) {
                        return 'Enter a circle name.';
                      }
                      if (trimmed.length > 50) {
                        return 'Maximum 50 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: NearPaceSpacing.sm),

                  TextFormField(
                    key: const ValueKey('create-circle-description'),
                    controller: _descriptionController,
                    maxLength: 160,
                    maxLines: 2,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'Share your weekly vibe or route spot',
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().length > 160) {
                        return 'Maximum 160 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: NearPaceSpacing.sm),

                  TextFormField(
                    key: const ValueKey('create-circle-goal'),
                    controller: _goalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Weekly goal in km (optional)',
                      hintText: 'e.g. 25',
                      suffixText: 'km / week',
                    ),
                    validator: (value) {
                      final trimmed = (value ?? '').trim().replaceAll(',', '.');
                      if (trimmed.isEmpty) return null;
                      final parsed = double.tryParse(trimmed);
                      if (parsed == null || parsed <= 0) {
                        return 'Enter a positive distance in km.';
                      }
                      if (parsed > 1000) {
                        return 'Goal must be 1,000 km or less.';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: NearPaceSpacing.lg),

                  FilledButton.icon(
                    key: const ValueKey('create-circle-submit'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: colors.onAccent,
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onAccent,
                            ),
                          )
                        : const Icon(Icons.group_add_rounded),
                    label: Text(
                      _submitting ? 'Creating...' : 'Create Circle',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
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

/// Bottom sheet to join an existing running circle via its 6-character invite code.
class JoinCircleSheet extends StatefulWidget {
  const JoinCircleSheet({super.key});

  static Future<RunGroup?> show(BuildContext context) {
    return showModalBottomSheet<RunGroup>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const JoinCircleSheet(),
    );
  }

  @override
  State<JoinCircleSheet> createState() => _JoinCircleSheetState();
}

class _JoinCircleSheetState extends State<JoinCircleSheet> {
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final code = normalizeInviteCode(_codeController.text);
    if (!isValidInviteCode(code)) {
      setState(() {
        _errorMessage =
            'Enter a valid 6-character code (letters & numbers, no 0/O/1/I).';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final controller = context.read<NearPaceController>();
      final joined = await controller.joinGroupByCode(code);
      if (mounted) {
        Navigator.of(context).pop(joined);
      }
    } on GroupRepositoryException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _submitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not join circle: $e';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(NearPaceSpacing.radiusLg),
          ),
          border: Border(
            top: BorderSide(color: colors.border),
            left: BorderSide(color: colors.border),
            right: BorderSide(color: colors.border),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              NearPaceSpacing.md,
              NearPaceSpacing.sm,
              NearPaceSpacing.md,
              MediaQuery.of(context).padding.bottom + NearPaceSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: NearPaceSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Join with Code',
                        style: textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: colors.textSecondary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Text(
                  'Ask a friend for their 6-character circle invite code to '
                  'compete on the same weekly leaderboard.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: NearPaceSpacing.md),

                if (_errorMessage != null) ...[
                  _SheetErrorBanner(message: _errorMessage!),
                  const SizedBox(height: NearPaceSpacing.sm),
                ],

                TextField(
                  key: const ValueKey('join-circle-code'),
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    letterSpacing: 6,
                    fontWeight: FontWeight.w800,
                    color: colors.accentText,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    LengthLimitingTextInputFormatter(6),
                    const _UpperCaseTextFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Invite code',
                    hintText: 'NDP4CE',
                    counterText: '',
                  ),
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: NearPaceSpacing.lg),

                FilledButton.icon(
                  key: const ValueKey('join-circle-submit'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: colors.onAccent,
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onAccent,
                          ),
                        )
                      : const Icon(Icons.login_rounded),
                  label: Text(
                    _submitting ? 'Joining...' : 'Join Circle',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  const _UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class _SheetErrorBanner extends StatelessWidget {
  const _SheetErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.npColors;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NearPaceSpacing.sm,
        vertical: NearPaceSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.dangerSurface,
        borderRadius: BorderRadius.circular(NearPaceSpacing.radiusSm),
        border: Border.all(color: colors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: colors.danger),
          const SizedBox(width: NearPaceSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(color: colors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
