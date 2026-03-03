## 0.0.58

- Fixed build error: added missing type declaration for `dataM` in native iOS code.

## 0.0.57

- Fixed UI freeze on iOS during PDF and image printing by moving all processing logic to background threads.
- Refactored native iOS code to use shared helper methods for image processing and command generation.
- Improved memory management in PDF printing using `@autoreleasepool`.
- Fast-paced printing: Removed hardcoded delays between pages, relying on printer buffer management.
- Cleaned up native code and removed redundant comments/logging for production readiness.
- Removed extraneous boilerplate tests to keep the package lean.

## 0.0.5

- Fixed print vertical alignment to start with a standard top margin instead of center alignment.
- Optimized `printPDF` using native Core Graphics API for extremely reliable PDF reading and page counting, replacing the unreliable `LabelDocument` SDK logic.
- Expanded inter-page BLE delay to allow large PDF pages to finish processing without overflowing the printer buffer.
- Removed unnecessary debug logs from production iOS code for better performance.

## 0.0.4
* Support for iOS Bluetooth thermal printer integration
* Features include device scanning, connection management, text printing, barcode/QR code printing, and image printing



## 0.0.2

feat: integrate image_picker and enhance printImage functionality

- Added image_picker dependency for image selection.
- Updated Podfile.lock to include image_picker_ios.
- Enhanced printImage method to accept additional parameters: commandType, printerWidth, printerHeight, rotation, and scale.
- Improved error handling and logging in XPrinterPckPlugin.m.
- Updated Info.plist for camera and photo library permissions.
- Added alignment options for image printing.



## 0.0.3


feat: Add PDF printing functionality to x_printer_pck

- Updated Podfile to use frameworks for better compatibility.
- Enhanced Podfile.lock with new dependencies including file_picker and path_provider.
- Modified project.pbxproj to include new Pods frameworks.
- Implemented PDF selection and printing in main.dart with user interface.
- Added printPDF method in XPrinterPck class for handling PDF printing.
- Extended MethodChannel to support PDF printing commands.
- Updated platform interface to declare printPDF method.
- Enhanced XPrinterPckPlugin.m to handle PDF printing logic.



## 0.0.4

Enhance printing capabilities with base64 support and improved defaults

- Added printImageBase64 method for printing images from base64 strings with advanced configuration options.
- Updated printImage and printPDF methods to use improved default values for printer width, height, and scale.
- Introduced PrinterCommandType enum for better command type management.
- Enhanced error handling and validation for printImageBase64 parameters.
- Updated platform interface and method channel implementations to support new features.
- Improved BluetoothDevice and ConnectionStatus models with additional properties and string representations.