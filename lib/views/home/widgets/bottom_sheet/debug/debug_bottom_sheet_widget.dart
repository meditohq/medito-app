import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebugBottomSheetWidget extends ConsumerStatefulWidget {
  const DebugBottomSheetWidget({super.key});

  @override
  ConsumerState<DebugBottomSheetWidget> createState() =>
      _DebugBottomSheetWidgetState();
}

class _DebugBottomSheetWidgetState
    extends ConsumerState<DebugBottomSheetWidget> {
  List<String> _authLogs = [];
  bool _isLoadingLogs = true;

  @override
  void initState() {
    super.initState();
    // Only load auth logs in debug mode
    if (kDebugMode) {
      _loadAuthLogs();
    } else {
      _isLoadingLogs = false;
    }
  }

  Future<void> _loadAuthLogs() async {
    setState(() {
      _isLoadingLogs = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList('auth_debug_logs') ?? [];

      setState(() {
        _authLogs = logs.reversed.toList(); // Show newest first
        _isLoadingLogs = false;
      });
    } catch (e) {
      setState(() {
        _authLogs = ['Error loading logs: $e'];
        _isLoadingLogs = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var deviceAppAndUserInfo = ref.watch(deviceAppAndUserInfoProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          deviceAppAndUserInfo.when(
            skipLoadingOnRefresh: false,
            data: (data) => _debugItemsList(
              context,
              data,
            ),
            error: (err, stack) {
              final error = err is AppError ? err : const UnknownError();
              return MeditoErrorWidget(
                error: error,
                onTap: () => ref.refresh(meProvider),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
          // Only show auth logs section in debug mode
          if (kDebugMode) ...[
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Auth Debug Logs',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            _isLoadingLogs
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    height: 300,
                    child: _authLogs.isEmpty
                        ? const Center(child: Text('No auth logs available'))
                        : ListView.builder(
                            itemCount: _authLogs.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                child: Text(
                                  _authLogs[index],
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              );
                            },
                          ),
                  ),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Logs'),
                onPressed: _loadAuthLogs,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Column _debugItemsList(
    BuildContext context,
    String info,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          child: const Text(StringConstants.copy),
          onPressed: () => _handleCopy(context, info),
        ),
        _debugRowItem(
          context,
          info,
        ),
      ],
    );
  }

  Padding _debugRowItem(BuildContext context, String info) {
    var labelMedium = Theme.of(context).textTheme.labelMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SelectableText(
        info,
        style: labelMedium,
      ),
    );
  }

  void _handleCopy(BuildContext context, String deviceInfo) {
    var info =
        '${StringConstants.debugInfo}\n$deviceInfo\n${StringConstants.writeBelowThisLine}';

    // Only include auth logs in debug mode
    if (kDebugMode && _authLogs.isNotEmpty) {
      info += '\n\nAuth Logs:\n${_authLogs.join('\n')}';
    }

    Clipboard.setData(ClipboardData(text: info)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(StringConstants.debugInfoCopied),
          backgroundColor: ColorConstants.ebony,
        ),
      );
    });
  }
}
