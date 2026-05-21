import 'package:flutter_test/flutter_test.dart';
import 'package:minprice_flutter/main.dart';

void main() {
  test('app controller restores persisted favorites and cart quantities', () {
    final storage = MemoryKeyValueStore();
    final product = Product(
      uuid: 'tea-1',
      title: 'Чай Greenfield Summer Bouquet пакетированный 25шт',
      imageUrl: '',
      minPrice: 665,
      stores: const [
        StorePrice(chainName: 'SMALL', chainSlug: 'small', price: 665),
      ],
    );
    final first = AppController(
      api: ApiClient(storage: storage),
      storage: storage,
    );

    first.toggleFavorite(product);
    first.cart.add(product);
    first.cart.add(product);

    final restored = AppController(
      api: ApiClient(storage: storage),
      storage: storage,
    )..restoreLocalState();

    expect(restored.isFavorite(product), isTrue);
    expect(restored.favorites.single.uuid, product.uuid);
    expect(restored.cart.quantityFor(product.uuid), 2);
    expect(restored.cart.minimumTotal, 1330);
  });
}
