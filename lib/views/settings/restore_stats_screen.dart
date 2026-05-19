import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/services/stats_backup_service.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/widgets/snackbar_widget.dart' show showSnackBar;
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';

/// Lists every stats snapshot stored on the device (across users) and lets
/// the user restore one. Snapshots are written automatically by
/// [StatsBackupService] on every successful `postStats`, with the most
/// recent 20 retained.
class RestoreStatsScreen extends ConsumerStatefulWidget {
  const RestoreStatsScreen({super.key});

  @override
  ConsumerState<RestoreStatsScreen> createState() => _RestoreStatsScreenState();
}

class _RestoreStatsScreenState extends ConsumerState<RestoreStatsScreen> {
  late Future<List<StatsBackup>> _backupsFuture;

  @override
  void initState() {
    super.initState();
    _backupsFuture = _loadBackups();
  }

  Future<List<StatsBackup>> _loadBackups() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final service = StatsBackupService(prefs: prefs);
    final backups = await service.getAllBackupsAcrossUsers();
    backups.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return backups;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.pop(context),
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              centerTitle: false,
              automaticallyImplyLeading: false,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              toolbarHeight: 56.0,
              pinned: true,
              floating: true,
              elevation: 0.0,
              title: HomeHeaderWidget(greeting: l10n.restorePreviousStats),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Text(
                  l10n.restorePreviousStatsExplainer,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
            FutureBuilder<List<StatsBackup>>(
              future: _backupsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final backups = snapshot.data ?? const <StatsBackup>[];
                if (backups.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          l10n.noBackupsAvailable,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _BackupRow(backup: backups[index], onRestored: _refresh),
                    childCount: backups.length,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _refresh() {
    setState(() {
      _backupsFuture = _loadBackups();
    });
  }
}

class _BackupRow extends ConsumerWidget {
  final StatsBackup backup;
  final VoidCallback onRestored;
  const _BackupRow({required this.backup, required this.onRestored});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final stats = backup.stats;
    final when = DateTime.fromMillisecondsSinceEpoch(backup.timestamp);
    final minutes = (stats.totalTimeListened / 60000).round();
    final sessionCount =
        stats.audioCompleted?.length ?? stats.totalTracksCompleted;

    return InkWell(
      onTap: () => _confirmRestore(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(width: 0.7, color: ColorConstants.onyx),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.restore_outlined,
                color: Theme.of(context).colorScheme.onSurface,
                size: 24,
              ),
              width16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(when),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.backupSummary(
                        stats.streakCurrent,
                        sessionCount,
                        minutes,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurface,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _confirmRestore(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.restoreStatsConfirmTitle),
        content: Text(l10n.restoreStatsConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.restore),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      final manager = ref.read(statsManagerProvider);
      await manager.restoreFromBackup(backup.stats);
      await ref.read(statsProvider.notifier).refreshFromLocal();
      if (!context.mounted) return;
      showSnackBar(context, l10n.restoreStatsSuccess);
      onRestored();
    } catch (e) {
      if (!context.mounted) return;
      showSnackBar(context, l10n.restoreStatsFailed);
    }
  }
}
