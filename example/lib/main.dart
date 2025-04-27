import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:x_printer_pck/x_printer_pck.dart';

void main() {
  runApp(const MaterialApp(home: Scaffold(body: MyApp())));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const PrinterPage();
}

@immutable
class PrinterPage extends StatefulWidget {
  const PrinterPage({super.key});

  @override
  _PrinterPageState createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  final List<BluetoothDevice> _devices = [];
  ConnectionStatus? _connectionStatus;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _qrCodeController = TextEditingController();
  Uint8List? _imageData;
  bool _isScanning = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();

    XPrinterPck.initialize();
    // Set up event listeners
    XPrinterPck.onScanResults = (devices) {
      setState(() {
        _devices.clear();
        _devices.addAll(devices);
      });
    };

    XPrinterPck.onConnectionChanged = (status) {
      setState(() {
        _connectionStatus = status;
        _statusMessage = 'Printer ${status.name} is ${status.status}';
        if (status.error.isNotEmpty) {
          _statusMessage += ' (${status.error})';
        }
      });
    };
  }

  void _scanDevices() async {
    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    try {
      await XPrinterPck.scanDevices();

      // Auto-stop scan after 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        if (_isScanning) {
          _stopScan();
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error starting scan: $e';
        _isScanning = false;
      });

      print(e);
    }
  }

  void _stopScan() async {
    try {
      await XPrinterPck.stopScan();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error stopping scan: $e';
      });
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _connectToDevice(int index) async {
    if (index < 0 || index >= _devices.length) return;

    try {
      setState(() {
        _statusMessage = 'Connecting to ${_devices[index].name}...';
      });

      await XPrinterPck.connectDevice(index);
    } catch (e) {
      setState(() {
        _statusMessage = 'Error connecting: $e';
      });
    }
  }

  void _disconnectDevice() async {
    try {
      await XPrinterPck.disconnectDevice();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error disconnecting: $e';
      });
    }
  }

  void _printText() async {
    if (_textController.text.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter text to print';
      });
      return;
    }

    try {
      final result =
          await XPrinterPck.printText(_textController.text, fontSize: 2);
      setState(() {
        _statusMessage =
            result ? 'Text printed successfully' : 'Failed to print text';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error printing text: $e';
      });
    }
  }

  void _printBarcode() async {
    if (_barcodeController.text.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter barcode content';
      });
      return;
    }

    try {
      final result = await XPrinterPck.printBarcode(_barcodeController.text);
      setState(() {
        _statusMessage =
            result ? 'Barcode printed successfully' : 'Failed to print barcode';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error printing barcode: $e';
      });
    }
  }

  void _printQRCode() async {
    if (_qrCodeController.text.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter QR code content';
      });
      return;
    }

    try {
      final result = await XPrinterPck.printQRCode(_qrCodeController.text);
      setState(() {
        _statusMessage =
            result ? 'QR code printed successfully' : 'Failed to print QR code';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error printing QR code: $e';
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageData = bytes;
          _statusMessage = 'Image selected';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error picking image: $e';
      });
    }
  }

  void _printImage() async {
    if (_imageData == null) {
      setState(() {
        _statusMessage = 'Please select an image first';
      });
      return;
    }

    // 2-inch printer: ~384 dots
    // 3-inch printer: ~576 dots
    // 4-inch printer: ~832 dots
    try {
      await XPrinterPck.printImage(_imageData!,
          commandType: 1, printerWidth: 832, scale: 1.25);
    } catch (e) {
      setState(() {
        _statusMessage = 'Error printing image: $e';
      });
    }
  }

  void _getPrinterStatus() async {
    try {
      final status = await XPrinterPck.getPrinterStatus();
      setState(() {
        _statusMessage =
            'Printer status: ${status.message} (code: ${status.code})';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error getting printer status: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = _connectionStatus?.isConnected ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TSC Printer Demo'),
        actions: [
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _getPrinterStatus,
              tooltip: 'Get Printer Status',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text(
                        'Status: ${isConnected ? 'Connected to ${_connectionStatus?.name}' : 'Disconnected'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(_statusMessage),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Device scanning section
              if (!isConnected)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Available Devices',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.search),
                              label: Text(_isScanning ? 'Scanning...' : 'Scan'),
                              onPressed: _isScanning ? _stopScan : _scanDevices,
                            ),
                            if (_isScanning)
                              ElevatedButton.icon(
                                icon: const Icon(Icons.stop),
                                label: const Text('Stop'),
                                onPressed: _stopScan,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_devices.isEmpty && _isScanning)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_devices.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: Text('No devices found')),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _devices.length,
                            itemBuilder: (context, index) {
                              final device = _devices[index];
                              return ListTile(
                                title: Text(device.name),
                                subtitle: Text('RSSI: ${device.rssi}'),
                                trailing: const Icon(Icons.bluetooth),
                                onTap: () => _connectToDevice(index),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

              // Connected printer options
              if (isConnected) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Disconnect'),
                  onPressed: _disconnectDevice,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
                const SizedBox(height: 16),

                // Print Text Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Print Text',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _textController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Enter text to print',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.print),
                          label: const Text('Print Text'),
                          onPressed: _printText,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Print Barcode Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Print Barcode',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _barcodeController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Enter barcode content',
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.print),
                          label: const Text('Print Barcode'),
                          onPressed: _printBarcode,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Print QR Code Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Print QR Code',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _qrCodeController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Enter QR code content',
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.qr_code),
                          label: const Text('Print QR Code'),
                          onPressed: _printQRCode,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Print Image Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Print Image',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _imageData != null
                                  ? Image.memory(
                                      _imageData!,
                                      height: 100,
                                    )
                                  : Container(
                                      height: 100,
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Text('No image selected'),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.photo),
                                label: const Text('Select Image'),
                                onPressed: _pickImage,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.print),
                                label: const Text('Print Image'),
                                onPressed:
                                    _imageData != null ? _printImage : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
