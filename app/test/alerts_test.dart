import 'package:flutter_test/flutter_test.dart';
import 'package:pk_deals/alerts.dart';

Map<String, dynamic> brand(String id, int onSale, int maxOff) => {
  'id': id,
  'name': id.toUpperCase(),
  'on_sale': onSale,
  'max_off': maxOff,
};

void main() {
  group('saleChanges', () {
    test('a followed brand starting a sale alerts', () {
      final before = snapshotOf([brand('zellbury', 0, 0)]);
      final now = [brand('zellbury', 420, 50)];
      final a = saleChanges(before, now, {'zellbury'});
      expect(a, hasLength(1));
      expect(a.single.title, 'ZELLBURY sale is live!');
      expect(a.single.body, contains('420 items on sale, up to 50% off'));
      expect(a.single.brandId, 'zellbury');
    });

    test('brands you do not follow never alert', () {
      final before = snapshotOf([brand('zellbury', 0, 0)]);
      expect(saleChanges(before, [brand('zellbury', 420, 50)], {}), isEmpty);
    });

    test('discount rising by 10 points or more alerts', () {
      final before = snapshotOf([brand('gulahmed', 4000, 50)]);
      final a = saleChanges(
        before,
        [brand('gulahmed', 4100, 70)],
        {'gulahmed'},
      );
      expect(a.single.title, 'GULAHMED: bigger discounts');
      expect(a.single.body, contains('Now up to 70% off (was 50%)'));
    });

    test('small discount change does not alert', () {
      final before = snapshotOf([brand('gulahmed', 4000, 50)]);
      expect(
        saleChanges(before, [brand('gulahmed', 4050, 55)], {'gulahmed'}),
        isEmpty,
      );
    });

    test('sale doubling in size alerts', () {
      final before = snapshotOf([brand('saya', 300, 40)]);
      final a = saleChanges(before, [brand('saya', 900, 45)], {'saya'});
      expect(a.single.title, 'SAYA added more to the sale');
    });

    test('a brand seen for the first time does not alert', () {
      expect(saleChanges({}, [brand('lama', 500, 40)], {'lama'}), isEmpty);
    });

    test('a sale ending does not alert', () {
      final before = snapshotOf([brand('engine', 4686, 70)]);
      expect(saleChanges(before, [brand('engine', 0, 0)], {'engine'}), isEmpty);
    });

    test('several followed brands alert separately', () {
      final before = snapshotOf([
        brand('a', 0, 0),
        brand('b', 0, 0),
        brand('c', 0, 0),
      ]);
      final now = [brand('a', 10, 20), brand('b', 0, 0), brand('c', 5, 30)];
      expect(saleChanges(before, now, {'a', 'b', 'c'}).map((x) => x.brandId), [
        'a',
        'c',
      ]);
    });
  });
}
