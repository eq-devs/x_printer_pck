import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'x_printer_pck_method_channel.dart';

/// The interface that implementations of x_printer_pck must implement.
///
/// Platform implementations should extend this class rather than implement it as `x_printer_pck`
/// does not consider newly added methods to be breaking changes. Extending this class
/// (using `extends`) ensures that the subclass will get the default implementation, while
/// platform implementations that `implements` this interface will be broken by newly added
/// [XPrinterPckPlatform] methods.
abstract class XPrinterPckPlatform extends PlatformInterface {
  /// Constructs a XPrinterPckPlatform.
  XPrinterPckPlatform() : super(token: _token);

  static final Object _token = Object();

  static XPrinterPckPlatform _instance = MethodChannelXPrinterPck();

  /// The default instance of [XPrinterPckPlatform] to use.
  ///
  /// Defaults to [MethodChannelXPrinterPck].
  static XPrinterPckPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [XPrinterPckPlatform] when
  /// they register themselves.
  static set instance(XPrinterPckPlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Starts scanning for Bluetooth devices
  Future<void> startScan() {
    throw UnimplementedError('startScan() has not been implemented.');
  }

  /// Stops scanning for Bluetooth devices
  Future<void> stopScan() {
    throw UnimplementedError('stopScan() has not been implemented.');
  }

  /// Connects to a Bluetooth device by UUID
  Future<void> connectToDevice(String uuid) {
    throw UnimplementedError('connectToDevice() has not been implemented.');
  }

  /// Disconnects from the currently connected device
  Future<void> disconnect() {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  /// Prints text
  Future<void> printText(String text) {
    throw UnimplementedError('printText() has not been implemented.');
  }

  /// Prints a barcode
  Future<void> printBarcode(String barcode, String type) {
    throw UnimplementedError('printBarcode() has not been implemented.');
  }

  /// Prints a QR code
  Future<void> printQRCode(String qrcode) {
    throw UnimplementedError('printQRCode() has not been implemented.');
  }

  /// Prints an image from base64 data
  Future<void> printImage(String base64Image) {
    throw UnimplementedError('printImage() has not been implemented.');
  }

  /// Stream for device discovery events
  Stream<List<String>> get devicesDiscoveredStream;

  /// Stream for connection state changes
  Stream<String> get connectionStateStream;
}
