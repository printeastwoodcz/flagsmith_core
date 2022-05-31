import 'dart:async';
import 'dart:convert';
import 'dart:developer' as d;

import 'package:rxdart/rxdart.dart';

import 'crud_storage.dart';
import 'model/flag.dart';
import 'tools/security.dart';

class StorageProvider with SecureStorage {
  Map<String, BehaviorSubject<Flag>?> _streams = {};
  late StorageSecurity _storageSecurity;
  final CoreStorage _storage;
  final bool logEnabled;
  void log(message) {
    if (logEnabled) {
      d.log(message);
    }
  }

  StorageProvider(this._storage, {String? password, this.logEnabled = false}) {
    assert(password != null);
    _storageSecurity = StorageSecurity(password);
    _storage.init();
    _initSubjects();
  }

  @override
  Future<String?> getSecuredValue(String key) async {
    final item = await _storage.read(key);
    if (item == null) {
      return null;
    }
    return _storageSecurity.decrypt(item);
  }

  @override
  Future<bool> setSecuredValue(String key, String value, {bool update = false}) async {
    final encrypted = _storageSecurity.encrypt(value);
    if (update) {
      return await _storage.update(key, encrypted);
    }
    return await _storage.create(key, encrypted);
  }

  Future<bool> create(String key, Flag item) async {
    final response = await setSecuredValue(key, item.asString());
    _createSubject(await read(key));
    return response;
  }

  Future<bool> delete(String key) {
    _destroySubject(key);
    _streams.remove(key);
    return _storage.delete(key);
  }

  Future<Flag?> read(String key) async {
    final decrypted = await getSecuredValue(key);
    if (decrypted == null) {
      return null;
    }
    return Flag.fromJson(jsonDecode(decrypted) as Map<String, dynamic>);
  }

  Future<bool> update(String key, Flag item) async {
    final result = await setSecuredValue(key, item.asString(), update: true);
    read(key).then((value) {
      _updateSubject(value);
    });
    return result;
  }

  Future<bool> clear() async {
    _clearSubjects();
    await _storage.clear();
    return true;
  }

  Future<List<Flag>> getAll() async {
    final list = await _storage.getAll();
    final filtered = list.whereType<String>();
    final result = <Flag>[];
    for (final item in filtered) {
      var decrypted = _storageSecurity.decrypt(item);
      if (decrypted != null) {
        result.add(Flag.fromJson(jsonDecode(decrypted) as Map<String, dynamic>));
      }
    }
    return result;
  }

  Future<bool> saveAll(List<Flag> items) async {
    for (var item in items) {
      final _current = await read(item.key);
      if (_current != null) {
        await update(item.key, item);
      } else {
        await create(item.key, item);
      }
    }
    return true;
  }

  Future<bool> seed({required List<Flag> items}) async {
    List<MapEntry<String, String>> list = [];
    for (final item in items) {
      list.add(MapEntry(item.key, _storageSecurity.encrypt(item.asString())));
    }
    var result = await _storage.seed(list);
    if (result) {
      for (var item in items) {
        _createSubject(item);
      }
    }
    return result;
  }

  Stream<Flag>? stream(String featureName) => _streams[featureName]?.stream;

  BehaviorSubject<Flag>? subject(String featureName) => _streams[featureName];

  Future<void> _initSubjects() async {
    final result = await getAll();
    for (var flag in result) {
      _createSubject(flag);
    }
  }

  void _createSubject(Flag? item) {
    if (item == null) {
      return;
    }

    if (_streams[item.key] == null) {
      _streams[item.key] = BehaviorSubject<Flag>.seeded(item);
      log('_createSubject ${item.key} -> ${_streams[item.key]?.value}');
    }
  }

  void _updateSubject(Flag? item) {
    if (item == null) {
      return;
    }
    _streams[item.key]?.add(item);
    log('_updateSubject ${item.key} -> ${_streams[item.key]?.value.enabled} f: ${item.enabled}');
  }

  void _destroySubject(String featureName) {
    try {
      _streams[featureName]?.close();
      _streams[featureName] = null;
    } catch (e) {
      log(e.toString());
    }
  }

  void _clearSubjects() {
    for (var item in _streams.entries) {
      _destroySubject(item.key);
    }
    _streams = {};
  }

  Future<bool> togggleFeature(String featureName) async {
    final value = await read(featureName);
    if (value == null) {
      return false;
    }
    var current = value.enabled ?? false;
    var updated = value.copyWith(enabled: !current);
    return await update(featureName, updated);
  }
}
