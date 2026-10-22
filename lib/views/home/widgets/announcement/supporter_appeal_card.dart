import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/home/announcement/announcement_model.dart';
import 'package:medito/providers/donation/supporter_appeal_experiment.dart';
import 'package:medito/providers/donation/supporter_appeal_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/services/notifications/local_notifications.dart';
import 'package:medito/views/donation/supporter_donation_screen.dart';

import 'announcement_widget.dart';

class SupporterAppealCard extends ConsumerWidget {
  const SupporterAppealCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final experiment = SupporterAppealExperiment(prefs);
    if (!experiment.showCard(DateTime.now())) return const SizedBox.shrink();
    Future<void> dismiss(String event) async {
      await prefs.setBool(SupporterAppealExperiment.dismissedKey, true);
      ref.invalidate(supporterAppealProvider);
      await LocalNotifications.cancelSafely(
        SupporterAppealExperiment.notificationId,
      );
      await SupporterAppealRuntime.log(event, prefs);
    }

    return Column(
      children: [
        _PaintObserver(
          onPaint: () {
            if (prefs.getBool(SupporterAppealExperiment.shownKey) == true ||
                WidgetsBinding.instance.lifecycleState !=
                    AppLifecycleState.resumed ||
                ModalRoute.of(context)?.isCurrent == false) {
              return;
            }
            unawaited(prefs.setBool(SupporterAppealExperiment.shownKey, true));
            unawaited(
              SupporterAppealRuntime.log('appeal_announcement_viewed', prefs),
            );
          },
          child: AnnouncementWidget(
            key: ValueKey(experiment.assignment!.id),
            announcement: const AnnouncementModel(
              id: SupporterAppealExperiment.name,
              text: SupporterAppealExperiment.announcementText,
              colorBackground: '#e9d5ff',
              colorText: '#4c1d95',
              ctaTitle: 'Donate now',
              ctaType: 'donation',
              ctaPath: 'https://donate.meditofoundation.org',
            ),
            onPressedDismiss: () => unawaited(dismiss('appeal_dismissed')),
            onCtaPressed: () {
              unawaited(
                SupporterAppealRuntime.log('appeal_donate_tapped', prefs),
              );
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SupporterDonationScreen(
                    campaignMetadata: experiment.ctaMetadata(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// IndexedStack builds hidden Home tabs, so build() is not an impression.
/// Observe painting within the screen instead, then log at most once per
/// assignment. No notification-delivery or offscreen-impression claims.
class _PaintObserver extends SingleChildRenderObjectWidget {
  const _PaintObserver({required this.onPaint, required super.child});
  final VoidCallback onPaint;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _AppealPaint(onPaint);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _AppealPaint renderObject,
  ) {
    renderObject.onPaint = onPaint;
  }
}

class _AppealPaint extends RenderProxyBox {
  _AppealPaint(this.onPaint);
  VoidCallback onPaint;
  bool _queued = false;
  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (_queued) return;
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final screen = Offset.zero & (view.physicalSize / view.devicePixelRatio);
    final rect = MatrixUtils.transformRect(
      getTransformTo(null),
      Offset.zero & size,
    );
    if (!rect.overlaps(screen)) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (attached) onPaint();
    });
  }
}
