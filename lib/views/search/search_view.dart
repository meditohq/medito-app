import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/views/search/search_results.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/widgets/widgets.dart';

/// The Search tab. A search field pinned to the top, results below, with the
/// bottom nav bar staying visible — you leave search by switching tabs, like
/// any other tab, rather than dismissing an overlay.
class SearchView extends ConsumerStatefulWidget {
  const SearchView({super.key});

  @override
  ConsumerState<SearchView> createState() => SearchViewState();
}

class SearchViewState extends ConsumerState<SearchView> {
  static const _searchDebounce = Duration(milliseconds: 500);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _query = '';

  /// Called by the nav host when the Search tab is selected, so tapping Search
  /// drops the cursor straight into the field ready to type. Re-tapping the
  /// already-active tab re-opens the keyboard too: [FocusNode.requestFocus] is
  /// a no-op when the field already holds focus (e.g. the keyboard was
  /// dismissed by scrolling), so in that case we ask the platform to show it.
  void focusInput() {
    if (!mounted) return;
    if (_focusNode.hasFocus) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } else {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (!mounted) return;
      // The search backend is ASCII-only.
      final asciiQuery = value.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
      setState(() => _query = asciiQuery);
      if (asciiQuery.isNotEmpty) {
        unawaited(
          ref
              .read(analyticsServiceProvider)
              .logEvent(
                name: AnalyticsEventConstants.searchPerformed,
                parameters: {
                  AnalyticsEventConstants.paramSearchTerm: asciiQuery,
                  AnalyticsEventConstants.paramSearchTermLength:
                      asciiQuery.length,
                },
              ),
        );
      }
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _query = '');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              padding16,
              padding12,
              padding16,
              padding8,
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                return MeditoTextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  hintText: l10n.searchMeditations,
                  textInputAction: TextInputAction.search,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: MeditoIcon(
                      assetName: MeditoIcons.search,
                      color: onSurface.withOpacityValue(0.6),
                      size: 18,
                    ),
                  ),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l10n.clearSearch,
                          iconSize: 20,
                          onPressed: _clear,
                          icon: Icon(
                            Icons.cancel,
                            color: onSurface.withOpacityValue(0.6),
                          ),
                        ),
                  onChanged: _onChanged,
                );
              },
            ),
          ),
          Expanded(
            child: SearchResults(
              query: _query,
              onBeforeNavigate: _focusNode.unfocus,
            ),
          ),
        ],
      ),
    );
  }
}
