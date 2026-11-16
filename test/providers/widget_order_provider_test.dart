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
        await prefs.setInt(
          SharedPreferenceConstants.blackFridayDismissedYear,
          DateTime.now().year,
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
        await prefs.setInt(
          SharedPreferenceConstants.blackFridayDismissedYear,
          DateTime.now().year,
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
        await prefs.setInt(
          SharedPreferenceConstants.blackFridayDismissedYear,
          DateTime.now().year,
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
        await prefs.setInt(
          SharedPreferenceConstants.blackFridayDismissedYear,
          DateTime.now().year,
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
        await prefs.setInt(
          SharedPreferenceConstants.blackFridayDismissedYear,
          DateTime.now().year,
        );

        final notifier = container.read(homeWidgetOrderProvider.notifier);
        notifier.refreshOrder();

        final order = container.read(homeWidgetOrderProvider);
        expect(order, [HomeWidgetType.upNext, ...customOrder]);
      });
    });

    group('Edge cases', () {
      test('adds back a missing section at the bottom', () async {
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
        expect(order, [
          HomeWidgetType.upNext,
          ...customOrder,
          HomeWidgetType.shortcuts,
        ]);
      });

      test('adds back products for orders saved before it existed', () async {
        final customOrder = [
          HomeWidgetType.shortcuts,
          HomeWidgetType.carousel,
          HomeWidgetType.quote,
          HomeWidgetType.upNext,
        ];
        await prefs.setStringList(
          SharedPreferenceConstants.homeWidgetOrder,
          customOrder.map((e) => e.name).toList(),
        );
        await prefs.setInt(
          SharedPreferenceConstants.blackFridayDismissedYear,
          DateTime.now().year,
        );

        final order = container.read(homeWidgetOrderProvider);
        expect(order, [...customOrder, HomeWidgetType.products]);

        container.read(homeWidgetOrderProvider.notifier).refreshOrder();
        expect(container.read(homeWidgetOrderProvider), [
          ...customOrder,
          HomeWidgetType.products,
        ]);
      });

      test('fills in every section for a partial order', () async {
        final customOrder = [HomeWidgetType.shortcuts, HomeWidgetType.products];
        await prefs.setStringList(
          SharedPreferenceConstants.homeWidgetOrder,
          customOrder.map((e) => e.name).toList(),
        );

        final order = container.read(homeWidgetOrderProvider);
        expect(order, [
          HomeWidgetType.upNext,
          ...customOrder,
          HomeWidgetType.carousel,
          HomeWidgetType.quote,
        ]);
      });

      test('drops duplicates and unknown section names', () async {
        await prefs.setStringList(SharedPreferenceConstants.homeWidgetOrder, [
          'quote',
          'removedSection',
          'shortcuts',
          'quote',
        ]);

        final order = container.read(homeWidgetOrderProvider);
        expect(order, [
          HomeWidgetType.upNext,
          HomeWidgetType.quote,
          HomeWidgetType.shortcuts,
          HomeWidgetType.carousel,
          HomeWidgetType.products,
        ]);
      });
    });

    group('Custom order preservation during Black Friday', () {
      // Black Friday lifts `products` to sit directly under Shortcuts. The
      // visible order is what the user sees, not the order they own, so saving
      // it as-is makes the promo layout permanent once the week ends.
      const defaultBaseOrder = [
        HomeWidgetType.upNext,
        HomeWidgetType.shortcuts,
        HomeWidgetType.carousel,
        HomeWidgetType.quote,
        HomeWidgetType.products,
      ];
      const defaultBlackFridayOrder = [
        HomeWidgetType.upNext,
        HomeWidgetType.shortcuts,
        HomeWidgetType.products,
        HomeWidgetType.carousel,
        HomeWidgetType.quote,
      ];

      test('a reorder that moves nothing does not save the promo layout', () {
        // The bug: the old slot guess reinserted products at index 2 for a
        // default order, so the saved order equalled the Black Friday one and
        // products stayed pinned under Shortcuts after the week ended.
        expect(
          restoreBaseOrderFromBlackFridayOrder(
            defaultBlackFridayOrder,
            baseOrder: defaultBaseOrder,
          ),
          defaultBaseOrder,
        );
      });

      test('keeps the user reorder of the other sections', () {
        // Quote dragged above carousel while the promo is on. Products must
        // still return to the end, where it sat before the promo.
        expect(
          restoreBaseOrderFromBlackFridayOrder(const [
            HomeWidgetType.upNext,
            HomeWidgetType.shortcuts,
            HomeWidgetType.products,
            HomeWidgetType.quote,
            HomeWidgetType.carousel,
          ], baseOrder: defaultBaseOrder),
          const [
            HomeWidgetType.upNext,
            HomeWidgetType.shortcuts,
            HomeWidgetType.quote,
            HomeWidgetType.carousel,
            HomeWidgetType.products,
          ],
        );
      });

      test(
        'a base order that already has products under shortcuts is kept',
        () {
          const baseOrder = [
            HomeWidgetType.upNext,
            HomeWidgetType.shortcuts,
            HomeWidgetType.products,
            HomeWidgetType.carousel,
            HomeWidgetType.quote,
          ];

          expect(
            restoreBaseOrderFromBlackFridayOrder(
              baseOrder,
              baseOrder: baseOrder,
            ),
            baseOrder,
          );
        },
      );

      test('a base order with products early keeps that slot', () {
        const baseOrder = [
          HomeWidgetType.products,
          HomeWidgetType.upNext,
          HomeWidgetType.shortcuts,
          HomeWidgetType.carousel,
          HomeWidgetType.quote,
        ];
        const visible = [
          HomeWidgetType.upNext,
          HomeWidgetType.shortcuts,
          HomeWidgetType.products,
          HomeWidgetType.carousel,
          HomeWidgetType.quote,
        ];

        expect(
          restoreBaseOrderFromBlackFridayOrder(visible, baseOrder: baseOrder),
          baseOrder,
        );
      });

      test(
        'a products move the user made themselves is saved as they left it',
        () {
          // Products dragged to the end, away from Shortcuts: that is the user's
          // own choice, not the promo injection.
          expect(
            restoreBaseOrderFromBlackFridayOrder(
              defaultBaseOrder,
              baseOrder: defaultBaseOrder,
            ),
            defaultBaseOrder,
          );
          // Products dragged to the top.
          const productsFirst = [
            HomeWidgetType.products,
            HomeWidgetType.upNext,
            HomeWidgetType.shortcuts,
            HomeWidgetType.carousel,
            HomeWidgetType.quote,
          ];
          expect(
            restoreBaseOrderFromBlackFridayOrder(
              productsFirst,
              baseOrder: defaultBaseOrder,
            ),
            productsFirst,
          );
        },
      );

      test('an order without products or shortcuts is untouched', () {
        const noProducts = [
          HomeWidgetType.upNext,
          HomeWidgetType.shortcuts,
          HomeWidgetType.carousel,
        ];
        expect(
          restoreBaseOrderFromBlackFridayOrder(
            noProducts,
            baseOrder: defaultBaseOrder,
          ),
          noProducts,
        );

        const noShortcuts = [
          HomeWidgetType.upNext,
          HomeWidgetType.products,
          HomeWidgetType.carousel,
        ];
        expect(
          restoreBaseOrderFromBlackFridayOrder(
            noShortcuts,
            baseOrder: defaultBaseOrder,
          ),
          noShortcuts,
        );
      });

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
