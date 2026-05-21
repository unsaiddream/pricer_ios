import 'package:flutter_test/flutter_test.dart';
import 'package:minprice_flutter/main.dart';

void main() {
  test(
    'price alert manager gates checks to a random daytime slot once per day',
    () {
      final now = DateTime(2026, 5, 22, 10);

      expect(
        PriceAlertManager.isDailyCheckDue(now: now, nextCheckAt: null),
        isTrue,
      );
      expect(
        PriceAlertManager.isDailyCheckDue(
          now: now,
          nextCheckAt: DateTime(2026, 5, 22, 11),
        ),
        isFalse,
      );

      final next = PriceAlertManager.nextDailyCheckDate(
        afterCompletedCheckAt: now,
        random: () => 0.5,
      );

      expect(next.year, 2026);
      expect(next.month, 5);
      expect(next.day, 23);
      expect(next.hour, 15);
      expect(next.minute, 0);
    },
  );

  test(
    'price alert manager only emits drops above threshold and updates baseline',
    () {
      final manager = PriceAlertManager();
      final product = Product(
        uuid: 'milk-1',
        title: 'Молоко 3.2%',
        imageUrl: '',
        minPrice: 1000,
      );

      manager.seedPrices([product]);
      final quiet = manager.evaluatePriceDrop(
        product.copyWith(minPrice: 970),
        thresholdPercent: 5,
      );
      final loud = manager.evaluatePriceDrop(
        product.copyWith(minPrice: 900),
        thresholdPercent: 5,
      );

      expect(quiet, isNull);
      expect(loud?.percent, 7);
      expect(manager.storedPrices[product.uuid], 900);
    },
  );

  test(
    'app controller persists price alert settings and next random check',
    () {
      final storage = MemoryKeyValueStore();
      final app = AppController(
        api: ApiClient(storage: storage),
        storage: storage,
      );

      app.setPriceAlertsEnabled(
        true,
        now: DateTime(2026, 5, 22, 8),
        random: () => 0.25,
      );
      app.setPriceAlertThreshold(10);

      final restored = AppController(
        api: ApiClient(storage: storage),
        storage: storage,
      )..restoreLocalState();

      expect(restored.priceAlertsEnabled, isTrue);
      expect(restored.priceAlertThreshold, 10);
      expect(restored.nextPriceCheckAt, DateTime(2026, 5, 22, 12));
    },
  );
}
