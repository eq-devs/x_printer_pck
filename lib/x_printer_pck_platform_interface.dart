import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'dart:typed_data';

import 'x_printer_pck_method_channel.dart';

/// The interface that implementations of x_printer_pck must implement.
abstract class XPrinterPckPlatform extends PlatformInterface {
  /// Constructs a XPrinterPckPlatform.
  XPrinterPckPlatform() : super(token: _token);

  static final Object _token = Object();

  /// The default instance of [XPrinterPckPlatform] to use.
  static XPrinterPckPlatform _instance = MethodChannelXPrinterPck();

  /// The default instance of [XPrinterPckPlatform] to use.
  /// Defaults to [MethodChannelXPrinterPck].
  static XPrinterPckPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [XPrinterPckPlatform] when
  /// they register themselves.
  static set instance(XPrinterPckPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initialize the printer plugin.
  Future<void> initialize() {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Start scanning for Bluetooth devices.
  Future<bool> scanDevices() {
    throw UnimplementedError('scanDevices() has not been implemented.');
  }

  /// Stop scanning for Bluetooth devices.
  Future<bool> stopScan() {
    throw UnimplementedError('stopScan() has not been implemented.');
  }

  /// Connect to a device by index in the scan results.
  Future<bool> connectDevice(int index) {
    throw UnimplementedError('connectDevice() has not been implemented.');
  }

  /// Disconnect from the current device.
  Future<bool> disconnectDevice() {
    throw UnimplementedError('disconnectDevice() has not been implemented.');
  }

  /// Print text.
  Future<bool> printText(String text, {int fontSize = 1}) {
    throw UnimplementedError('printText() has not been implemented.');
  }

  /// Print barcode.
  Future<bool> printBarcode(
    String content, {
    int x = 100,
    int y = 50,
    int height = 80,
    String type = '128',
  }) {
    throw UnimplementedError('printBarcode() has not been implemented.');
  }

  /// Print QR code.
  Future<bool> printQRCode(
    String content, {
    int x = 280,
    int y = 10,
    int cellWidth = 8,
  }) {
    throw UnimplementedError('printQRCode() has not been implemented.');
  }

  /// Print image.
  Future<bool> printImage(
    Uint8List imageData, {
    int commandType = 0,
    int? printerWidth,
    int? printerHeight,
    int rotation = 0,
    double scale = 0.9,
  }) {
    throw UnimplementedError('printImage() has not been implemented.');
  }

  /// Get printer status.
  Future<Map<String, dynamic>> getPrinterStatus() {
    throw UnimplementedError('getPrinterStatus() has not been implemented.');
  }

  /// Register scan results handler.
  void registerScanResultsHandler(
      Function(List<Map<String, dynamic>>) handler) {
    throw UnimplementedError(
        'registerScanResultsHandler() has not been implemented.');
  }

  /// Register connection status change handler.
  void registerConnectionChangedHandler(
      Function(Map<String, dynamic>) handler) {
    throw UnimplementedError(
        'registerConnectionChangedHandler() has not been implemented.');
  }
}
