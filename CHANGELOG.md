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