import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'x_printer_pck_platform_interface.dart';

import 'dart:async';

// Enum for image alignment options
enum PrintAlignment {
  center, // Center the image on the paper
  topLeft, // Position at top-left corner
  topRight, // Position at top-right corner
  bottomLeft, // Position at bottom-left corner
  bottomRight, // Position at bottom-right corner
  custom, // Use custom X/Y coordinates
}

// Enum for printer command types
enum PrinterCommandType {
  tspl, // TSC Printer Language
  zpl, // Zebra Programming Language
  cpcl, // Comtec Printer Control Language
}

// Extension to convert enum to int
extension PrinterCommandTypeExtension on PrinterCommandType {
  int get value {
    switch (this) {
      case PrinterCommandType.tspl:
        return 0;
      case PrinterCommandType.zpl:
        return 1;
      case PrinterCommandType.cpcl:
        return 2;
    }
  }
}

// Extension to convert enum to string
extension PrintAlignmentExtension on PrintAlignment {
  String get value {
    switch (this) {
      case PrintAlignment.center:
        return 'center';
      case PrintAlignment.topLeft:
        return 'topLeft';
      case PrintAlignment.topRight:
        return 'topRight';
      case PrintAlignment.bottomLeft:
        return 'bottomLeft';
      case PrintAlignment.bottomRight:
        return 'bottomRight';
      case PrintAlignment.custom:
        return 'custom';
    }
  }
}

/// An implementation of [XPrinterPckPlatform] that uses method channels.
class MethodChannelXPrinterPck extends XPrinterPckPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('x_printer_eq');

  // Event handlers
  Function(List<Map<String, dynamic>>)? _scanResultsHandler;
  Function(Map<String, dynamic>)? _connectionChangedHandler;

  // Add initialization tracking
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    print('🔄 Flutter: Starting initialization...');

    try {
      // Set up method call handler first
      methodChannel.setMethodCallHandler(_handleMethodCall);
      print('✅ Flutter: Method call handler set up');

      // Call native initialization with explicit timeout
      print('📱 Flutter: Calling native initialize method...');

      final result = await methodChannel.invokeMethod('initialize').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏰ Flutter: Initialize method call timed out');
          throw TimeoutException(
              'Initialize method call timed out', const Duration(seconds: 10));
        },
      );

      print('📱 Flutter: Native initialize returned: $result');

      if (result == true) {
        _isInitialized = true;
        print('✅ Flutter: XPrinterPck initialized successfully');
      } else {
        _isInitialized = false;
        print('❌ Flutter: Native initialize returned false');
        throw Exception('Native initialization returned false');
      }
    } on PlatformException catch (e) {
      _isInitialized = false;
      print(
          '❌ Flutter: PlatformException during initialization: ${e.code} - ${e.message}');
      print('   Details: ${e.details}');
      rethrow;
    } on TimeoutException catch (e) {
      _isInitialized = false;
      print('❌ Flutter: Timeout during initialization: $e');
      rethrow;
    } catch (e) {
      _isInitialized = false;
      print('❌ Flutter: Unexpected error during initialization: $e');
      rethrow;
    }
  }

  // Add initialization check helper
  void _checkInitialization() {
    print('🔍 Flutter: Checking initialization status: $_isInitialized');
    if (!_isInitialized) {
      print('❌ Flutter: Not initialized, throwing StateError');
      throw StateError(
          'XPrinterPck not initialized. Call XPrinterPck.initialize() first.');
    }
  }

  // Handle incoming method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    print('📞 Flutter: Received method call: ${call.method}');

    switch (call.method) {
      case 'onScanResults':
        final devices = (call.arguments as List)
            .cast<Map<dynamic, dynamic>>()
            .map((device) => _convertToStringDynamicMap(device))
            .toList();
        print('📱 Flutter: Scan results received: ${devices.length} devices');
        _scanResultsHandler?.call(devices);
        break;

      case 'onConnectionChanged':
        final status = _convertToStringDynamicMap(call.arguments);
        print('📱 Flutter: Connection status changed: ${status['status']}');
        _connectionChangedHandler?.call(status);
        break;

      default:
        print('❓ Flutter: Unknown method call: ${call.method}');
    }
  }

  // Helper method to convert Map<dynamic, dynamic> to Map<String, dynamic>
  Map<String, dynamic> _convertToStringDynamicMap(Map<dynamic, dynamic> map) {
    return map.map((key, value) => MapEntry(key.toString(), value));
  }

  @override
  Future<bool> scanDevices() async {
    print('🔍 Flutter: scanDevices() called');
    _checkInitialization();

    try {
      print('📱 Flutter: Calling native scanDevices...');
      final result = await methodChannel.invokeMethod('scanDevices');
      print('📱 Flutter: Native scanDevices returned: $result');
      return result;
    } catch (e) {
      print('❌ Flutter: Error in scanDevices: $e');
      rethrow;
    }
  }

  @override
  Future<bool> stopScan() async {
    print('⏹️ Flutter: stopScan() called');
    _checkInitialization();
    return await methodChannel.invokeMethod('stopScan');
  }

  @override
  Future<bool> connectDevice(int index) async {
    print('🔗 Flutter: connectDevice($index) called');
    _checkInitialization();
    return await methodChannel.invokeMethod('connectDevice', {'index': index});
  }

  @override
  Future<bool> disconnectDevice() async {
    print('🔌 Flutter: disconnectDevice() called');
    _checkInitialization();
    return await methodChannel.invokeMethod('disconnectDevice');
  }

  @override
  Future<bool> printText(String text, {int fontSize = 1}) async {
    print('📄 Flutter: printText() called');
    _checkInitialization();
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
    print('📊 Flutter: printBarcode() called');
    _checkInitialization();
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
    print('🔲 Flutter: printQRCode() called');
    _checkInitialization();
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
    int printerWidth = 350,
    int printerHeight = 350,
    int rotation = 0,
    double scale = 0.91,
  }) async {
    print('🖼️ Flutter: printImage() called');
    _checkInitialization();
    return await methodChannel.invokeMethod('printImage', {
      'imageData': imageData,
      'commandType': commandType,
      'printerWidth': printerWidth,
      'printerHeight': printerHeight,
      'rotation': rotation,
      'scale': scale,
    });
  }

  @override
  Future<bool> printImageBase64(
    String base64String, {
    int commandType = 0,
    int printerWidth = 350,
    int printerHeight = 350,
    int rotation = 0,
    double scale = 0.91,
    double quality = 1.0,
    String alignment = 'center',
    int? x,
    int? y,
  }) async {
    print('🎨 Flutter: printImageBase64() called');
    _checkInitialization();
    return await methodChannel.invokeMethod('printImageBase64', {
      'base64String': base64String,
      'commandType': commandType,
      'printerWidth': printerWidth,
      'printerHeight': printerHeight,
      'rotation': rotation,
      'scale': scale,
      'quality': quality,
      'alignment': alignment,
      if (x != null) 'x': x,
      if (y != null) 'y': y,
    });
  }

  @override
  Future<bool> printPDF(
    String pdfPath, {
    int commandType = 0,
    int printerWidth = 350,
    int printerHeight = 350,
    int rotation = 0,
    double scale = 0.91,
    int? startPage,
    int? endPage,
    String? password,
  }) async {
    print('📑 Flutter: printPDF() called');
    _checkInitialization();
    try {
      return await methodChannel.invokeMethod('printPDF', {
        'pdfPath': pdfPath,
        'commandType': commandType,
        'printerWidth': printerWidth,
        'printerHeight': printerHeight,
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
    print('📊 Flutter: getPrinterStatus() called');
    _checkInitialization();
    final result = await methodChannel.invokeMethod('getPrinterStatus');
    return {
      'code': result['code'],
      'message': result['message'],
    };
  }

  @override
  void registerScanResultsHandler(
      Function(List<Map<String, dynamic>>) handler) {
    print('📝 Flutter: Registering scan results handler');
    _scanResultsHandler = handler;
  }

  @override
  void registerConnectionChangedHandler(
      Function(Map<String, dynamic>) handler) {
    print('📝 Flutter: Registering connection changed handler');
    _connectionChangedHandler = handler;
  }
}
