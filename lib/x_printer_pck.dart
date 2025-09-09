import 'x_printer_pck_platform_interface.dart';
import 'x_printer_pck_method_channel.dart';

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

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

  static Future<bool> init() async {
    try {
      final bool isInitialized = await XPrinterPckPlatform.instance.init();
      return isInitialized;
    } catch (e) {
      return false;
    }
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

  /// Print image from Uint8List
  static Future<bool> printImage(
    Uint8List imageData, {
    PrinterCommandType commandType = PrinterCommandType.tspl,
    int printerWidth = 350, // Updated default
    int printerHeight = 350, // Updated default
    int rotation = 0,
    double scale = 0.91,
  }) async {
    return await XPrinterPckPlatform.instance.printImage(
      imageData,
      commandType: commandType.value,
      printerWidth: printerWidth,
      printerHeight: printerHeight,
      rotation: rotation,
      scale: scale,
    );
  }

  /// Print image from base64 string (optimized - all processing on iOS side)
  ///
  /// [base64String] - Base64 encoded image data (with or without data URL prefix)
  /// [commandType] - Printer command language to use
  /// [printerWidth] - Width of the printer canvas in pixels (default: 350)
  /// [printerHeight] - Height of the printer canvas in pixels (default: 350)
  /// [rotation] - Rotation angle in degrees (0, 90, 180, 270)
  /// [scale] - Scale factor for the image (default: 0.91)
  /// [quality] - Image processing quality (0.1 to 1.0, where 1.0 is highest)
  /// [alignment] - Image alignment on the paper
  /// [x] - Custom X position (only used when alignment is custom)
  /// [y] - Custom Y position (only used when alignment is custom)
  static Future<bool> printImageBase64(
    String base64String, {
    PrinterCommandType commandType = PrinterCommandType.tspl,
    int printerWidth = 350, // Updated default for optimal output size
    int printerHeight = 350, // Updated default for optimal output size
    int rotation = 0,
    double scale = 0.91,
    double quality = 1.0,
    PrintAlignment alignment = PrintAlignment.center,
    int? x,
    int? y,
  }) async {
    // Validate parameters
    if (base64String.isEmpty) {
      throw ArgumentError('Base64 string cannot be empty');
    }

    if (scale < 0.1 || scale > 1.0) {
      throw ArgumentError('Scale must be between 0.1 and 1.0');
    }

    if (quality < 0.1 || quality > 1.0) {
      throw ArgumentError('Quality must be between 0.1 and 1.0');
    }

    if (alignment == PrintAlignment.custom && (x == null || y == null)) {
      throw ArgumentError(
          'X and Y coordinates must be provided when using custom alignment');
    }

    return await XPrinterPckPlatform.instance.printImageBase64(
      base64String,
      commandType: commandType.value,
      printerWidth: printerWidth,
      printerHeight: printerHeight,
      rotation: rotation,
      scale: scale,
      quality: quality,
      alignment: alignment.value,
      x: x,
      y: y,
    );
  }

  /// Prints an image from a base64 encoded string (legacy method for backward compatibility).
  ///
  /// - [base64Encoded] Base64 encoded image data.
  /// - [width] Width parameter (deprecated, use scale instead).
  @Deprecated(
      'Use printImageBase64 instead for better performance and more options')
  static Future<bool> printImageBase64Legacy(
    String base64Encoded, {
    double width = 460,
    PrinterCommandType commandType = PrinterCommandType.tspl,
    int printerWidth = 350, // Updated default
    int printerHeight = 350, // Updated default
    int rotation = 0,
    double scale = 0.91,
  }) async {
    try {
      // Decode base64 string to bytes
      final Uint8List imageData = base64Decode(base64Encoded);

      // Use the existing printImage function
      return await printImage(
        imageData,
        commandType: commandType,
        printerWidth: printerWidth,
        printerHeight: printerHeight,
        rotation: rotation,
        scale: scale,
      );
    } catch (e) {
      print('Error decoding base64 image: $e');
      return false;
    }
  }

  /// Print PDF document
  static Future<bool> printPDF(
    String pdfPath, {
    PrinterCommandType commandType = PrinterCommandType.tspl,
    int printerWidth = 350, // Updated default
    int printerHeight = 350, // Updated default
    int rotation = 0,
    double scale = 0.91,
    int? startPage,
    int? endPage,
    String? password,
  }) async {
    return await XPrinterPckPlatform.instance.printPDF(
      pdfPath,
      commandType: commandType.value,
      printerWidth: printerWidth,
      printerHeight: printerHeight,
      rotation: rotation,
      scale: scale,
      startPage: startPage,
      endPage: endPage,
      password: password,
    );
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

// Model classes remain the same...

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

  @override
  String toString() {
    return 'BluetoothDevice(name: $name, address: $address, rssi: $rssi)';
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
  bool get isDisconnected => status == 'disconnected';
  bool get isFailed => status == 'failed';

  @override
  String toString() {
    return 'ConnectionStatus(name: $name, address: $address, status: $status, error: $error)';
  }
}

class PrinterStatus {
  final int code;
  final String message;

  PrinterStatus({
    required this.code,
    required this.message,
  });

  bool get isReady => code == 0x00;
  bool get isCoverOpen => (code & 0x01) != 0;
  bool get isPaperJam => (code & 0x02) != 0;
  bool get isPaperEnd => (code & 0x04) != 0;
  bool get isNoRibbon => (code & 0x08) != 0;
  bool get isPaused => (code & 0x10) != 0;
  bool get isPrinting => (code & 0x20) != 0;

  @override
  String toString() {
    return 'PrinterStatus(code: 0x${code.toRadixString(16).toUpperCase()}, message: $message)';
  }
}
