import 'x_printer_pck_platform_interface.dart';

import 'dart:async';
import 'dart:typed_data';

class XPrinterPck {
  // Event handlers
  static Function(List<BluetoothDevice>)? onScanResults;
  static Function(ConnectionStatus)? onConnectionChanged;

  /// Initialize the plugin and set up method call handlers
  static Future<void> initialize() async {
    await XPrinterPckPlatform.instance.initialize();

    // Set up event handlers
    XPrinterPckPlatform.instance.registerScanResultsHandler(_handleScanResults);
    XPrinterPckPlatform.instance
        .registerConnectionChangedHandler(_handleConnectionChanged);
  }

  // Handler for scan results
  static void _handleScanResults(List<Map<String, dynamic>> devicesMap) {
    final devices =
        devicesMap.map((device) => BluetoothDevice.fromMap(device)).toList();
    onScanResults?.call(devices);
  }

  // Handler for connection status changes
  static void _handleConnectionChanged(Map<String, dynamic> statusMap) {
    final status = ConnectionStatus.fromMap(statusMap);
    onConnectionChanged?.call(status);
  }

  /// Start scanning for Bluetooth devices
  static Future<bool> scanDevices() async {
    return await XPrinterPckPlatform.instance.scanDevices();
  }

  /// Stop scanning for Bluetooth devices
  static Future<bool> stopScan() async {
    return await XPrinterPckPlatform.instance.stopScan();
  }

  /// Connect to a device by index in the scan results
  static Future<bool> connectDevice(int index) async {
    return await XPrinterPckPlatform.instance.connectDevice(index);
  }

  /// Disconnect from the current device
  static Future<bool> disconnectDevice() async {
    return await XPrinterPckPlatform.instance.disconnectDevice();
  }

  /// Print text
  static Future<bool> printText(String text, {int fontSize = 1}) async {
    return await XPrinterPckPlatform.instance
        .printText(text, fontSize: fontSize);
  }

  /// Print barcode
  static Future<bool> printBarcode(
    String content, {
    int x = 100,
    int y = 50,
    int height = 80,
    String type = '128',
  }) async {
    return await XPrinterPckPlatform.instance.printBarcode(
      content,
      x: x,
      y: y,
      height: height,
      type: type,
    );
  }

  /// Print QR code
  static Future<bool> printQRCode(
    String content, {
    int x = 280,
    int y = 10,
    int cellWidth = 8,
  }) async {
    return await XPrinterPckPlatform.instance.printQRCode(
      content,
      x: x,
      y: y,
      cellWidth: cellWidth,
    );
  }

  /// Print image
  static Future<bool> printImage(Uint8List imageData) async {
    return await XPrinterPckPlatform.instance.printImage(imageData);
  }

  /// Get printer status
  static Future<PrinterStatus> getPrinterStatus() async {
    final result = await XPrinterPckPlatform.instance.getPrinterStatus();
    return PrinterStatus(
      code: result['code'],
      message: result['message'],
    );
  }
}

// Model classes

class BluetoothDevice {
  final String name;
  final String address;
  final int rssi;

  BluetoothDevice({
    required this.name,
    required this.address,
    required this.rssi,
  });

  factory BluetoothDevice.fromMap(Map<String, dynamic> map) {
    return BluetoothDevice(
      name: map['name'] as String,
      address: map['address'] as String,
      rssi: map['rssi'] as int,
    );
  }
}

class ConnectionStatus {
  final String name;
  final String address;
  final String status;
  final String error;

  ConnectionStatus({
    required this.name,
    required this.address,
    required this.status,
    this.error = '',
  });

  factory ConnectionStatus.fromMap(Map<String, dynamic> map) {
    return ConnectionStatus(
      name: map['name'] as String,
      address: map['address'] as String,
      status: map['status'] as String,
      error: map['error'] as String? ?? '',
    );
  }

  bool get isConnected => status == 'connected';
}

class PrinterStatus {
  final int code;
  final String message;

  PrinterStatus({
    required this.code,
    required this.message,
  });

  bool get isReady => code == 0x00;
}
