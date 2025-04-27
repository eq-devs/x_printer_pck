# X Printer Package for iOS

## Overview

The X Printer Package (`x_printer_pck`) is a Flutter plugin that provides integration with Bluetooth thermal printers specifically for iOS devices. This package enables developers to easily connect to compatible printers, send print jobs, and manage printer connections within their Flutter applications.

## Features

- Bluetooth device scanning and discovery
- Printer connection management
- Print text with adjustable font sizes
- Print barcodes (Code 128 and others)
- Print QR codes with customizable parameters
- Print images from device gallery
- Get printer status information

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  x_printer_pck: ^*
```

Then run:

```bash
flutter pub get
```

## iOS Setup Requirements

This package is designed for iOS only. Follow these steps to set up your iOS project:

1. **Update Info.plist**

Add the following permissions to your iOS project's `Info.plist` file:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth access to connect to printers</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth access to connect to printers</string>
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

2. **Minimum iOS Version**

This package requires iOS 13.0 or later. Update your `Podfile`:

```ruby
platform :ios, '13.0'
```

## Usage

### Initialization

Initialize the printer package before using it, typically in your app's initialization:

```dart
import 'package:x_printer_pck/x_printer_pck.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  XPrinterPck.initialize();
  runApp(MyApp());
}
```

### Scanning for Devices

```dart
// Start scanning for printers
await XPrinterPck.scanDevices();

// Register a listener for scan results
XPrinterPck.onScanResults = (List<BluetoothDevice> devices) {
  // Handle the discovered devices
  setState(() {
    _devices = devices;
  });
};

// Stop scanning when done
await XPrinterPck.stopScan();
```

### Connecting to a Printer

```dart
// Connect to a printer by its index in the scan results
await XPrinterPck.connectDevice(deviceIndex);

// Register a listener for connection status changes
XPrinterPck.onConnectionChanged = (ConnectionStatus status) {
  setState(() {
    _connectionStatus = status;
    _isConnected = status.isConnected;
  });
};

// Disconnect when done
await XPrinterPck.disconnectDevice();
```

### Printing Text

```dart
// Print text with default font size
await XPrinterPck.printText("Hello, Printer!");

// Print text with larger font size
await XPrinterPck.printText("LARGE TEXT", fontSize: 3);
```

### Printing Barcodes

```dart
// Print a barcode with default settings
await XPrinterPck.printBarcode("123456789");

// Print a barcode with custom parameters
await XPrinterPck.printBarcode(
  "123456789",
  x: 150,         // X position
  y: 100,         // Y position
  height: 100,    // Barcode height
  type: "CODE39", // Barcode type
);
```

### Printing QR Codes

```dart
// Print a QR code with default settings
await XPrinterPck.printQRCode("https://example.com");

// Print a QR code with custom parameters
await XPrinterPck.printQRCode(
  "https://example.com",
  x: 300,         // X position
  y: 150,         // Y position
  cellWidth: 10,  // Cell width (determines QR code size)
);
```

### Printing Images

```dart
// Select an image using image_picker
final ImagePicker picker = ImagePicker();
final XFile? image = await picker.pickImage(source: ImageSource.gallery);

if (image != null) {
  // Convert image to bytes and print it
  final bytes = await image.readAsBytes();
  await XPrinterPck.printImage(bytes);
}
```

### Getting Printer Status

```dart
// Check the printer status
final PrinterStatus status = await XPrinterPck.getPrinterStatus();

if (status.isReady) {
  print("Printer is ready");
} else {
  print("Printer error: ${status.message}");
}
```

## Example App

Check out the example folder for a complete implementation of all features, including:

- Device scanning
- Connection management
- Text printing
- Barcode printing
- QR code printing
- Image printing
- Status checking

## Supported Printer Models

This package is designed to work with:

- Star Micronics printers supporting the iOS POSPrinting library
- ESC/POS compatible thermal printers with Bluetooth connectivity

## Troubleshooting

### Common Issues

1. **Printer Not Found During Scanning**
   - Ensure Bluetooth is enabled on your iOS device
   - Verify the printer is powered on and in discoverable mode
   - Try restarting the printer

2. **Connection Issues**
   - Check that your printer is supported
   - Ensure the printer is sufficiently charged
   - Try forgetting the device in iOS Bluetooth settings and reconnecting

3. **Printing Quality Issues**
   - Check printer paper quality
   - Adjust font size or print density settings
   - For image printing, ensure the image is not too large or complex

## Technical Notes for iOS Developers

### Native Implementation

The plugin uses a Swift implementation that interfaces with CoreBluetooth and the printer's custom SDKs.

### Memory Management

Be aware of memory usage when printing large images. The plugin optimizes images for thermal printing but very large images may cause performance issues.

### Background Mode Support

The plugin supports background mode connections, but be aware of iOS background restrictions that may affect long-running Bluetooth operations.

## Limitations

- iOS only - Android is not supported
- Some advanced printer-specific features may not be available
- Limited customization for print layouts

## Feedback and Contributions

Please report any issues or feature requests via the GitHub repository. Contributions are welcome!

## License

This project is licensed under the MIT License - see the LICENSE file for details.