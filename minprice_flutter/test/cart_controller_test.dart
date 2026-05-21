import 'package:flutter_test/flutter_test.dart';
import 'package:minprice_flutter/main.dart';

void main() {
  test('cart quantity changes recalculate item count and total', () {
    final cart = CartController();
    final product = Product(
      uuid: 'tomato-1',
      title: 'Помидоры розовые Казахстан 1кг',
      imageUrl: '',
      minPrice: 899,
      stores: const [
        StorePrice(
          chainName: 'MagnumGO',
          chainSlug: 'magnumgo',
          price: 899,
          currency: '₸',
        ),
      ],
    );

    cart.add(product);
    cart.add(product);
    cart.setQuantity(product.uuid, 7);

    expect(cart.totalItems, 7);
    expect(cart.minimumTotal, 6293);

    cart.setQuantity(product.uuid, 0);

    expect(cart.totalItems, 0);
    expect(cart.minimumTotal, 0);
    expect(cart.items, isEmpty);
  });
}
