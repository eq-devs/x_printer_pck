import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:x_printer_pck/x_printer_pck.dart';

void main() {
  runApp(const MaterialApp(home: Scaffold(body: MyApp())));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _printerPlugin = XPrinterPck();

  List<String> _devices = [];
  String _connectionStatus = 'disconnected';
  String? _selectedDevice;

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _qrcodeController = TextEditingController();

  // Subscription for device discovery events
  StreamSubscription<List<String>>? _devicesSubscription;

  // Subscription for connection state changes
  StreamSubscription<String>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _setupSubscriptions();
  }

  void _setupSubscriptions() {
    // Listen for device discovery events
    _devicesSubscription =
        _printerPlugin.devicesDiscoveredStream.listen((devices) {
      setState(() {
        _devices = devices;
      });
    });

    // Listen for connection state changes
    _connectionSubscription =
        _printerPlugin.connectionStateStream.listen((state) {
      setState(() {
        _connectionStatus = state;
        if (state == 'disconnected') {
          _selectedDevice = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    _connectionSubscription?.cancel();
    _textController.dispose();
    _barcodeController.dispose();
    _qrcodeController.dispose();
    super.dispose();
  }

  // Start scanning for devices
  Future<void> _startScan() async {
    try {
      await _printerPlugin.startScan();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scanning started')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting scan: $e')),
      );
    }
  }

  // Stop scanning for devices
  Future<void> _stopScan() async {
    try {
      await _printerPlugin.stopScan();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scanning stopped')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping scan: $e')),
      );
    }
  }

  // Connect to a selected device
  Future<void> _connectToDevice(String uuid) async {
    try {
      await _printerPlugin.connectToDevice(uuid);
      setState(() {
        _selectedDevice = uuid;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error connecting to device: $e')),
      );
    }
  }

  // Disconnect from the current device
  Future<void> _disconnect() async {
    try {
      await _printerPlugin.disconnect();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error disconnecting: $e')),
      );
    }
  }

  // Print text
  Future<void> _printText() async {
    if (_textController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter text to print')),
      );
      return;
    }

    try {
      await _printerPlugin.printText(_textController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text printed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error printing text: $e')),
      );
    }
  }

  // Print barcode
  Future<void> _printBarcode() async {
    if (_barcodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter barcode data')),
      );
      return;
    }

    try {
      // Using CODE128 as default barcode type
      await _printerPlugin.printBarcode(_barcodeController.text, 'CODE128');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barcode printed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error printing barcode: $e')),
      );
    }
  }

  // Print QR code
  Future<void> _printQRCode() async {
    if (_qrcodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter QR code data')),
      );
      return;
    }

    try {
      await _printerPlugin.printQRCode(_qrcodeController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR code printed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error printing QR code: $e')),
      );
    }
  }

  // Example function to print an image - in a real app, you would get the image from a file or camera
  Future<void> _printSampleImage() async {
    try {
      // This is a placeholder - you would replace with real image data
      // For this example, we're using a simple base64 encoded 1x1 pixel image
      const String base64Image =
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=";

      await _printerPlugin.printImage(base64Image);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sample image printed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error printing image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('X Printer Plugin Example'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bluetooth controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Connection Status: $_connectionStatus',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _startScan,
                          child: const Text('Start Scan'),
                        ),
                        ElevatedButton(
                          onPressed: _stopScan,
                          child: const Text('Stop Scan'),
                        ),
                        ElevatedButton(
                          onPressed: _connectionStatus == 'connected'
                              ? _disconnect
                              : null,
                          child: const Text('Disconnect'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Device list
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Discovered Devices:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _devices.isEmpty
                        ? const Text('No devices found')
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _devices.length,
                            itemBuilder: (context, index) {
                              final device = _devices[index];
                              return ListTile(
                                title: Text(device),
                                trailing: ElevatedButton(
                                  onPressed: _connectionStatus == 'connected'
                                      ? null
                                      : () => _connectToDevice(device),
                                  child: const Text('Connect'),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Print controls - only enabled when connected
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Print Functions:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // Text printing
                    TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        labelText: 'Text to print',
                        border: OutlineInputBorder(),
                      ),
                      enabled: _connectionStatus == 'connected',
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed:
                          _connectionStatus == 'connected' ? _printText : null,
                      child: const Text('Print Text'),
                    ),
                    const SizedBox(height: 16),

                    // Barcode printing
                    TextField(
                      controller: _barcodeController,
                      decoration: const InputDecoration(
                        labelText: 'Barcode data',
                        border: OutlineInputBorder(),
                      ),
                      enabled: _connectionStatus == 'connected',
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _connectionStatus == 'connected'
                          ? _printBarcode
                          : null,
                      child: const Text('Print Barcode'),
                    ),
                    const SizedBox(height: 16),

                    // QR code printing
                    TextField(
                      controller: _qrcodeController,
                      decoration: const InputDecoration(
                        labelText: 'QR code data',
                        border: OutlineInputBorder(),
                      ),
                      enabled: _connectionStatus == 'connected',
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _connectionStatus == 'connected'
                          ? _printQRCode
                          : null,
                      child: const Text('Print QR Code'),
                    ),
                    const SizedBox(height: 16),

                    // Image printing
                    ElevatedButton(
                      onPressed: _connectionStatus == 'connected'
                          ? _printSampleImage
                          : null,
                      child: const Text('Print Sample Image'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
