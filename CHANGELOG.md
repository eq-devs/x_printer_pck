## 0.0.1

* Initial release
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