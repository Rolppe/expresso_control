// ============================================================================
// wifi_key_store.dart — the Pico's Wi-Fi link key, address and port
// ============================================================================
// The key (32 bytes, 64 hex chars) comes over BLE once (`wifi:key?` ->
// {"type":"wifi_key",...}) or is pasted in Settings. It lives in the iOS
// Keychain (flutter_secure_storage). It is never logged or printed: nothing in
// this file formats it into a string other than the storage write.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/debug_log.dart';

const String wifiDefaultHost = '192.0.2.10';
const int wifiDefaultPort = 47211;

class WifiLinkConfig {
  /// 64 hex chars. Never log this.
  final String keyHex;
  final String host;
  final int port;

  const WifiLinkConfig({
    required this.keyHex,
    this.host = wifiDefaultHost,
    this.port = wifiDefaultPort,
  });

  /// The 32 key bytes, or null when [keyHex] is malformed.
  Uint8List? get keyBytes => decodeWifiKey(keyHex);

  @override
  String toString() => 'WifiLinkConfig(host: $host, port: $port, key: ***)';
}

/// 64 hex chars -> 32 bytes; null for anything else.
Uint8List? decodeWifiKey(String hex) {
  final h = hex.trim();
  if (h.length != 64) return null;
  final out = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    final v = int.tryParse(h.substring(i * 2, i * 2 + 2), radix: 16);
    if (v == null) return null;
    out[i] = v;
  }
  return out;
}

abstract class WifiKeyStore {
  Future<WifiLinkConfig?> load();

  Future<void> save(WifiLinkConfig config);

  Future<void> clear();

  /// Fires after every save / clear.
  Stream<void> get changes;
}

/// Keychain-backed store.
class SecureWifiKeyStore implements WifiKeyStore {
  static const _kKey = 'wifi_link_key';
  static const _kHost = 'wifi_link_host';
  static const _kPort = 'wifi_link_port';

  final FlutterSecureStorage _storage;
  final _changes = StreamController<void>.broadcast();

  SecureWifiKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<WifiLinkConfig?> load() async {
    try {
      final key = await _storage.read(key: _kKey);
      if (key == null || decodeWifiKey(key) == null) return null;
      final host = await _storage.read(key: _kHost);
      final port = int.tryParse(await _storage.read(key: _kPort) ?? '');
      return WifiLinkConfig(
        keyHex: key.trim().toLowerCase(),
        host: (host == null || host.isEmpty) ? wifiDefaultHost : host,
        port: port ?? wifiDefaultPort,
      );
    } catch (e) {
      DLog.sys('wifi key load failed: ${e.runtimeType}');
      return null;
    }
  }

  @override
  Future<void> save(WifiLinkConfig config) async {
    try {
      await _storage.write(key: _kKey, value: config.keyHex.trim().toLowerCase());
      await _storage.write(key: _kHost, value: config.host);
      await _storage.write(key: _kPort, value: config.port.toString());
      _changes.add(null);
    } catch (e) {
      DLog.sys('wifi key save failed: ${e.runtimeType}');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _kKey);
      await _storage.delete(key: _kHost);
      await _storage.delete(key: _kPort);
      _changes.add(null);
    } catch (e) {
      DLog.sys('wifi key clear failed: ${e.runtimeType}');
    }
  }
}

/// RAM-only store for tests and for builds where the Keychain is unavailable.
class MemoryWifiKeyStore implements WifiKeyStore {
  WifiLinkConfig? _config;
  final _changes = StreamController<void>.broadcast();

  MemoryWifiKeyStore([this._config]);

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<WifiLinkConfig?> load() async => _config;

  @override
  Future<void> save(WifiLinkConfig config) async {
    _config = config;
    _changes.add(null);
  }

  @override
  Future<void> clear() async {
    _config = null;
    _changes.add(null);
  }
}
