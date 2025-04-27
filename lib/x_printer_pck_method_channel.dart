import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'x_printer_pck_platform_interface.dart';

import 'dart:async';

/// An implementation of [XPrinterPckPlatform] that uses method channels.
class MethodChannelXPrinterPck extends XPrinterPckPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('x_printer_eq');

  // Stream controllers for handling events
  final StreamController<List<String>> _devicesStreamController =
      StreamController<List<String>>.broadcast();
  final StreamController<String> _connectionStateController =
      StreamController<String>.broadcast();

  MethodChannelXPrinterPck() {
    methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  // Handle method calls from the native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDevicesUpdated':
        final List<dynamic> devices = call.arguments;
        _devicesStreamController.add(devices.map((e) => e.toString()).toList());
        break;
      case 'onConnectionStateChanged':
        final String state = call.arguments;
        _connectionStateController.add(state);
        break;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'The method ${call.method} is not implemented',
        );
    }
  }

  @override
  Stream<List<String>> get devicesDiscoveredStream =>
      _devicesStreamController.stream;

  @override
  Stream<String> get connectionStateStream => _connectionStateController.stream;

  @override
  Future<void> startScan() async {
    await methodChannel.invokeMethod<void>('startScan');
  }

  @override
  Future<void> stopScan() async {
    await methodChannel.invokeMethod<void>('stopScan');
  }

  @override
  Future<void> connectToDevice(String uuid) async {
    await methodChannel.invokeMethod<void>('connectToDevice', {'uuid': uuid});
  }

  @override
  Future<void> disconnect() async {
    await methodChannel.invokeMethod<void>('disconnect');
  }

  @override
  Future<void> printText(String text) async {
    await methodChannel.invokeMethod<void>('printText', {'text': text});
  }

  @override
  Future<void> printBarcode(String barcode, String type) async {
    await methodChannel.invokeMethod<void>('printBarcode', {
      'barcode': barcode,
      'type': type,
    });
  }

  @override
  Future<void> printQRCode(String qrcode) async {
    await methodChannel.invokeMethod<void>('printQRCode', {'qrcode': qrcode});
  }

  @override
  Future<void> printImage(String base64Image) async {
    await methodChannel
        .invokeMethod<void>('printImage', {'image': base64Image});
  }
}
