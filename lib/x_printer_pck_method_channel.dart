import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'x_printer_pck_platform_interface.dart';

import 'dart:async';

// Enum for image alignment options
enum PrintAlignment {
  center, // Center the image on the paper
  topLeft, // Position at top-left corner
  custom, // Use custom X/Y coordinates
}

/// An implementation of [XPrinterPckPlatform] that uses method channels.
class MethodChannelXPrinterPck extends XPrinterPckPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('x_printer_eq');

  // Event handlers
  Function(List<Map<String, dynamic>>)? _scanResultsHandler;
  Function(Map<String, dynamic>)? _connectionChangedHandler;

  @override
  Future<void> initialize() async {
    methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  /// Initializes the printer plugin
  @override
  Future<bool> init() async {
    try {
      final bool isInitialized = await methodChannel.invokeMethod('initialize');
      return isInitialized;
    } catch (e) {
      return false;
    }
  }

  // Handle incoming method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onScanResults':
        final devices = (call.arguments as List)
            .cast<Map<dynamic, dynamic>>()
            .map((device) => _convertToStringDynamicMap(device))
            .toList();
        _scanResultsHandler?.call(devices);
        break;

      case 'onConnectionChanged':
        final status = _convertToStringDynamicMap(call.arguments);
        _connectionChangedHandler?.call(status);
        break;

      default:
    }
  }

  // Helper method to convert Map<dynamic, dynamic> to Map<String, dynamic>
  Map<String, dynamic> _convertToStringDynamicMap(Map<dynamic, dynamic> map) {
    return map.map((key, value) => MapEntry(key.toString(), value));
  }

  @override
  Future<bool> scanDevices() async {
    return await methodChannel.invokeMethod('scanDevices');
  }

  @override
  Future<bool> stopScan() async {
    return await methodChannel.invokeMethod('stopScan');
  }

  @override
  Future<bool> connectDevice(int index) async {
    return await methodChannel.invokeMethod('connectDevice', {'index': index});
  }

  @override
  Future<bool> disconnectDevice() async {
    return await methodChannel.invokeMethod('disconnectDevice');
  }

  @override
  Future<bool> printText(String text, {int fontSize = 1}) async {
    return await methodChannel.invokeMethod('printText', {
      'text': text,
      'fontSize': fontSize,
    });
  }

  @override
  Future<bool> printBarcode(
    String content, {
    int x = 100,
    int y = 50,
    int height = 80,
    String type = '128',
  }) async {
    return await methodChannel.invokeMethod('printBarcode', {
      'content': content,
      'x': x,
      'y': y,
      'height': height,
      'type': type,
    });
  }

  @override
  Future<bool> printQRCode(
    String content, {
    int x = 280,
    int y = 10,
    int cellWidth = 8,
  }) async {
    return await methodChannel.invokeMethod('printQRCode', {
      'content': content,
      'x': x,
      'y': y,
      'cellWidth': cellWidth,
    });
  }

  @override
  Future<bool> printImage(
    Uint8List imageData, {
    int commandType = 0,
    int? printerWidth,
    int? printerHeight,
    int rotation = 0,
    double scale = 0.9,
  }) async {
    return await methodChannel.invokeMethod('printImage', {
      'imageData': imageData,
      'commandType': commandType,
      if (printerWidth != null) 'printerWidth': printerWidth,
      if (printerHeight != null) 'printerHeight': printerHeight,
      'rotation': rotation,
      'scale': scale,
    });
  }

  /// Prints a PDF file through the thermal printer
  ///
  /// [pdfPath] - Path to the PDF file on the device filesystem
  /// [commandType] - Printer command language (0: TSPL, 1: ZPL, 2: CPCL)
  /// [printerWidth] - Width of the printer in dots (default: 384)
  /// [printerHeight] - Height of the printer in dots (default: 600)
  /// [rotation] - Rotation angle in degrees (default: 0)
  /// [scale] - Scale factor for the image (default: 0.9)
  /// [startPage] - First page to print (default: 1)
  /// [endPage] - Last page to print (0 means print all pages, default: 0)
  /// [password] - Password for protected PDFs (optional)
  @override
  Future<bool> printPDF(
    String pdfPath, {
    int commandType = 0,
    int? printerWidth,
    int? printerHeight,
    int rotation = 0,
    double scale = 0.9,
    int? startPage,
    int? endPage,
    String? password,
  }) async {
    try {
      return await methodChannel.invokeMethod('printPDF', {
        'pdfPath': pdfPath,
        'commandType': commandType,
        if (printerWidth != null) 'printerWidth': printerWidth,
        if (printerHeight != null) 'printerHeight': printerHeight,
        'rotation': rotation,
        'scale': scale,
        if (startPage != null) 'startPage': startPage,
        if (endPage != null) 'endPage': endPage,
        if (password != null) 'password': password,
      });
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getPrinterStatus() async {
    final result = await methodChannel.invokeMethod('getPrinterStatus');
    return {
      'code': result['code'],
      'message': result['message'],
    };
  }

  @override
  void registerScanResultsHandler(
      Function(List<Map<String, dynamic>>) handler) {
    _scanResultsHandler = handler;
  }

  @override
  void registerConnectionChangedHandler(
      Function(Map<String, dynamic>) handler) {
    _connectionChangedHandler = handler;
  }
}
