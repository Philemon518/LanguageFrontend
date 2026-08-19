import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../models/curriculum.dart';
import '../../services/app_state.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshProgress();
    });
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account and learning progress. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('DELETE ACCOUNT'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await context.read<AppState>().deleteAccount();
    if (!deleted && mounted) {
      final message =
          context.read<AppState>().authError ?? 'Could not delete account';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final progress = state.progress;
    final skills = state.skills;
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Skills'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
            ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          children: [
            if (progress == null && skills.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Text(
                'Your skills',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Every exercise adds one permanent step when you first answer it correctly.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 18),
                _SummaryStrip(
                  xp: progress.totalXp,
                  lessons: progress.lessonsCompleted,
                ),
              ],
              const SizedBox(height: 22),
              ..._orderedSkills(skills).map(_SkillCard.new),
            ],
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 14),
            if (state.user != null)
              Text(
                'Signed in as ${state.user!.username}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('logoutButton'),
              onPressed: state.authLoading ? null : state.logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('LOG OUT'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('deleteAccountButton'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.red,
                side: const BorderSide(color: AppTheme.red, width: 2),
              ),
              onPressed: state.authLoading ? null : _confirmDeleteAccount,
              icon: state.authLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_outlined),
              label: const Text('DELETE ACCOUNT'),
            ),
          ],
        ),
      ),
    );
  }

  List<SkillProgress> _orderedSkills(List<SkillProgress> source) {
    const order = ['listening', 'speaking', 'reading', 'writing'];
    return order.map((skill) {
      return source.where((item) => item.skill == skill).firstOrNull ??
          SkillProgress(skill: skill, completed: 0, total: 0, percentage: 0);
    }).toList();
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.xp, required this.lessons});
  final int xp;
  final int lessons;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppTheme.border, width: 2),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _SummaryValue(icon: Icons.bolt_rounded, value: '$xp', label: 'XP'),
        Container(width: 2, height: 34, color: AppTheme.border),
        _SummaryValue(
          icon: Icons.flag_rounded,
          value: '$lessons',
          label: 'LESSONS',
        ),
      ],
    ),
  );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppTheme.orange, size: 28),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ],
      ),
    ],
  );
}

class _SkillCard extends StatelessWidget {
  const _SkillCard(this.data);
  final SkillProgress data;

  @override
  Widget build(BuildContext context) {
    final theme = _themeFor(data.skill);
    final fraction = data.total == 0 ? 0.0 : data.completed / data.total;
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border, width: 2),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: theme.$2, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: theme.$2,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(theme.$3, color: theme.$1, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.skill[0].toUpperCase() + data.skill.substring(1),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      theme.$4,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${data.percentage.round()}%',
                style: TextStyle(
                  color: theme.$1,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 14,
              value: fraction.clamp(0, 1),
              color: theme.$1,
              backgroundColor: AppTheme.border,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${data.completed} / ${data.total} exercises',
              style: const TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, IconData, String) _themeFor(String skill) => switch (skill) {
    'listening' => (
      AppTheme.blue,
      const Color(0xFFE4F6FE),
      Icons.hearing_rounded,
      'Hear tones, words, and meaning',
    ),
    'speaking' => (
      AppTheme.red,
      const Color(0xFFFFE8E8),
      Icons.mic_rounded,
      'Produce clear Cantonese aloud',
    ),
    'reading' => (
      AppTheme.purple,
      const Color(0xFFF5E9FE),
      Icons.menu_book_rounded,
      'Recognize Jyutping and characters',
    ),
    _ => (
      AppTheme.orange,
      const Color(0xFFFFF1D9),
      Icons.edit_rounded,
      'Build words and sentences',
    ),
  };
}
