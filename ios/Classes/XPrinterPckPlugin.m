#import "XPrinterPckPlugin.h"

#import "PrinterSDK/Headers/POSBLEManager.h"
#import "PrinterSDK/Headers/POSCommand.h"



@interface XPrinterPckPlugin () <POSBLEManagerDelegate>
@property (nonatomic, strong) FlutterMethodChannel *channel;
@property (nonatomic, strong) POSBLEManager *bleManager;
@property (nonatomic, strong) NSMutableArray<CBPeripheral *> *discoveredPeripherals;
@end

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
        _bleManager = [POSBLEManager sharedInstance];
        _bleManager.delegate = self;
        _discoveredPeripherals = [NSMutableArray array];
    }
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"startScan" isEqualToString:call.method]) {
        [self startScan:result];
    } else if ([@"stopScan" isEqualToString:call.method]) {
        [self stopScan:result];
    } else if ([@"connectToDevice" isEqualToString:call.method]) {
        NSString *uuidString = call.arguments[@"uuid"];
        [self connectToDevice:uuidString result:result];
    } else if ([@"disconnect" isEqualToString:call.method]) {
        [self disconnect:result];
    } else if ([@"printText" isEqualToString:call.method]) {
        NSString *text = call.arguments[@"text"];
        [self printText:text result:result];
    } else if ([@"printBarcode" isEqualToString:call.method]) {
        NSString *barcode = call.arguments[@"barcode"];
        NSString *type = call.arguments[@"type"];
        [self printBarcode:barcode type:type result:result];
    } else if ([@"printQRCode" isEqualToString:call.method]) {
        NSString *qrcode = call.arguments[@"qrcode"];
        [self printQRCode:qrcode result:result];
    } else if ([@"printImage" isEqualToString:call.method]) {
        NSString *base64Image = call.arguments[@"image"];
        [self printImage:base64Image result:result];
    } else {
        result(FlutterMethodNotImplemented);
    }
}

#pragma mark - Bluetooth Management Methods

- (void)startScan:(FlutterResult)result {
    [_discoveredPeripherals removeAllObjects];
    [_bleManager startScan];
    result(nil);
}

- (void)stopScan:(FlutterResult)result {
    [_bleManager stopScan];
    result(nil);
}

- (void)connectToDevice:(NSString *)uuidString result:(FlutterResult)result {
    for (CBPeripheral *peripheral in _discoveredPeripherals) {
        if ([peripheral.identifier.UUIDString isEqualToString:uuidString]) {
            [_bleManager connectDevice:peripheral];
            result(nil);
            return;
        }
    }
    result([FlutterError errorWithCode:@"DEVICE_NOT_FOUND" 
                               message:@"Device with specified UUID not found" 
                               details:nil]);
}

- (void)disconnect:(FlutterResult)result {
    [_bleManager disconnectRootPeripheral];
    result(nil);
}

#pragma mark - Printing Methods

- (void)printText:(NSString *)text result:(FlutterResult)result {
    if (![_bleManager printerIsConnect]) {
        result([FlutterError errorWithCode:@"NOT_CONNECTED" 
                                   message:@"Printer is not connected" 
                                   details:nil]);
        return;
    }
    NSMutableData *dataM = [NSMutableData dataWithData:[POSCommand initializePrinter]];
    NSStringEncoding gbkEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    [dataM appendData:[text dataUsingEncoding:gbkEncoding]];
    [dataM appendData:[POSCommand printAndFeedLine]];
    [_bleManager writeCommandWithData:dataM writeCallBack:^(CBCharacteristic *characteristic, NSError *error) {
        if (error) {
            result([FlutterError errorWithCode:@"WRITE_ERROR" 
                                       message:error.localizedDescription 
                                       details:nil]);
        } else {
            result(nil);
        }
    }];
}

- (void)printBarcode:(NSString *)barcode type:(NSString *)type result:(FlutterResult)result {
    if (![_bleManager printerIsConnect]) {
        result([FlutterError errorWithCode:@"NOT_CONNECTED" 
                                   message:@"Printer is not connected" 
                                   details:nil]);
        return;
    }
    NSDictionary *barcodeTypes = @{
        @"UPC-A": @0,
        @"UPC-E": @1,
        @"JAN13": @2,
        @"JAN8": @3,
        @"CODE39": @4,
        @"ITF": @5,
        @"CODEBAR": @6,
        @"CODE93": @72,
        @"CODE128": @73
    };
    NSNumber *m = barcodeTypes[type];
    if (m == nil) {
        result([FlutterError errorWithCode:@"INVALID_TYPE" 
                                   message:@"Invalid barcode type" 
                                   details:nil]);
        return;
    }
    int mValue = [m intValue];
    NSMutableData *dataM = [NSMutableData dataWithData:[POSCommand initializePrinter]];
    [dataM appendData:[POSCommand selectAlignment:1]]; // Center alignment
    [dataM appendData:[POSCommand setBarcodeHeight:70]];
    [dataM appendData:[POSCommand printBarcodeWithM:mValue 
                                         andContent:barcode 
                                      useEnCodeing:NSUTF8StringEncoding]];
    [dataM appendData:[POSCommand printAndFeedLine]];
    [_bleManager writeCommandWithData:dataM writeCallBack:^(CBCharacteristic *characteristic, NSError *error) {
        if (error) {
            result([FlutterError errorWithCode:@"WRITE_ERROR" 
                                       message:error.localizedDescription 
                                       details:nil]);
        } else {
            result(nil);
        }
    }];
}

- (void)printQRCode:(NSString *)qrcode result:(FlutterResult)result {
    if (![_bleManager printerIsConnect]) {
        result([FlutterError errorWithCode:@"NOT_CONNECTED" 
                                   message:@"Printer is not connected" 
                                   details:nil]);
        return;
    }
    NSMutableData *dataM = [NSMutableData dataWithData:[POSCommand initializePrinter]];
    [dataM appendData:[POSCommand selectAlignment:1]]; // Center alignment
    [dataM appendData:[POSCommand printQRCode:6 
                                        level:48 
                                         code:qrcode 
                                useEnCodeing:NSUTF8StringEncoding]];
    [dataM appendData:[POSCommand printAndFeedLine]];
    [_bleManager writeCommandWithData:dataM writeCallBack:^(CBCharacteristic *characteristic, NSError *error) {
        if (error) {
            result([FlutterError errorWithCode:@"WRITE_ERROR" 
                                       message:error.localizedDescription 
                                       details:nil]);
        } else {
            result(nil);
        }
    }];
}

- (void)printImage:(NSString *)base64Image result:(FlutterResult)result {
    if (![_bleManager printerIsConnect]) {
        result([FlutterError errorWithCode:@"NOT_CONNECTED" 
                                   message:@"Printer is not connected" 
                                   details:nil]);
        return;
    }
    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Image options:0];
    UIImage *image = [UIImage imageWithData:imageData];
    if (image == nil) {
        result([FlutterError errorWithCode:@"INVALID_IMAGE" 
                                   message:@"Invalid image data" 
                                   details:nil]);
        return;
    }
    NSMutableData *dataM = [NSMutableData dataWithData:[POSCommand initializePrinter]];
    [dataM appendData:[POSCommand selectAlignment:1]]; // Center alignment
    [dataM appendData:[POSCommand printRasteBmpWithM:RasterNolmorWH 
                                           andImage:image 
                                            andType:Dithering]];
    [dataM appendData:[POSCommand printAndFeedLine]];
    [_bleManager writeCommandWithData:dataM writeCallBack:^(CBCharacteristic *characteristic, NSError *error) {
        if (error) {
            result([FlutterError errorWithCode:@"WRITE_ERROR" 
                                       message:error.localizedDescription 
                                       details:nil]);
        } else {
            result(nil);
        }
    }];
}

#pragma mark - POSBLEManagerDelegate Methods

- (void)POSbleUpdatePeripheralList:(NSArray *)peripherals RSSIList:(NSArray *)rssiList {
    _discoveredPeripherals = [peripherals mutableCopy];
    NSMutableArray *deviceList = [NSMutableArray array];
    for (CBPeripheral *peripheral in peripherals) {
        [deviceList addObject:peripheral.identifier.UUIDString];
    }
    [self.channel invokeMethod:@"onDevicesUpdated" arguments:deviceList];
}

- (void)POSbleConnectPeripheral:(CBPeripheral *)peripheral {
    [self.channel invokeMethod:@"onConnectionStateChanged" arguments:@"connected"];
}

- (void)POSbleDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self.channel invokeMethod:@"onConnectionStateChanged" arguments:@"disconnected"];
}

@end


// @implementation XPrinterPckPlugin
// + (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {

//   FlutterMethodChannel* channel = [FlutterMethodChannel
//       methodChannelWithName:@"x_printer_pck"
//             binaryMessenger:[registrar messenger]];
//   XPrinterPckPlugin* instance = [[XPrinterPckPlugin alloc] init];
//   [registrar addMethodCallDelegate:instance channel:channel];
// }

// - (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
//   if ([@"getPlatformVersion" isEqualToString:call.method]) {
//     result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
//   } else {
//     result(FlutterMethodNotImplemented);
//   }
// }

// @end
