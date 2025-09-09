import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:x_printer_pck/x_printer_pck.dart';
import 'package:x_printer_pck/x_printer_pck_method_channel.dart';

void main() {
  runApp(const MaterialApp(home: Scaffold(body: Base64PrinterExample())));
}

class Base64PrinterExample extends StatelessWidget {
  const Base64PrinterExample({super.key});

  @override
  Widget build(BuildContext context) => const Base64PrinterPage();
}

@immutable
class Base64PrinterPage extends StatefulWidget {
  const Base64PrinterPage({super.key});

  @override
  _Base64PrinterPageState createState() => _Base64PrinterPageState();
}

class _Base64PrinterPageState extends State<Base64PrinterPage> {
  final List<BluetoothDevice> _devices = [];
  ConnectionStatus? _connectionStatus;
  final TextEditingController _base64Controller = TextEditingController();
  bool _isScanning = false;
  String _statusMessage = '';

  // Configuration variables
  PrinterCommandType _commandType = PrinterCommandType.tspl;
  int _printerWidth = 384;
  int _printerHeight = 600;
  int _rotation = 0;
  double _scale = 0.9;
  double _quality = 1.0;
  PrintAlignment _alignment = PrintAlignment.center;
  int _customX = 0;
  int _customY = 0;

  // Sample base64 images for testing
  final Map<String, String> _sampleImages = {
    'Small Test Image':
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
    'Data URL Format':
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
    'QR Code Sample':
        '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCdABmX/9k=',
  };

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
      _statusMessage = 'Scanning for devices...';
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

  // Print Base64 image with current configuration
  Future<void> _printBase64Image() async {
    if (_base64Controller.text.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter a Base64 string';
      });
      return;
    }

    try {
      setState(() {
        _statusMessage = 'Printing Base64 image...';
      });

      bool result = await XPrinterPck.printImageBase64(
        _base64Controller.text,
        commandType: _commandType,
        printerWidth: _printerWidth,
        printerHeight: _printerHeight,
        rotation: _rotation,
        scale: _scale,
        quality: _quality,
        alignment: _alignment,
        x: _alignment == PrintAlignment.custom ? _customX : null,
        y: _alignment == PrintAlignment.custom ? _customY : null,
      );

      setState(() {
        _statusMessage = result
            ? 'Base64 image printed successfully!'
            : 'Failed to print Base64 image';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error printing Base64 image: $e';
      });
      print('Print error: $e');
    }
  }

  // Convert image file to Base64 and print
  Future<void> _pickImageAndConvertToBase64() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);

        setState(() {
          _base64Controller.text = base64String;
          _statusMessage = 'Image converted to Base64. Ready to print!';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error converting image to Base64: $e';
      });
    }
  }

  // Test different configurations
  Future<void> _testDifferentConfigurations() async {
    if (_base64Controller.text.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter a Base64 string first';
      });
      return;
    }

    final configurations = [
      {
        'name': 'Center Aligned',
        'alignment': PrintAlignment.center,
        'scale': 0.8,
      },
      {
        'name': 'Top Left',
        'alignment': PrintAlignment.topLeft,
        'scale': 0.6,
      },
      {
        'name': 'Rotated 90°',
        'alignment': PrintAlignment.center,
        'rotation': 90,
        'scale': 0.7,
      },
      {
        'name': 'High Quality',
        'alignment': PrintAlignment.center,
        'quality': 1.0,
        'scale': 0.9,
      },
      {
        'name': 'Custom Position',
        'alignment': PrintAlignment.custom,
        'x': 100,
        'y': 50,
        'scale': 0.5,
      },
    ];

    for (var config in configurations) {
      setState(() {
        _statusMessage = 'Printing: ${config['name']}...';
      });

      try {
        await XPrinterPck.printImageBase64(
          _base64Controller.text,
          commandType: _commandType,
          printerWidth: _printerWidth,
          printerHeight: _printerHeight,
          rotation: int.parse(config['rotation']?.toString() ?? '0'),
          scale: double.tryParse(config['scale']?.toString() ?? '0') ?? 0.9,
          quality: double.tryParse(config['quality']?.toString() ?? '0') ?? 1.0,
          // alignment: config['alignment'] ?? PrintAlignment.center,
          x: int.tryParse(config['x']?.toString() ?? '0'),
          y: int.tryParse(config['y']?.toString() ?? '0'),
          // config['y'],
        );

        // Wait between prints
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        setState(() {
          _statusMessage = 'Error in ${config['name']}: $e';
        });
        return;
      }
    }

    setState(() {
      _statusMessage = 'All test configurations completed!';
    });
  }

  // Performance test
  Future<void> _performanceTest() async {
    if (_base64Controller.text.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter a Base64 string first';
      });
      return;
    }

    final stopwatch = Stopwatch()..start();

    try {
      setState(() {
        _statusMessage = 'Running performance test...';
      });

      await XPrinterPck.printImageBase64(
        _base64Controller.text,
        commandType: _commandType,
        printerWidth: _printerWidth,
        printerHeight: _printerHeight,
        quality: 1.0,
      );

      stopwatch.stop();
      setState(() {
        _statusMessage =
            'Performance test completed in ${stopwatch.elapsedMilliseconds}ms';
      });
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _statusMessage =
            'Performance test failed: $e (${stopwatch.elapsedMilliseconds}ms)';
      });
    }
  }

  void _getPrinterStatus() async {
    try {
      final status = await XPrinterPck.getPrinterStatus();
      setState(() {
        _statusMessage =
            'Printer Status: ${status.message} (Code: 0x${status.code.toRadixString(16).toUpperCase()})';
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
        title: const Text('Base64 Printer Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
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
              // Status Card
              Card(
                color: isConnected ? Colors.green[50] : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        isConnected ? Icons.check_circle : Icons.error,
                        color: isConnected ? Colors.green : Colors.red,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isConnected
                            ? 'Connected to ${_connectionStatus?.name}'
                            : 'Not Connected',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Device Scanning Section
              if (!isConnected) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Bluetooth Devices',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: Icon(
                                    _isScanning ? Icons.stop : Icons.search),
                                label: Text(
                                    _isScanning ? 'Stop Scan' : 'Scan Devices'),
                                onPressed:
                                    _isScanning ? _stopScan : _scanDevices,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _isScanning ? Colors.red : Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_devices.isEmpty && _isScanning)
                          const Center(child: CircularProgressIndicator())
                        else if (_devices.isEmpty && !_isScanning)
                          const Center(
                              child: Text('No devices found. Try scanning.'))
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _devices.length,
                            separatorBuilder: (context, index) =>
                                const Divider(),
                            itemBuilder: (context, index) {
                              final device = _devices[index];
                              return ListTile(
                                leading: const Icon(Icons.bluetooth,
                                    color: Colors.blue),
                                title: Text(device.name),
                                subtitle: Text('RSSI: ${device.rssi} dBm'),
                                trailing: ElevatedButton(
                                  onPressed: () => _connectToDevice(index),
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
              ],

              // Disconnect Button
              if (isConnected) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.bluetooth_disabled),
                  label: const Text('Disconnect'),
                  onPressed: _disconnectDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Configuration Panel
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Printer Configuration',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),

                      // Command Type
                      Row(
                        children: [
                          const Text('Command Type: '),
                          const SizedBox(width: 8),
                          DropdownButton<PrinterCommandType>(
                            value: _commandType,
                            onChanged: (PrinterCommandType? value) {
                              if (value != null) {
                                setState(() {
                                  _commandType = value;
                                });
                              }
                            },
                            items: PrinterCommandType.values
                                .map((PrinterCommandType type) {
                              return DropdownMenuItem<PrinterCommandType>(
                                value: type,
                                child: Text(type.name.toUpperCase()),
                              );
                            }).toList(),
                          ),
                        ],
                      ),

                      // Printer Size
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Width (dots)'),
                                Slider(
                                  value: _printerWidth.toDouble(),
                                  min: 200,
                                  max: 1000,
                                  divisions: 16,
                                  label: _printerWidth.toString(),
                                  onChanged: (double value) {
                                    setState(() {
                                      _printerWidth = value.round();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Height (dots)'),
                                Slider(
                                  value: _printerHeight.toDouble(),
                                  min: 200,
                                  max: 1000,
                                  divisions: 16,
                                  label: _printerHeight.toString(),
                                  onChanged: (double value) {
                                    setState(() {
                                      _printerHeight = value.round();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Scale and Quality
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Scale: ${_scale.toStringAsFixed(2)}'),
                                Slider(
                                  value: _scale,
                                  min: 0.1,
                                  max: 1.0,
                                  divisions: 9,
                                  onChanged: (double value) {
                                    setState(() {
                                      _scale = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Quality: ${_quality.toStringAsFixed(2)}'),
                                Slider(
                                  value: _quality,
                                  min: 0.1,
                                  max: 1.0,
                                  divisions: 9,
                                  onChanged: (double value) {
                                    setState(() {
                                      _quality = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Rotation
                      Row(
                        children: [
                          const Text('Rotation: '),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: _rotation,
                            onChanged: (int? value) {
                              if (value != null) {
                                setState(() {
                                  _rotation = value;
                                });
                              }
                            },
                            items: [0, 90, 180, 270].map((int rotation) {
                              return DropdownMenuItem<int>(
                                value: rotation,
                                child: Text('${rotation}°'),
                              );
                            }).toList(),
                          ),
                        ],
                      ),

                      // Alignment
                      Row(
                        children: [
                          const Text('Alignment: '),
                          const SizedBox(width: 8),
                          DropdownButton<PrintAlignment>(
                            value: _alignment,
                            onChanged: (PrintAlignment? value) {
                              if (value != null) {
                                setState(() {
                                  _alignment = value;
                                });
                              }
                            },
                            items: PrintAlignment.values
                                .map((PrintAlignment alignment) {
                              return DropdownMenuItem<PrintAlignment>(
                                value: alignment,
                                child: Text(alignment.name),
                              );
                            }).toList(),
                          ),
                        ],
                      ),

                      // Custom Position (only if alignment is custom)
                      if (_alignment == PrintAlignment.custom)
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'X Position',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (String value) {
                                  _customX = int.tryParse(value) ?? 0;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  labelText: 'Y Position',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (String value) {
                                  _customY = int.tryParse(value) ?? 0;
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Base64 Input Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Base64 Image Input',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),

                      // Sample images buttons
                      Wrap(
                        spacing: 8,
                        children: _sampleImages.keys.map((String name) {
                          return ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _base64Controller.text = _sampleImages[name]!;
                                _statusMessage = 'Loaded sample: $name';
                              });
                            },
                            child: Text(name),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 16),

                      // Base64 input field
                      TextField(
                        controller: _base64Controller,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Base64 String',
                          hintText: 'Paste Base64 image data here...',
                        ),
                        maxLines: 5,
                      ),

                      const SizedBox(height: 16),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.image),
                              label: const Text('Pick & Convert'),
                              onPressed: _pickImageAndConvertToBase64,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.clear),
                              label: const Text('Clear'),
                              onPressed: () {
                                setState(() {
                                  _base64Controller.clear();
                                  _statusMessage = 'Base64 input cleared';
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Print Actions
              if (isConnected) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Print Actions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),

                        // Main print button
                        ElevatedButton.icon(
                          icon: const Icon(Icons.print),
                          label: const Text('Print Base64 Image'),
                          onPressed: _base64Controller.text.isNotEmpty
                              ? _printBase64Image
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Test buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.science),
                                label: const Text('Test Configs'),
                                onPressed: _base64Controller.text.isNotEmpty
                                    ? _testDifferentConfigurations
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.speed),
                                label: const Text('Performance'),
                                onPressed: _base64Controller.text.isNotEmpty
                                    ? _performanceTest
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        'Please connect to a printer to enable printing functions',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
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

  @override
  void dispose() {
    _base64Controller.dispose();
    super.dispose();
  }
}
