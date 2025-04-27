import 'x_printer_pck_platform_interface.dart';

import 'dart:async';

/// The main class for the X Printer plugin
class XPrinterPck {
  /// Starts scanning for Bluetooth devices
  ///
  /// Returns a Future that completes when the scan has been started
  Future<void> startScan() {
    return XPrinterPckPlatform.instance.startScan();
  }

  /// Stops scanning for Bluetooth devices
  ///
  /// Returns a Future that completes when the scan has been stopped
  Future<void> stopScan() {
    return XPrinterPckPlatform.instance.stopScan();
  }

  /// Connects to a Bluetooth device
  ///
  /// [uuid] The UUID of the device to connect to
  /// Returns a Future that completes when the connection attempt has been initiated
  Future<void> connectToDevice(String uuid) {
    return XPrinterPckPlatform.instance.connectToDevice(uuid);
  }

  /// Disconnects from the currently connected device
  ///
  /// Returns a Future that completes when the disconnection has been initiated
  Future<void> disconnect() {
    return XPrinterPckPlatform.instance.disconnect();
  }

  /// Prints text to the connected printer
  ///
  /// [text] The text to print
  /// Returns a Future that completes when the print command has been sent
  Future<void> printText(String text) {
    return XPrinterPckPlatform.instance.printText(text);
  }

  /// Prints a barcode to the connected printer
  ///
  /// [barcode] The barcode content to print
  /// [type] The type of barcode to print (e.g., 'UPC-A', 'CODE128')
  /// Returns a Future that completes when the print command has been sent
  Future<void> printBarcode(String barcode, String type) {
    return XPrinterPckPlatform.instance.printBarcode(barcode, type);
  }

  /// Prints a QR code to the connected printer
  ///
  /// [qrcode] The QR code content to print
  /// Returns a Future that completes when the print command has been sent
  Future<void> printQRCode(String qrcode) {
    return XPrinterPckPlatform.instance.printQRCode(qrcode);
  }

  /// Prints an image to the connected printer
  ///
  /// [base64Image] The base64-encoded image data to print
  /// Returns a Future that completes when the print command has been sent
  Future<void> printImage(String base64Image) {
    return XPrinterPckPlatform.instance.printImage(base64Image);
  }

  /// Stream for discovering Bluetooth devices
  ///
  /// Emits a list of device UUIDs whenever new devices are discovered
  Stream<List<String>> get devicesDiscoveredStream {
    return XPrinterPckPlatform.instance.devicesDiscoveredStream;
  }

  /// Stream for connection state changes
  ///
  /// Emits 'connected' or 'disconnected' when the connection state changes
  Stream<String> get connectionStateStream {
    return XPrinterPckPlatform.instance.connectionStateStream;
  }
}
