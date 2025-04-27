//
//  XPrinterPckPlugin.m
//  Flutter POS Printer Plugin
//

#import "XPrinterPckPlugin.h"


// #import "PrinterSDK/Headers/POSBLEManager.h"
// #import "PrinterSDK/Headers/POSCommand.h"
#import "TSCPrinterSDK.h"
#import "TSCBLEManager.h"

@implementation XPrinterPckPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"x_printer_eq"
                                     binaryMessenger:[registrar messenger]];
    XPrinterPckPlugin* instance = [[XPrinterPckPlugin alloc] init];
    instance.channel = channel;
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.peripherals = [NSMutableArray array];
        self.rssiList = [NSMutableArray array];
        self.bleManager = [TSCBLEManager sharedInstance];
        self.bleManager.delegate = self;
    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"scanDevices" isEqualToString:call.method]) {
        [self startScanDevices:result];
    } else if ([@"stopScan" isEqualToString:call.method]) {
        [self stopScan:result];
    } else if ([@"connectDevice" isEqualToString:call.method]) {
        [self connectDevice:call.arguments result:result];
    } else if ([@"disconnectDevice" isEqualToString:call.method]) {
        [self disconnectDevice:result];
    } else if ([@"printText" isEqualToString:call.method]) {
        [self printText:call.arguments result:result];
    } else if ([@"printBarcode" isEqualToString:call.method]) {
        [self printBarcode:call.arguments result:result];
    } else if ([@"printQRCode" isEqualToString:call.method]) {
        [self printQRCode:call.arguments result:result];
    } else if ([@"printImage" isEqualToString:call.method]) {
        [self printImage:call.arguments result:result];
    } else if ([@"getPrinterStatus" isEqualToString:call.method]) {
        [self getPrinterStatus:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

#pragma mark - Device Methods

- (void)startScanDevices:(FlutterResult)result {
    [self.peripherals removeAllObjects];
    [self.rssiList removeAllObjects];
    [self.bleManager startScan];
    result(@YES);
}

- (void)stopScan:(FlutterResult)result {
    [self.bleManager stopScan];
    result(@YES);
}

- (void)connectDevice:(id)arguments result:(FlutterResult)result {
    NSDictionary *args = arguments;
    NSInteger index = [args[@"index"] integerValue];
    
    if (index >= 0 && index < [self.peripherals count]) {
        CBPeripheral *peripheral = self.peripherals[index];
        [self.bleManager connectDevice:peripheral];
        result(@YES);
    } else {
        result([FlutterError errorWithCode:@"INVALID_INDEX"
                                   message:@"Invalid device index"
                                   details:nil]);
    }
}

- (void)disconnectDevice:(FlutterResult)result {
    [self.bleManager disconnectRootPeripheral];
    result(@YES);
}

#pragma mark - Printing Methods

- (void)printText:(id)arguments result:(FlutterResult)result {
    if (!self.bleManager.isConnecting) {
        result([FlutterError errorWithCode:@"NOT_CONNECTED"
                                   message:@"Printer not connected"
                                   details:nil]);
        return;
    }
    
    NSDictionary *args = arguments;
    NSString *text = args[@"text"];
    NSInteger fontSize = [args[@"fontSize"] integerValue];
    
    if (!text) {
        result([FlutterError errorWithCode:@"INVALID_ARGUMENTS"
                                   message:@"Text is required"
                                   details:nil]);
        return;
    }
    
    NSMutableData *dataM = [[NSMutableData alloc] init];
    NSStringEncoding gbkEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    
    [dataM appendData:[TSCCommand sizeBymmWithWidth:70 andHeight:85]];
    [dataM appendData:[TSCCommand gapBymmWithWidth:2 andHeight:0]];
    [dataM appendData:[TSCCommand cls]];
    
    // Choose font based on fontSize parameter
    NSString *font = @"2";
    if (fontSize == 2) {
        font = @"3";
    } else if (fontSize == 3) {
        font = @"4";
    } else if (fontSize == 4) {
        font = @"5";
    }
    
    [dataM appendData:[TSCCommand textWithX:0 andY:10 andFont:font andRotation:0 andX_mul:1 andY_mul:1 andContent:text usStrEnCoding:gbkEncoding]];
    [dataM appendData:[TSCCommand print:1]];
    
    [self sendDataToPrinter:dataM result:result];
}

- (void)printBarcode:(id)arguments result:(FlutterResult)result {
    if (!self.bleManager.isConnecting) {
        result([FlutterError errorWithCode:@"NOT_CONNECTED"
                                   message:@"Printer not connected"
                                   details:nil]);
        return;
    }
    
    NSDictionary *args = arguments;
    NSString *content = args[@"content"];
    NSInteger x = [args[@"x"] integerValue];
    NSInteger y = [args[@"y"] integerValue];
    NSInteger height = [args[@"height"] integerValue];
    NSString *barcodeType = args[@"type"] ?: @"128";
    
    if (!content) {
        result([FlutterError errorWithCode:@"INVALID_ARGUMENTS"
                                   message:@"Barcode content is required"
                                   details:nil]);
        return;
    }
    
    NSMutableData *dataM = [[NSMutableData alloc] init];
    
    [dataM appendData:[TSCCommand sizeBymmWithWidth:80 andHeight:100]];
    [dataM appendData:[TSCCommand gapBymmWithWidth:2 andHeight:0]];
    [dataM appendData:[TSCCommand cls]];
    [dataM appendData:[TSCCommand barcodeWithX:x andY:y andCodeType:barcodeType andHeight:height andHunabReadable:2 andRotation:0 andNarrow:2 andWide:2 andContent:content usStrEnCoding:NSUTF8StringEncoding]];
    [dataM appendData:[TSCCommand print:1]];
    
    [self sendDataToPrinter:dataM result:result];
}

- (void)printQRCode:(id)arguments result:(FlutterResult)result {
    if (!self.bleManager.isConnecting) {
        result([FlutterError errorWithCode:@"NOT_CONNECTED"
                                   message:@"Printer not connected"
                                   details:nil]);
        return;
    }
    
    NSDictionary *args = arguments;
    NSString *content = args[@"content"];
    NSInteger x = [args[@"x"] integerValue];
    NSInteger y = [args[@"y"] integerValue];
    NSInteger cellWidth = [args[@"cellWidth"] integerValue] ?: 8;
    
    if (!content) {
        result([FlutterError errorWithCode:@"INVALID_ARGUMENTS"
                                   message:@"QR code content is required"
                                   details:nil]);
        return;
    }
    
    NSMutableData *dataM = [[NSMutableData alloc] init];
    
    [dataM appendData:[TSCCommand sizeBymmWithWidth:80 andHeight:100]];
    [dataM appendData:[TSCCommand gapBymmWithWidth:2 andHeight:0]];
    [dataM appendData:[TSCCommand cls]];
    [dataM appendData:[TSCCommand qrCodeWithX:x andY:y andEccLevel:@"M" andCellWidth:cellWidth andMode:@"A" andRotation:0 andContent:content usStrEnCoding:NSUTF8StringEncoding]];
    [dataM appendData:[TSCCommand print:1]];
    
    [self sendDataToPrinter:dataM result:result];
}

- (void)printImage:(id)arguments result:(FlutterResult)result {
    if (!self.bleManager.isConnecting) {
        result([FlutterError errorWithCode:@"NOT_CONNECTED"
                                   message:@"Printer not connected"
                                   details:nil]);
        return;
    }
    
    NSDictionary *args = arguments;
    FlutterStandardTypedData *imageData = args[@"imageData"];
    
    if (!imageData) {
        result([FlutterError errorWithCode:@"INVALID_ARGUMENTS"
                                   message:@"Image data is required"
                                   details:nil]);
        return;
    }
    
    NSData *data = [imageData data];
    UIImage *image = [UIImage imageWithData:data];
    
    if (!image) {
        result([FlutterError errorWithCode:@"INVALID_IMAGE"
                                   message:@"Invalid image data"
                                   details:nil]);
        return;
    }
    
    NSMutableData *dataM = [[NSMutableData alloc] init];
    
    [dataM appendData:[TSCCommand sizeBymmWithWidth:80 andHeight:50]];
    [dataM appendData:[TSCCommand gapBymmWithWidth:0 andHeight:0]];
    [dataM appendData:[TSCCommand cls]];
    [dataM appendData:[TSCCommand bitmapWithX:0 andY:0 andMode:0 andImage:image]];
    [dataM appendData:[TSCCommand print:1]];
    
    [self sendDataToPrinter:dataM result:result];
}

- (void)getPrinterStatus:(FlutterResult)result {
    if (!self.bleManager.isConnecting) {
        result([FlutterError errorWithCode:@"NOT_CONNECTED"
                                   message:@"Printer not connected"
                                   details:nil]);
        return;
    }
    
    [self.bleManager printerStatus:^(NSData *status) {
        unsigned statusCode = 0;
        if (status.length == 1) {
            const Byte *byte = (Byte *)[status bytes];
            statusCode = byte[0];
        } else if (status.length == 2) {
            const Byte *byte = (Byte *)[status bytes];
            statusCode = byte[1];
        }
        
        NSString *statusMessage = @"Unknown status";
        
        if (statusCode == 0x00) {
            statusMessage = @"Ready";
        } else if (statusCode == 0x01) {
            statusMessage = @"Cover opened";
        } else if (statusCode == 0x02) {
            statusMessage = @"Paper jam";
        } else if (statusCode == 0x03) {
            statusMessage = @"Cover opened and paper jam";
        } else if (statusCode == 0x04) {
            statusMessage = @"Paper end";
        } else if (statusCode == 0x05) {
            statusMessage = @"Cover opened and Paper end";
        } else if (statusCode == 0x08) {
            statusMessage = @"No Ribbon";
        } else if (statusCode == 0x09) {
            statusMessage = @"Cover opened and no Ribbon";
        } else if (statusCode == 0x10) {
            statusMessage = @"Pause";
        } else if (statusCode == 0x20) {
            statusMessage = @"Printing";
        }
        
        result(@{
            @"code": @(statusCode),
            @"message": statusMessage
        });
    }];
}

#pragma mark - Helper Methods

- (void)sendDataToPrinter:(NSMutableData *)data result:(FlutterResult)result {
    __weak typeof(self) weakSelf = self;
    [self.bleManager writeCommandWithData:data writeCallBack:^(CBCharacteristic *characteristic, NSError *error) {
        if (error) {
            result([FlutterError errorWithCode:@"PRINT_ERROR"
                                       message:error.localizedDescription
                                       details:nil]);
            return;
        }
        result(@YES);
    }];
}

#pragma mark - TSCBLEManagerDelegate

- (void)TSCbleUpdatePeripheralList:(NSArray *)peripherals RSSIList:(NSArray *)rssiList {
    // Update local copies
    [self.peripherals removeAllObjects];
    [self.peripherals addObjectsFromArray:peripherals];
    
    [self.rssiList removeAllObjects];
    [self.rssiList addObjectsFromArray:rssiList];
    
    // Convert peripherals to map for Flutter
    NSMutableArray *deviceList = [NSMutableArray array];
    
    for (int i = 0; i < [peripherals count]; i++) {
        CBPeripheral *peripheral = peripherals[i];
        NSNumber *rssi = rssiList[i];
        
        NSMutableDictionary *deviceInfo = [NSMutableDictionary dictionary];
        deviceInfo[@"name"] = peripheral.name ?: @"Unknown";
        deviceInfo[@"address"] = peripheral.identifier.UUIDString;
        deviceInfo[@"rssi"] = rssi;
        
        [deviceList addObject:deviceInfo];
    }
    
    [self.channel invokeMethod:@"onScanResults" arguments:deviceList];
}

- (void)TSCbleConnectPeripheral:(CBPeripheral *)peripheral {
    NSDictionary *deviceInfo = @{
        @"name": peripheral.name ?: @"Unknown",
        @"address": peripheral.identifier.UUIDString,
        @"status": @"connected"
    };
    
    [self.channel invokeMethod:@"onConnectionChanged" arguments:deviceInfo];
}

- (void)TSCbleDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSDictionary *deviceInfo = @{
        @"name": peripheral.name ?: @"Unknown",
        @"address": peripheral.identifier.UUIDString,
        @"status": @"disconnected",
        @"error": error ? error.localizedDescription : @""
    };
    
    [self.channel invokeMethod:@"onConnectionChanged" arguments:deviceInfo];
}

- (void)TSCbleFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSDictionary *deviceInfo = @{
        @"name": peripheral.name ?: @"Unknown",
        @"address": peripheral.identifier.UUIDString,
        @"status": @"failed",
        @"error": error ? error.localizedDescription : @"Failed to connect"
    };
    
    [self.channel invokeMethod:@"onConnectionChanged" arguments:deviceInfo];
}

@end
