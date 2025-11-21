import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:medito/utils/logger.dart';

/// Service for handling iOS App Tracking Transparency (ATT) system permission
/// This is a system-level iOS feature, not specific to any analytics SDK
class AppTrackingTransparencyService {
  AppTrackingTransparencyService._();

  static final AppTrackingTransparencyService instance =
      AppTrackingTransparencyService._();

  /// Request App Tracking Transparency permission (iOS only)
  /// Shows the system dialog asking user to allow tracking
  /// Returns the authorization status after user responds
  Future<TrackingStatus> requestTrackingPermission() async {
    if (!Platform.isIOS) {
      if (kDebugMode) {
        AppLogger.d('ATT', 'Not iOS platform, skipping ATT request');
      }
      return TrackingStatus.notSupported;
    }

    try {
      // Check the current status
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;

      // If not determined, request authorization
      if (status == TrackingStatus.notDetermined) {
        // Wait a moment before showing dialog to ensure UI is ready
        await Future.delayed(const Duration(milliseconds: 200));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }

      // Get the final status after user responds
      final finalStatus =
          await AppTrackingTransparency.trackingAuthorizationStatus;

      if (kDebugMode) {
        AppLogger.d('ATT', 'Tracking authorization status: $finalStatus');
      }

      return finalStatus;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.w('ATT', 'Error requesting tracking authorization: $e');
      }
      return TrackingStatus.notDetermined;
    }
  }

  /// Get the current tracking authorization status without requesting permission
  Future<TrackingStatus> getTrackingStatus() async {
    if (!Platform.isIOS) {
      return TrackingStatus.notSupported;
    }

    try {
      return await AppTrackingTransparency.trackingAuthorizationStatus;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.w('ATT', 'Error getting tracking status: $e');
      }
      return TrackingStatus.notDetermined;
    }
  }

  /// Check if tracking is currently authorized
  Future<bool> isTrackingAuthorized() async {
    final status = await getTrackingStatus();
    return status == TrackingStatus.authorized;
  }
}
