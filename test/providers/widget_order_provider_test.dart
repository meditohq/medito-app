import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/home/widget_order_provider.dart';
import 'package:medito/constants/enums/home_widget_type.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('HomeWidgetOrderNotifier', () {
    late SharedPreferences prefs;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    });

    tearDown(() async {
      container.dispose();
      await prefs.clear();
    });

    group('Default order', () {
      test('returns default order when no custom order saved', () async {
        await prefs.setBool(
          SharedPreferenceConstants.blackFridayDismissed,
          true,
        );
        final order = container.read(homeWidgetOrderProvider);
        expect(order, [
          HomeWidgetType.upNext,
          HomeWidgetType.shortcuts,
          HomeWidgetType.carousel,
          HomeWidgetType.quote,
          HomeWidgetType.products,
        ]);
      });
    });

    group('Custom order', () {
      test('returns saved custom order', () async {
        final customOrder = [
          HomeWidgetType.quote,
          HomeWidgetType.shortcuts,
          HomeWidgetType.products,
          HomeWidgetType.carousel,
        ];
        await prefs.setStringList(
          SharedPreferenceConstants.homeWidgetOrder,
          customOrder.map((e) => e.name).toList(),
        );

        final order = container.read(homeWidgetOrderProvider);
        expect(order, [HomeWidgetType.upNext, ...customOrder]);
      });

      test('preserves custom order when not Black Friday', () async {
        final customOrder = [
          HomeWidgetType.carousel,
          HomeWidgetType.shortcuts,
          HomeWidgetType.quote,
          HomeWidgetType.products,
        ];
        await prefs.setStringList(
          SharedPreferenceConstants.homeWidgetOrder,
          customOrder.map((e) => e.name).toList(),
        );
        await prefs.setBool(
          SharedPreferenceConstants.blackFridayDismissed,
          true,
        );

        final order = container.read(homeWidgetOrderProvider);
        // When not Black Friday (current date), should return custom order with upNext prepended
        expect(order, [HomeWidgetType.upNext, ...customOrder]);
      });
    });

    group('Black Friday dismissal', () {
      test('restores custom order when dismissed', () async {
        final customOrder = [
          HomeWidgetType.carousel,
          HomeWidgetType.shortcuts,
          HomeWidgetType.quote,
          HomeWidgetType.products,
        ];
        await prefs.setStringList(
          SharedPreferenceConstants.homeWidgetOrder,
          customOrder.map((e) => e.name).toList(),
        );
        await prefs.setBool(
          SharedPreferenceConstants.blackFridayDismissed,
          true,
        );

        final order = container.read(homeWidgetOrderProvider);
        // Should return custom order when dismissed, even during Black Friday, with upNext prepended
        expect(order, [HomeWidgetType.upNext, ...customOrder]);
      });

      test('restores custom order after dismissing and refreshing', () async {
        final customOrder = [
          HomeWidgetType.quote,
          HomeWidgetType.carousel,
          HomeWidgetType.shortcuts,
          HomeWidgetType.products,
        ];
        await prefs.setStringList(
          SharedPreferenceConstants.homeWidgetOrder,
          customOrder.map((e) => e.name).toList(),
        );
        await prefs.setBool(
          SharedPreferenceConstants.blackFridayDismissed,
          true,
        );

        final notifier = container.read(homeWidgetOrderProvider.notifier);
        notifier.refreshOrder();

        final order = container.read(homeWidgetOrderProvider);
        expect(order, [HomeWidgetType.upNext, ...customOrder]);
      });
    });

    group('Order updates', () {
      test('updateOrder saves new order', () async {
        final newOrder = [
          HomeWidgetType.quote,
          HomeWidgetType.carousel,
          HomeWidgetType.shortcuts,
          HomeWidgetType.products,
        ];

        final notifier = container.read(homeWidgetOrderProvider.notifier);
        await notifier.updateOrder(newOrder);

        final savedOrder = prefs.getStringList(
          SharedPreferenceConstants.homeWidgetOrder,
        );
        expect(savedOrder, newOrder.map((e) => e.name).toList());
      });

      test('updateOrder updates state immediately', () async {
        final newOrder = [
          HomeWidgetType.quote,
          HomeWidgetType.carousel,
          HomeWidgetType.shortcuts,
          HomeWidgetType.products,
        ];

        final notifier = container.read(homeWidgetOrderProvider.notifier);
        await notifier.updateOrder(newOrder);

        final order = container.read(homeWidgetOrderProvider);
        expect(order, newOrder);
      });

      test('refreshOrder reloads from preferences', () async {
        final customOrder = [
          HomeWidgetType.carousel,
          HomeWidgetType.shortcuts,
          HomeWidgetType.quote,
          HomeWidgetType.products,
        ];
        await prefs.setStringList(
          SharedPreferenceConstants.homeWidgetOrder,
          customOrder.map((e) => e.name).toList(),
        );
        await prefs.setBool(
          SharedPreferenceConstants.blackFridayDismissed,
          true,
        );

        final notifier = container.read(homeWidgetOrderProvider.notifier);
        notifier.refreshOrder();

        final order = container.read(homeWidgetOrderProvider);
        expect(order, [HomeWidgetType.upNext, ...customOrder]);
      });
    });

    group('Edge cases', () {
      test('handles missing shortcuts gracefully', () async {
        final customOrder = [
          HomeWidgetType.carousel,
          HomeWidgetType.quote,
          HomeWidgetType.products,
        ];
        await prefs.setStringList(
          SharedPreferenceConstants.homeWidgetOrder,
          customOrder.map((e) => e.name).toList(),
        );

        final order = container.read(homeWidgetOrderProvider);
        // Should return order with upNext prepended when shortcuts missing
        expect(order, [HomeWidgetType.upNext, ...customOrder]);
      });

      test('handles missing products gracefully', () async {
        final customOrder = [
          HomeWidgetType.shortcuts,
          HomeWidgetType.carousel,
          HomeWidgetType.quote,
        ];
        await prefs.setStringList(
          SharedPreferenceConstants.homeWidgetOrder,
          customOrder.map((e) => e.name).toList(),
        );

        final order = container.read(homeWidgetOrderProvider);
        // Should return order with upNext prepended when products missing
        expect(order, [HomeWidgetType.upNext, ...customOrder]);
      });

      test('handles partial custom order', () async {
        final customOrder = [HomeWidgetType.shortcuts, HomeWidgetType.products];
        await prefs.setStringList(
          SharedPreferenceConstants.homeWidgetOrder,
          customOrder.map((e) => e.name).toList(),
        );

        final order = container.read(homeWidgetOrderProvider);
        expect(order, [HomeWidgetType.upNext, ...customOrder]);
      });
    });

    group('Custom order preservation during Black Friday', () {
      test(
        'updateOrder preserves custom order when saving during Black Friday',
        () async {
          final originalCustomOrder = [
            HomeWidgetType.carousel,
            HomeWidgetType.shortcuts,
            HomeWidgetType.quote,
            HomeWidgetType.products,
          ];
          await prefs.setStringList(
            SharedPreferenceConstants.homeWidgetOrder,
            originalCustomOrder.map((e) => e.name).toList(),
          );

          final notifier = container.read(homeWidgetOrderProvider.notifier);

          final reorderedOrder = [
            HomeWidgetType.carousel,
            HomeWidgetType.shortcuts,
            HomeWidgetType.products,
            HomeWidgetType.quote,
          ];

          await notifier.updateOrder(reorderedOrder);

          final savedOrder = prefs.getStringList(
            SharedPreferenceConstants.homeWidgetOrder,
          );
          final savedOrderTypes = savedOrder!
              .map((e) => HomeWidgetType.fromString(e))
              .toList();

          expect(savedOrderTypes.length, 4);
          expect(savedOrderTypes.contains(HomeWidgetType.shortcuts), true);
          expect(savedOrderTypes.contains(HomeWidgetType.products), true);
          expect(savedOrderTypes.contains(HomeWidgetType.carousel), true);
          expect(savedOrderTypes.contains(HomeWidgetType.quote), true);
        },
      );
    });
  });
}
