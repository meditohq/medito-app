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
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          homeWidgetOrderClockProvider.overrideWithValue(
            () => DateTime(DateTime.now().year, 1, 1),
          ),
        ],
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
        await notifier.updateOrder(newOrder, movedWidget: HomeWidgetType.quote);

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
        await notifier.updateOrder(newOrder, movedWidget: HomeWidgetType.quote);

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
      const baseOrder = [
        HomeWidgetType.upNext,
        HomeWidgetType.shortcuts,
        HomeWidgetType.carousel,
        HomeWidgetType.quote,
        HomeWidgetType.products,
      ];
      const promoOrder = [
        HomeWidgetType.upNext,
        HomeWidgetType.shortcuts,
        HomeWidgetType.products,
        HomeWidgetType.carousel,
        HomeWidgetType.quote,
      ];

      late DateTime now;

      setUp(() async {
        now = DateTime(2026, 11, 27);
        await prefs.setStringList(
          SharedPreferenceConstants.homeWidgetOrder,
          baseOrder.map((e) => e.name).toList(),
        );
        container.dispose();
        container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            homeWidgetOrderClockProvider.overrideWithValue(() => now),
          ],
        );
      });

      List<String>? savedOrder() =>
          prefs.getStringList(SharedPreferenceConstants.homeWidgetOrder);

      test(
        'does not persist the promotional position on a no-op drag',
        () async {
          expect(container.read(homeWidgetOrderProvider), promoOrder);
          final notifier = container.read(homeWidgetOrderProvider.notifier);
          await notifier.updateOrder(
            promoOrder,
            movedWidget: HomeWidgetType.quote,
          );
          expect(savedOrder(), baseOrder.map((e) => e.name).toList());
          notifier.refreshOrder();
          expect(container.read(homeWidgetOrderProvider), promoOrder);

          await prefs.setInt(
            SharedPreferenceConstants.blackFridayDismissedYear,
            2026,
          );
          notifier.refreshOrder();
          expect(container.read(homeWidgetOrderProvider), baseOrder);
        },
      );

      test(
        'a products drag to the same position does not save the promo',
        () async {
          final notifier = container.read(homeWidgetOrderProvider.notifier);
          await notifier.updateOrder(
            promoOrder,
            movedWidget: HomeWidgetType.products,
          );
          expect(savedOrder(), baseOrder.map((e) => e.name).toList());
          final reordered = [...promoOrder]..remove(HomeWidgetType.shortcuts);
          reordered.add(HomeWidgetType.shortcuts);
          await notifier.updateOrder(
            reordered,
            movedWidget: HomeWidgetType.shortcuts,
          );
          expect(savedOrder(), [
            'upNext',
            'carousel',
            'quote',
            'shortcuts',
            'products',
          ]);
        },
      );

      test('restores the saved order when the promotion ends', () async {
        final notifier = container.read(homeWidgetOrderProvider.notifier);
        final reordered = [...promoOrder]..remove(HomeWidgetType.quote);
        reordered.insert(3, HomeWidgetType.quote);
        await notifier.updateOrder(
          reordered,
          movedWidget: HomeWidgetType.quote,
        );
        now = DateTime(2026, 12, 5);
        notifier.refreshOrder();
        expect(
          container.read(homeWidgetOrderProvider).map((e) => e.name).toList(),
          ['upNext', 'shortcuts', 'quote', 'carousel', 'products'],
        );
      });

      test(
        'preserves other section reorders while restoring products',
        () async {
          final notifier = container.read(homeWidgetOrderProvider.notifier);
          final reordered = [...promoOrder]..remove(HomeWidgetType.quote);
          reordered.insert(3, HomeWidgetType.quote);
          await notifier.updateOrder(
            reordered,
            movedWidget: HomeWidgetType.quote,
          );
          expect(container.read(homeWidgetOrderProvider), reordered);
          expect(savedOrder(), [
            'upNext',
            'shortcuts',
            'quote',
            'carousel',
            'products',
          ]);
        },
      );

      test(
        'moving Shortcuts away does not persist promoted products',
        () async {
          final notifier = container.read(homeWidgetOrderProvider.notifier);
          final reordered = [...promoOrder]..remove(HomeWidgetType.shortcuts);
          reordered.add(HomeWidgetType.shortcuts);
          await notifier.updateOrder(
            reordered,
            movedWidget: HomeWidgetType.shortcuts,
          );
          expect(savedOrder(), [
            'upNext',
            'carousel',
            'quote',
            'shortcuts',
            'products',
          ]);
        },
      );

      test(
        'moving a section between Shortcuts and products restores products',
        () async {
          final notifier = container.read(homeWidgetOrderProvider.notifier);
          final reordered = [...promoOrder]..remove(HomeWidgetType.quote);
          reordered.insert(2, HomeWidgetType.quote);
          await notifier.updateOrder(
            reordered,
            movedWidget: HomeWidgetType.quote,
          );
          expect(savedOrder(), [
            'upNext',
            'shortcuts',
            'quote',
            'carousel',
            'products',
          ]);
        },
      );

      test(
        'explicit products drag survives subsequent section drags',
        () async {
          final notifier = container.read(homeWidgetOrderProvider.notifier);
          final reordered = [...promoOrder]..remove(HomeWidgetType.products);
          reordered.insert(3, HomeWidgetType.products);
          await notifier.updateOrder(
            reordered,
            movedWidget: HomeWidgetType.products,
          );
          final secondOrder = [...reordered]..remove(HomeWidgetType.quote);
          secondOrder.insert(0, HomeWidgetType.quote);
          await notifier.updateOrder(
            secondOrder,
            movedWidget: HomeWidgetType.quote,
          );
          expect(savedOrder(), secondOrder.map((e) => e.name).toList());
        },
      );

      test('preserves a base order that was not promoted', () async {
        for (final productsIndex in [0, 2]) {
          final custom = [...baseOrder]..remove(HomeWidgetType.products);
          custom.insert(productsIndex, HomeWidgetType.products);
          await prefs.setStringList(
            SharedPreferenceConstants.homeWidgetOrder,
            custom.map((e) => e.name).toList(),
          );
          final notifier = container.read(homeWidgetOrderProvider.notifier);
          notifier.refreshOrder();
          expect(container.read(homeWidgetOrderProvider), custom);
          final reordered = [...custom]..remove(HomeWidgetType.quote);
          reordered.insert(0, HomeWidgetType.quote);
          await notifier.updateOrder(
            reordered,
            movedWidget: HomeWidgetType.quote,
          );
          expect(savedOrder(), reordered.map((e) => e.name).toList());
        }
      });

      test('keeps a custom products slot through repeated reorders', () async {
        await prefs.setStringList(SharedPreferenceConstants.homeWidgetOrder, [
          'upNext',
          'shortcuts',
          'carousel',
          'products',
          'quote',
        ]);
        final notifier = container.read(homeWidgetOrderProvider.notifier);
        await notifier.updateOrder([
          HomeWidgetType.quote,
          HomeWidgetType.upNext,
          HomeWidgetType.shortcuts,
          HomeWidgetType.products,
          HomeWidgetType.carousel,
        ], movedWidget: HomeWidgetType.quote);
        expect(savedOrder(), [
          'quote',
          'upNext',
          'shortcuts',
          'products',
          'carousel',
        ]);
        await notifier.updateOrder([
          HomeWidgetType.upNext,
          HomeWidgetType.quote,
          HomeWidgetType.shortcuts,
          HomeWidgetType.products,
          HomeWidgetType.carousel,
        ], movedWidget: HomeWidgetType.upNext);
        expect(savedOrder(), [
          'upNext',
          'quote',
          'shortcuts',
          'products',
          'carousel',
        ]);
      });

      test('dismissed promotion saves the actual drag', () async {
        await prefs.setInt(
          SharedPreferenceConstants.blackFridayDismissedYear,
          2026,
        );
        final notifier = container.read(homeWidgetOrderProvider.notifier);
        expect(container.read(homeWidgetOrderProvider), baseOrder);
        await notifier.updateOrder(
          promoOrder,
          movedWidget: HomeWidgetType.products,
        );
        expect(savedOrder(), promoOrder.map((e) => e.name).toList());
      });
    });
  });
}
