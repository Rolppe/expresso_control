// ============================================================================
// pico_usb_channel.dart — MethodChannel to Android USB host + bridge
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class PicoUsbDevice {
  final int deviceId;
  final int vendorId;
  final int productId;
  final String name;
  final String productName;
  final bool hasPermission;

  PicoUsbDevice({
    required this.deviceId,
    required this.vendorId,
    required this.productId,
    required this.name,
    required this.productName,
    required this.hasPermission,
  });

  factory PicoUsbDevice.fromMap(Map<dynamic, dynamic> m) => PicoUsbDevice(
        deviceId: m['deviceId'] as int,
        vendorId: m['vendorId'] as int,
        productId: m['productId'] as int,
        name: m['name']?.toString() ?? '',
        productName: m['productName']?.toString() ?? '',
        hasPermission: m['hasPermission'] as bool? ?? false,
      );

  @override
  String toString() =>
      'PicoUsbDevice($deviceId vid=$vendorId pid=$productId perm=$hasPermission $productName)';
}

class PicoUsbChannel {
  static const _method = MethodChannel('espressopico/usb_serial');
  static const _events = EventChannel('espressopico/usb_serial_events');

  static Stream<Map<String, dynamic>>? _eventStream;

  static bool get isAndroid => Platform.isAndroid;

  static Stream<Map<String, dynamic>> get events {
    _eventStream ??= _events
        .receiveBroadcastStream()
        .map((e) => Map<String, dynamic>.from(e as Map));
    return _eventStream!;
  }

  static Future<List<PicoUsbDevice>> listDevices() async {
    if (!isAndroid) return [];
    final raw = await _method.invokeMethod<List<dynamic>>('listDevices');
    return (raw ?? [])
        .map((e) => PicoUsbDevice.fromMap(e as Map))
        .toList();
  }

  static Future<bool> requestPermission(int deviceId) async {
    if (!isAndroid) return false;
    return await _method.invokeMethod<bool>(
          'requestPermission',
          {'deviceId': deviceId},
        ) ??
        false;
  }

  static Future<bool> open(int deviceId, {int baud = 115200}) async {
    if (!isAndroid) return false;
    return await _method.invokeMethod<bool>(
          'open',
          {'deviceId': deviceId, 'baud': baud},
        ) ??
        false;
  }

  /// Request permission if needed and open first serial device.
  static Future<bool> openFirst({int baud = 115200}) async {
    if (!isAndroid) return false;
    return await _method.invokeMethod<bool>('openFirst', {'baud': baud}) ??
        false;
  }

  static Future<void> close() async {
    if (!isAndroid) return;
    await _method.invokeMethod<void>('close');
  }

  static Future<bool> isOpen() async {
    if (!isAndroid) return false;
    return await _method.invokeMethod<bool>('isOpen') ?? false;
  }

  static Future<bool> writeText(String text) async {
    if (!isAndroid) return false;
    return await _method.invokeMethod<bool>('write', {'text': text}) ?? false;
  }

  static Future<bool> writeBytes(List<int> bytes) async {
    if (!isAndroid) return false;
    final b64 = base64Encode(bytes);
    return await _method.invokeMethod<bool>('write', {'b64': b64}) ?? false;
  }

  static Future<bool> startBridge({int port = 2217, String token = ''}) async {
    if (!isAndroid) return false;
    return await _method.invokeMethod<bool>(
          'startBridge',
          {'port': port, 'token': token},
        ) ??
        false;
  }

  static Future<void> stopBridge() async {
    if (!isAndroid) return;
    await _method.invokeMethod<void>('stopBridge');
  }

  static Future<Map<String, dynamic>> bridgeStatus() async {
    if (!isAndroid) return {'running': false};
    final m = await _method.invokeMethod<Map<dynamic, dynamic>>('bridgeStatus');
    return Map<String, dynamic>.from(m ?? {});
  }

  /// Phone battery (OTG host usually cannot charge while Pico is attached).
  static Future<Map<String, dynamic>> batteryStatus() async {
    if (!isAndroid) {
      return {'level': 100, 'charging': true, 'minFlashPct': 20, 'warnPct': 30};
    }
    final m =
        await _method.invokeMethod<Map<dynamic, dynamic>>('batteryStatus');
    return Map<String, dynamic>.from(m ?? {});
  }

  /// Backup folder names under app files/firmware_backup (sorted, newest last).
  static Future<List<String>> listBackups() async {
    if (!isAndroid) return [];
    final raw = await _method.invokeMethod<List<dynamic>>('listBackups');
    return (raw ?? []).map((e) => e.toString()).toList();
  }

  /// Full restore of every file in files/firmware_backup/[name] (SHA-256 checked vs MANIFEST.json).
  static Future<Map<String, dynamic>> restoreBackup(
    String name, {
    bool force = false,
  }) async {
    if (!isAndroid) return {'ok': false, 'message': 'not Android'};
    final m = await _method.invokeMethod<Map<dynamic, dynamic>>(
      'restoreBackup',
      {'name': name, 'force': force},
    );
    return Map<String, dynamic>.from(m ?? {});
  }

  /// Flash firmware/*.py previously pushed to app files dir via adb.
  /// [force] bypasses low-battery block (not recommended on OTG-only power).
  static Future<Map<String, dynamic>> flashFromAppFiles({
    bool force = false,
  }) async {
    if (!isAndroid) return {'ok': false, 'message': 'not Android'};
    final m = await _method.invokeMethod<Map<dynamic, dynamic>>(
      'flashFromAppFiles',
      {'force': force},
    );
    return Map<String, dynamic>.from(m ?? {});
  }
}
