import 'package:flutter_test/flutter_test.dart';
import 'package:pk_deals/live.dart';

Map<String, dynamic> v(String size, bool avail, int price, int? was) => {
  'option1': size,
  'available': avail,
  'price': price * 100,
  'compare_at_price': was == null ? null : was * 100,
};

void main() {
  test('in stock and discounted: deepest discount, only sizes in stock', () {
    final l = parseLive({
      'options': ['Size'],
      'variants': [
        v('S', true, 3000, 5000),
        v('M', false, 2000, 5000),
        v('L', true, 2500, 5000),
      ],
      'images': ['//cdn.shopify.com/a.jpg', '//cdn.shopify.com/b.jpg?v=1'],
    });
    expect(l.inStock, true);
    expect(l.onSale, true);
    expect(l.price, 2500);
    expect(l.was, 5000);
    expect(l.sizes, ['S', 'L']);
    expect(l.images, [
      'https://cdn.shopify.com/a.jpg?width=1200',
      'https://cdn.shopify.com/b.jpg?v=1&width=1200',
    ]);
  });

  test('a full-price size listed before a discounted one does not crash', () {
    final l = parseLive({
      'options': [
        {'name': 'Size'},
      ],
      'variants': [v('S', true, 5000, null), v('M', true, 4000, 5000)],
    });
    expect(l.onSale, true);
    expect(l.price, 4000);
    expect(l.was, 5000);
  });

  test('everything sold out', () {
    final l = parseLive({
      'options': ['Size'],
      'variants': [v('S', false, 3000, 5000)],
    });
    expect(l.inStock, false);
  });

  test('in stock but back to full price', () {
    final l = parseLive({
      'options': ['Size'],
      'variants': [v('S', true, 5000, 5000)],
    });
    expect(l.inStock, true);
    expect(l.onSale, false);
    expect(l.price, 5000);
  });

  test('size comes from the size option, not colour', () {
    final l = parseLive({
      'options': ['Color', 'Size'],
      'variants': [
        {
          'option1': 'Red',
          'option2': 'M',
          'available': true,
          'price': 100000,
          'compare_at_price': 200000,
        },
      ],
    });
    expect(l.sizes, ['M']);
  });
}
