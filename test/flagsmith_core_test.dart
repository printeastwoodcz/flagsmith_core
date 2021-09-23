import 'package:flagsmith_core/flagsmith_core.dart';
import 'package:collection/collection.dart';
import 'package:test/test.dart';

import 'shared.dart';

void main() {
  final InMemoryStore storage = InMemoryStore();
  late StorageProvider store;

  setUpAll(() {
    store = StorageProvider(storage, password: 'pa5w0rD', logEnabled: true);
  });

  test('adds one to input values', () async {
    final response = await store.seed(items: seeds);
    expect(response, true);
    final all = await store.getAll();
    expect(all.length, seeds.length);
  });
  test('When update value', () async {
    final response = await store.read(myFeature);
    expect(response, isNotNull);
    expect(response!.enabled, true);
  });
  test('Update with enabled false', () async {
    await store.update(myFeature, Flag.seed(myFeature, enabled: false));
    final responseUpdated = await store.read(myFeature);
    expect(responseUpdated, isNotNull);
    expect(responseUpdated!.enabled, false);
  });
  test('Remove item from storage', () async {
    await store.delete(myFeature);
    final items = await store.getAll();
    expect(items, isNotEmpty);
    expect(items.length, seeds.length - 1);
  });
  test('Remove item from storage', () async {
    await store.clear();
    final items = await store.getAll();
    expect(items, isEmpty);
  });
  test('Create a flag', () async {
    final _created = await store.create(
        'test_feature', Flag.seed('test_feature', enabled: false));
    expect(_created, isTrue);
  });
  test('Save all flags', () async {
    final _created = await store.saveAll([
      Flag.seed('test_feature_a', enabled: false),
      Flag.seed('test_feature_b', enabled: true)
    ]);
    expect(_created, isTrue);
    final _all = await store.getAll();
    expect(_all, isNotEmpty);
    expect(
        _all,
        const TypeMatcher<List<Flag>>().having(
            (p0) => p0
                .firstWhereOrNull((element) => element.key == 'test_feature_a'),
            'saved flags containse feature flag `test_feature_a`',
            isNotNull));
  });

  test('Update all flags', () async {
    final _created = await store.saveAll([
      Flag.seed('test_feature_a', enabled: false),
      Flag.seed('test_feature_b', enabled: true)
    ]);
    expect(_created, isTrue);
    final _all = await store.getAll();
    expect(_all, isNotEmpty);
    expect(
        _all,
        const TypeMatcher<List<Flag>>().having(
            (p0) => p0
                .firstWhereOrNull((element) => element.key == 'test_feature_a'),
            'saved flags containse feature flag `test_feature_a`',
            isNotNull));
  });

  test('Init storage over', () async {
    store = StorageProvider(storage, password: 'pa5w0rD', logEnabled: true);
    expect(await store.seed(items: seeds), isTrue);
  });
}
