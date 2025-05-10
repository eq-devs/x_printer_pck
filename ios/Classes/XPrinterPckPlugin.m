//
//  XPrinterPckPlugin.m
//  Flutter POS Printer Plugin
//

#import "XPrinterPckPlugin.h"


// #import "PrinterSDK/Headers/POSBLEManager.h"
// #import "PrinterSDK/Headers/POSCommand.h"
#import "TSCPrinterSDK.h"
#import "TSCBLEManager.h"
#import "LabelDocument.h"

@interface XPrinterPckPlugin()
@property (nonatomic, strong) FlutterMethodChannel* channel;
@property (nonatomic, strong) TSCBLEManager *bleManager;
@property (nonatomic, strong) NSMutableArray *peripherals;
@property (nonatomic, strong) NSMutableArray *rssiList;
@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, assign) BOOL isReconnecting;
@property (nonatomic, strong) NSTimer *connectionWatchdogTimer;
@property (nonatomic, strong) NSMutableArray *printQueue;
@property (nonatomic, assign) BOOL isPrinting;
@property (nonatomic, strong) dispatch_queue_t printQueueDispatchQueue;
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
        self.isInitialized = NO;
        self.isReconnecting = NO;
    }
    return self;
}

- (void)initializePlugin:(FlutterResult)result {
    @try {
        // Initialize properties
        self.peripherals = [NSMutableArray array];
        self.rssiList = [NSMutableArray array];
        self.bleManager = [TSCBLEManager sharedInstance];
        self.bleManager.delegate = self;
        
        // Initialize print queue
        self.printQueue = [NSMutableArray array];
        self.isPrinting = NO;
        self.printQueueDispatchQueue = dispatch_queue_create("com.xprinter.printqueue", DISPATCH_QUEUE_SERIAL);
        
        // Mark as initialized
        self.isInitialized = YES;
        
        // Return success
        result(@YES);
    } @catch (NSException *exception) {
        // Handle any errors during initialization
        self.isInitialized = NO;
        result([FlutterError errorWithCode:@"INIT_FAILED"
                                  message:[NSString stringWithFormat:@"Initialization failed: %@", exception.reason]
                                  details:nil]);
    }
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    // Check if initialized except for initialize method
    if (!self.isInitialized && ![@"initialize" isEqualToString:call.method]) {
        result([FlutterError errorWithCode:@"NOT_INITIALIZED"
                                   message:@"Plugin not initialized. Call initialize() first."
                                   details:nil]);
        return;
    }
    
    if ([@"initialize" isEqualToString:call.method]) {
        [self initializePlugin:result];
    } else if ([@"scanDevices" isEqualToString:call.method]) {
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
    } else if ([@"printPDF" isEqualToString:call.method]) {
        [self printPDF:call.arguments result:result];
    } else if ([@"resetBLEManager" isEqualToString:call.method]) {
        [self resetBLEManager:result];
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

- (void)resetBLEManager:(FlutterResult)result {
    // Cancel any pending operations
    [self cancelConnectionWatchdogTimer];
    
    // Disconnect if connected
    if (self.bleManager.isConnecting) {
        [self.bleManager disconnectRootPeripheral];
    }
    
    // Wait a bit before recreating the manager
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Create new instance
        self.bleManager = [TSCBLEManager sharedInstance];
        self.bleManager.delegate = self;
        self.isReconnecting = NO;
        self.isPrinting = NO;
        [self.printQueue removeAllObjects];
        
        result(@YES);
    });
}

- (void)connectDevice:(id)arguments result:(FlutterResult)result {
    NSDictionary *args = arguments;
    NSInteger index = [args[@"index"] integerValue];
    
    // Validate index
    if (index < 0 || index >= [self.peripherals count]) {
        result([FlutterError errorWithCode:@"INVALID_INDEX"
                                   message:@"Invalid device index"
                                   details:nil]);
        return;
    }
    
    // Keep a reference to the result callback
    FlutterResult connectionResult = [result copy];
    
    // Set reconnecting flag
    self.isReconnecting = self.bleManager.isConnecting;
    
    // If already connected, disconnect first and then reconnect
    if (self.bleManager.isConnecting) {
        NSLog(@"Already connected, will disconnect and reconnect");
        
        // Create a connection watchdog timer
        [self cancelConnectionWatchdogTimer];
        self.connectionWatchdogTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                                       target:self
                                                                     selector:@selector(handleConnectionTimeout:)
                                                                     userInfo:nil
                                                                      repeats:NO];
        
        // Perform disconnect
        [self.bleManager disconnectRootPeripheral];
        
        // Wait for disconnection callback before connecting again
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self cancelConnectionWatchdogTimer];
            
            // Reset BLE manager if needed
            if (self.isReconnecting) {
                NSLog(@"Forcing BLE manager reset");
                self.bleManager = [TSCBLEManager sharedInstance];
                self.bleManager.delegate = self;
                self.isReconnecting = NO;
            }
            
            // Connect to new device
            CBPeripheral *peripheral = self.peripherals[index];
            [self.bleManager connectDevice:peripheral];
            connectionResult(@YES);
        });
    } else {
        // Direct connection if not already connected
        CBPeripheral *peripheral = self.peripherals[index];
        [self.bleManager connectDevice:peripheral];
        connectionResult(@YES);
    }
}

- (void)handleConnectionTimeout:(NSTimer *)timer {
    NSLog(@"Connection timeout - forcing reset");
    
    // Force BLE manager reset
    self.bleManager = [TSCBLEManager sharedInstance];
    self.bleManager.delegate = self;
    self.isReconnecting = NO;
    
    // Notify Flutter about the timeout
    NSDictionary *deviceInfo = @{
        @"name": @"Unknown",
        @"address": @"Unknown",
        @"status": @"timeout",
        @"error": @"Connection timeout occurred"
    };
    
    [self.channel invokeMethod:@"onConnectionChanged" arguments:deviceInfo];
}

- (void)cancelConnectionWatchdogTimer {
    if (self.connectionWatchdogTimer) {
        [self.connectionWatchdogTimer invalidate];
        self.connectionWatchdogTimer = nil;
    }
}

- (void)disconnectDevice:(FlutterResult)result {
    [self cancelConnectionWatchdogTimer];
    
    // Clear print queue on disconnect
    dispatch_async(self.printQueueDispatchQueue, ^{
        [self.printQueue removeAllObjects];
        self.isPrinting = NO;
    });
    
    // Perform disconnect
    [self.bleManager disconnectRootPeripheral];
    
    // Reset state
    self.isReconnecting = NO;
    
    // Additional cleanup - may need to be adjusted based on TSCBLEManager implementation
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        result(@YES);
    });
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
        NSLog(@"Failed to create UIImage from data of length: %lu", (unsigned long)data.length);
        result([FlutterError errorWithCode:@"INVALID_IMAGE"
                                  message:@"Invalid image data"
                                  details:nil]);
        return;
    }
    
    NSMutableData *dataM = [[NSMutableData alloc] init];
    
    // Get command type from arguments (default to TSC/0 if not provided)
    NSNumber *commandTypeNum = args[@"commandType"];
    int commandType = commandTypeNum ? [commandTypeNum intValue] : 0;
    
    // Get printer parameters
    NSNumber *printerWidthNum = args[@"printerWidth"];
    NSNumber *printerHeightNum = args[@"printerHeight"];
    int printerWidth = printerWidthNum ? [printerWidthNum intValue] : 384; // Default printer width in dots
    int printerHeight = printerHeightNum ? [printerHeightNum intValue] : 600; // Default printer height in dots
    
    // Get rotation angle from arguments (default to 0 if not provided)
    NSNumber *rotationAngleNum = args[@"rotation"];
    int rotationAngle = rotationAngleNum ? [rotationAngleNum intValue] : 0;
    
    // Get scale (default to 0.9 if not provided)
    NSNumber *scaleNum = args[@"scale"];
    CGFloat scale = scaleNum ? [scaleNum floatValue] : 0.9; // Default 90% of printer width
    
    // Calculate target size based on printer width and scale
    CGFloat imageRatio = image.size.width / image.size.height;
    CGSize targetSize = CGSizeMake(printerWidth * scale, printerWidth * scale / imageRatio);
    
    // If height exceeds printer height, scale down based on height
    if (targetSize.height > printerHeight * scale) {
        targetSize = CGSizeMake(printerHeight * scale * imageRatio, printerHeight * scale);
    }
    
    // Resize image to fit printer
    UIGraphicsBeginImageContextWithOptions(targetSize, NO, 1.0);
    [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    if (resizedImage) {
        image = resizedImage;
    }
    
    // Apply rotation if needed
    if (rotationAngle != 0) {
        // Convert degrees to radians
        CGFloat radians = rotationAngle * M_PI / 180.0;
        
        // Calculate the size of the rotated image
        CGRect rotatedRect = CGRectApplyAffineTransform(
            CGRectMake(0, 0, image.size.width, image.size.height),
            CGAffineTransformMakeRotation(radians));
        
        CGSize rotatedSize = rotatedRect.size;
        
        // Create a new context with the rotated size
        UIGraphicsBeginImageContextWithOptions(rotatedSize, NO, image.scale);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        // Move to center and rotate
        CGContextTranslateCTM(context, rotatedSize.width/2, rotatedSize.height/2);
        CGContextRotateCTM(context, radians);
        
        // Draw the original image centered
        [image drawInRect:CGRectMake(-image.size.width/2, -image.size.height/2, 
                                    image.size.width, image.size.height)];
        
        // Get the rotated image
        UIImage *rotatedImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        if (rotatedImage) {
            image = rotatedImage;
        }
    }
    
    // Calculate centered position
    int xPos = (printerWidth - image.size.width) / 2;
    int yPos = (printerHeight - image.size.height) / 2;
    
    // Convert to mm for TSC
    int xPosMM = xPos / 8;
    int yPosMM = yPos / 8;
    
    switch (commandType) {
        // TSPL
        case 0:
        {
            int mmWidth = printerWidth / 8; // Approximate conversion from dots to mm
            int mmHeight = printerHeight / 8;
            
            [dataM appendData:[TSCCommand sizeBymmWithWidth:mmWidth andHeight:mmHeight]];
            [dataM appendData:[TSCCommand gapBymmWithWidth:0 andHeight:0]];
            [dataM appendData:[TSCCommand cls]];
            
            [dataM appendData:[TSCCommand bitmapWithX:xPosMM andY:yPosMM andMode:0 andImage:image]];
            [dataM appendData:[TSCCommand print:1]];
        }
            break;
            
        // ZPL
        case 1:
        {
            [dataM appendData:[ZPLCommand XA]];
            [dataM appendData:[ZPLCommand setLabelWidth:printerWidth]];
            
            [dataM appendData:[ZPLCommand drawImageWithx:xPos y:yPos image:image]];
            [dataM appendData:[ZPLCommand XZ]];
        }
            break;
            
        // CPCL
        case 2:
        {
            [dataM appendData:[CPCLCommand initLabelWithHeight:printerHeight count:1 offsetx:0]];
            
            [dataM appendData:[CPCLCommand drawImageWithx:xPos y:yPos image:image]];
            [dataM appendData:[CPCLCommand form]];
            [dataM appendData:[CPCLCommand print]];
        }
            break;
            
        default:
            break;
    }
    
    [self sendDataToPrinter:dataM result:result];
}

- (void)printPDF:(id)arguments result:(FlutterResult)result {
    if (!self.bleManager.isConnecting) {
        result([FlutterError errorWithCode:@"NOT_CONNECTED"
                                  message:@"Printer not connected"
                                  details:nil]);
        return;
    }
    
    NSDictionary *args = arguments;
    NSString *pdfPath = args[@"pdfPath"];
    
    if (!pdfPath || [pdfPath length] == 0) {
        result([FlutterError errorWithCode:@"INVALID_ARGUMENTS"
                                  message:@"PDF path is required"
                                  details:nil]);
        return;
    }
    
    // Verify file exists
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:pdfPath];
    NSLog(@"PDF path: %@, File exists: %@", pdfPath, fileExists ? @"YES" : @"NO");
    
    if (!fileExists) {
        result([FlutterError errorWithCode:@"FILE_NOT_FOUND"
                                  message:@"PDF file not found at provided path"
                                  details:nil]);
        return;
    }
    
    // Get total page count first
    int totalPages = [LabelDocument getPDFPages:pdfPath pdfPassword:nil];
    NSLog(@"PDF total pages: %d", totalPages);
    
    if (totalPages <= 0) {
        result([FlutterError errorWithCode:@"PDF_INVALID"
                                  message:@"Could not determine PDF page count or PDF is invalid"
                                  details:nil]);
        return;
    }
    
    // Get command type from arguments (default to TSC/0 if not provided)
    NSNumber *commandTypeNum = args[@"commandType"];
    int commandType = commandTypeNum ? [commandTypeNum intValue] : 0;
    
    // Get printer parameters
    NSNumber *printerWidthNum = args[@"printerWidth"];
    NSNumber *printerHeightNum = args[@"printerHeight"];
    int printerWidth = printerWidthNum ? [printerWidthNum intValue] : 384; // Default printer width in dots
    int printerHeight = printerHeightNum ? [printerHeightNum intValue] : 600; // Default printer height in dots
    
    // Get rotation angle from arguments (default to 0 if not provided)
    NSNumber *rotationAngleNum = args[@"rotation"];
    int rotationAngle = rotationAngleNum ? [rotationAngleNum intValue] : 0;
    
    // Get scale (default to 0.9 if not provided)
    NSNumber *scaleNum = args[@"scale"];
    CGFloat scale = scaleNum ? [scaleNum floatValue] : 0.9; // Default 90% of printer width
    
    // Get specific page to print (if specified)
    NSNumber *startPageNum = args[@"startPage"];
    NSNumber *endPageNum = args[@"endPage"];
    int startPage = startPageNum ? [startPageNum intValue] : 1; // Default to first page
    int endPage = endPageNum ? [endPageNum intValue] : totalPages; // Default to all pages
    
    // Validate page numbers
    if (startPage < 1) startPage = 1;
    if (startPage > totalPages) startPage = totalPages;
    if (endPage > totalPages) endPage = totalPages;
    if (endPage < startPage) endPage = startPage;
    
    // Password for protected PDFs (if provided)
    NSString *password = args[@"password"];
    
    // Log the parsing attempt
    NSLog(@"Attempting to parse PDF: %@, pages %d to %d of %d total pages", 
          pdfPath, startPage, endPage, totalPages);
    
    // Create a copy of the result to use in the callback
    FlutterResult pdfResult = [result copy];
    
    // Parse PDF using LabelDocument
    [LabelDocument parsingDoc:pdfPath start:startPage end:endPage password:password DataCallBack:^(NSMutableArray<UIImage *> *sourceImages, DocErrorCode errorCode) {
        NSLog(@"PDF parsing complete with error code: %ld, images count: %lu", 
              (long)errorCode, (unsigned long)sourceImages.count);
        
        if (errorCode != DocSuccess) {
            NSString *errorMessage;
            switch (errorCode) {
                case CGPDFDocumentRefNULL:
                    errorMessage = @"Failed to create PDF document reference";
                    break;
                case PageNumberExceeds:
                    errorMessage = @"Requested page number exceeds document length";
                    break;
                default:
                    errorMessage = @"Unknown error parsing PDF";
                    break;
            }
            
            NSLog(@"PDF parsing error: %@", errorMessage);
            pdfResult([FlutterError errorWithCode:@"PDF_PARSING_ERROR"
                                      message:errorMessage
                                      details:nil]);
            return;
        }
        
        if ([sourceImages count] == 0) {
            pdfResult([FlutterError errorWithCode:@"PDF_EMPTY"
                                      message:@"No pages in PDF or no pages in selected range"
                                      details:nil]);
            return;
        }
        
        // Process each page as individual print jobs to queue
        dispatch_group_t group = dispatch_group_create();
        __block BOOL printSuccess = YES;
        __block NSString *errorMessage = nil;
        
        for (UIImage *pageImage in sourceImages) {
            dispatch_group_enter(group);
            
            NSMutableData *dataM = [[NSMutableData alloc] init];
            
            // Resize image to fit printer
            UIImage *image = pageImage;
            NSLog(@"Original image size: %.0f x %.0f", image.size.width, image.size.height);
            
            CGFloat imageRatio = image.size.width / image.size.height;
            CGSize targetSize = CGSizeMake(printerWidth * scale, printerWidth * scale / imageRatio);
            
            // If height exceeds printer height, scale down based on height
            if (targetSize.height > printerHeight * scale) {
                targetSize = CGSizeMake(printerHeight * scale * imageRatio, printerHeight * scale);
            }
            
            NSLog(@"Target image size: %.0f x %.0f", targetSize.width, targetSize.height);
            
            // Resize image to fit printer
            UIGraphicsBeginImageContextWithOptions(targetSize, NO, 1.0);
            [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
            UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            if (resizedImage) {
                image = resizedImage;
                NSLog(@"Resized image size: %.0f x %.0f", image.size.width, image.size.height);
            }
            
            // Apply rotation if needed
            if (rotationAngle != 0) {
                // Convert degrees to radians
                CGFloat radians = rotationAngle * M_PI / 180.0;
                
                // Calculate the size of the rotated image
                CGRect rotatedRect = CGRectApplyAffineTransform(
                    CGRectMake(0, 0, image.size.width, image.size.height),
                    CGAffineTransformMakeRotation(radians));
                
                CGSize rotatedSize = rotatedRect.size;
                
                // Create a new context with the rotated size
                UIGraphicsBeginImageContextWithOptions(rotatedSize, NO, image.scale);
                CGContextRef context = UIGraphicsGetCurrentContext();
                
                // Move to center and rotate
                CGContextTranslateCTM(context, rotatedSize.width/2, rotatedSize.height/2);
                CGContextRotateCTM(context, radians);
                
                // Draw the original image centered
                [image drawInRect:CGRectMake(-image.size.width/2, -image.size.height/2, 
                                            image.size.width, image.size.height)];
                
                // Get the rotated image
                UIImage *rotatedImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                
                if (rotatedImage) {
                    image = rotatedImage;
                    NSLog(@"Rotated image size: %.0f x %.0f", image.size.width, image.size.height);
                }
            }
            
            // Calculate centered position
            int xPos = (printerWidth - image.size.width) / 2;
            int yPos = (printerHeight - image.size.height) / 2;
            
            // Convert to mm for TSC
            int xPosMM = xPos / 8;
            int yPosMM = yPos / 8;
            
            NSLog(@"Printing with command type: %d, position: %d,%d", commandType, xPos, yPos);
            
            switch (commandType) {
                // TSPL
                case 0:
                {
                    int mmWidth = printerWidth / 8; // Approximate conversion from dots to mm
                    int mmHeight = printerHeight / 8;
                    
                    [dataM appendData:[TSCCommand sizeBymmWithWidth:mmWidth andHeight:mmHeight]];
                    [dataM appendData:[TSCCommand gapBymmWithWidth:0 andHeight:0]];
                    [dataM appendData:[TSCCommand cls]];
                    
                    [dataM appendData:[TSCCommand bitmapWithX:xPosMM andY:yPosMM andMode:0 andImage:image]];
                    [dataM appendData:[TSCCommand print:1]];
                }
                    break;
                    
                // ZPL
                case 1:
                {
                    [dataM appendData:[ZPLCommand XA]];
                    [dataM appendData:[ZPLCommand setLabelWidth:printerWidth]];
                    
                    [dataM appendData:[ZPLCommand drawImageWithx:xPos y:yPos image:image]];
                    [dataM appendData:[ZPLCommand XZ]];
                }
                    break;
                    
                // CPCL
                case 2:
                {
                    [dataM appendData:[CPCLCommand initLabelWithHeight:printerHeight count:1 offsetx:0]];
                    
                    [dataM appendData:[CPCLCommand drawImageWithx:xPos y:yPos image:image]];
                    [dataM appendData:[CPCLCommand form]];
                    [dataM appendData:[CPCLCommand print]];
                }
                    break;
                    
                default:
                    break;
            }
            
            // Use our queuing system instead of direct sending
            FlutterResult pageResult = ^(id result) {
                if ([result isKindOfClass:[FlutterError class]]) {
                    printSuccess = NO;
                    errorMessage = [(FlutterError *)result message];
                    NSLog(@"Print error: %@", errorMessage);
                } else {
                    NSLog(@"Page printed successfully");
                }
                dispatch_group_leave(group);
            };
            
            // Add to print queue
            [self sendDataToPrinter:dataM result:pageResult];
        }
        
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            if (printSuccess) {
                NSLog(@"All pages added to print queue successfully");
                pdfResult(@YES);
            } else {
                NSLog(@"Print failed: %@", errorMessage ?: @"Unknown error");
                pdfResult([FlutterError errorWithCode:@"PRINT_ERROR"
                                          message:errorMessage ?: @"Error printing PDF"
                                          details:nil]);
            }
        });
    }];
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
    // Create a job dictionary with the data and result callback
    NSDictionary *printJob = @{
        @"data": data,
        @"result": result
    };
    
    // Add to queue and process
    dispatch_async(self.printQueueDispatchQueue, ^{
        [self.printQueue addObject:printJob];
        [self processNextPrintJobIfNeeded];
    });
}

- (void)processNextPrintJobIfNeeded {
    // Only run on our serial queue
    if (![NSThread isMainThread] && dispatch_get_current_queue() != self.printQueueDispatchQueue) {
        dispatch_async(self.printQueueDispatchQueue, ^{
            [self processNextPrintJobIfNeeded];
        });
        return;
    }
    
    // If we're already printing or queue is empty, do nothing
    if (self.isPrinting || [self.printQueue count] == 0) {
        return;
    }
    
    // Mark as printing and get next job
    self.isPrinting = YES;
    NSDictionary *nextJob = [self.printQueue firstObject];
    NSMutableData *data = nextJob[@"data"];
    FlutterResult result = nextJob[@"result"];
    
    // Send to printer
    __weak typeof(self) weakSelf = self;
    [self.bleManager writeCommandWithData:data writeCallBack:^(CBCharacteristic *characteristic, NSError *error) {
        // Handle result
        if (error) {
            result([FlutterError errorWithCode:@"PRINT_ERROR"
                                     message:error.localizedDescription
                                     details:nil]);
        } else {
            result(@YES);
        }
        
        // Move to next job
        dispatch_async(weakSelf.printQueueDispatchQueue, ^{
            // Remove the job we just processed
            if ([weakSelf.printQueue count] > 0) {
                [weakSelf.printQueue removeObjectAtIndex:0];
            }
            
            // Clear printing flag
            weakSelf.isPrinting = NO;
            
            // Add a small delay between print jobs
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), weakSelf.printQueueDispatchQueue, ^{
                [weakSelf processNextPrintJobIfNeeded];
            });
        });
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
    // Cancel any pending timers
    [self cancelConnectionWatchdogTimer];
    
    NSDictionary *deviceInfo = @{
        @"name": peripheral.name ?: @"Unknown",
        @"address": peripheral.identifier.UUIDString,
        @"status": @"connected"
    };
    
    [self.channel invokeMethod:@"onConnectionChanged" arguments:deviceInfo];
}

- (void)TSCbleDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    // Cancel any pending timers
    [self cancelConnectionWatchdogTimer];
    
    // Only reset manager if not in the middle of a reconnection
    if (!self.isReconnecting) {
        // Additional cleanup if needed
        dispatch_async(self.printQueueDispatchQueue, ^{
            [self.printQueue removeAllObjects];
            self.isPrinting = NO;
        });
    }
    
    NSDictionary *deviceInfo = @{
        @"name": peripheral.name ?: @"Unknown",
        @"address": peripheral.identifier.UUIDString,
        @"status": @"disconnected",
        @"error": error ? error.localizedDescription : @""
    };
    
    [self.channel invokeMethod:@"onConnectionChanged" arguments:deviceInfo];
}

- (void)TSCbleFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    // Cancel any pending timers
    [self cancelConnectionWatchdogTimer];
    
    // Force reset of manager on connection failure
    if (!self.isReconnecting) {
        self.bleManager = [TSCBLEManager sharedInstance];
        self.bleManager.delegate = self;
        dispatch_async(self.printQueueDispatchQueue, ^{
            [self.printQueue removeAllObjects];
            self.isPrinting = NO;
        });
    }
    
    self.isReconnecting = NO;
    
    NSDictionary *deviceInfo = @{
        @"name": peripheral.name ?: @"Unknown",
        @"address": peripheral.identifier.UUIDString,
        @"status": @"failed",
        @"error": error ? error.localizedDescription : @"Failed to connect"
    };
    
    [self.channel invokeMethod:@"onConnectionChanged" arguments:deviceInfo];
}

@end

// //
// //  XPrinterPckPlugin.m
// //  Flutter POS Printer Plugin
// //

// #import "XPrinterPckPlugin.h"


// // #import "PrinterSDK/Headers/POSBLEManager.h"
// // #import "PrinterSDK/Headers/POSCommand.h"
// #import "TSCPrinterSDK.h"
// #import "TSCBLEManager.h"
// #import "LabelDocument.h"

// @implementation XPrinterPckPlugin

// + (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
//     FlutterMethodChannel* channel = [FlutterMethodChannel
//                                      methodChannelWithName:@"x_printer_eq"
//                                      binaryMessenger:[registrar messenger]];
//     XPrinterPckPlugin* instance = [[XPrinterPckPlugin alloc] init];
//     instance.channel = channel;
//     [registrar addMethodCallDelegate:instance channel:channel];
// }

// - (instancetype)init {
//     self = [super init];
//     // if (self) {
//     //     self.peripherals = [NSMutableArray array];
//     //     self.rssiList = [NSMutableArray array];
//     //     self.bleManager = [TSCBLEManager sharedInstance];
//     //     self.bleManager.delegate = self;
//     // }
//     return self;
// }


// - (void)initializePlugin:(FlutterResult)result {
//     @try {
//         // Initialize properties
//         self.peripherals = [NSMutableArray array];
//         self.rssiList = [NSMutableArray array];
//         self.bleManager = [TSCBLEManager sharedInstance];
//         self.bleManager.delegate = self;
//         self.isPrinting = NO;
//         self.commandQueue = [NSMutableArray array];
//         // Mark as initialized
//         self.isInitialized = YES;

        
//         // Return success
//         result(@YES);
//     } @catch (NSException *exception) {
//         // Handle any errors during initialization
//         self.isInitialized = NO;
//         result([FlutterError errorWithCode:@"INIT_FAILED"
//                                   message:[NSString stringWithFormat:@"Initialization failed: %@", exception.reason]
//                                   details:nil]);
//     }
// }

// - (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
//      if ([@"initialize" isEqualToString:call.method]) {
//         [self initializePlugin:result];
//     } else if ([@"scanDevices" isEqualToString:call.method]) {
//         [self startScanDevices:result];
//     } else if ([@"stopScan" isEqualToString:call.method]) {
//         [self stopScan:result];
//     } else if ([@"connectDevice" isEqualToString:call.method]) {
//         [self connectDevice:call.arguments result:result];
//     } else if ([@"disconnectDevice" isEqualToString:call.method]) {
//         [self disconnectDevice:result];
//     } else if ([@"printText" isEqualToString:call.method]) {
//         [self printText:call.arguments result:result];
//     } else if ([@"printBarcode" isEqualToString:call.method]) {
//         [self printBarcode:call.arguments result:result];
//     } else if ([@"printQRCode" isEqualToString:call.method]) {
//         [self printQRCode:call.arguments result:result];
//     } else if ([@"printImage" isEqualToString:call.method]) {
//         [self printImage:call.arguments result:result];
//     } else if ([@"getPrinterStatus" isEqualToString:call.method]) {
//         [self getPrinterStatus:result];
//     } 
//      else if ([@"printPDF" isEqualToString:call.method]) {
//         [self printPDF:call.arguments result:result];
//     }
    
//     else {
//         result(FlutterMethodNotImplemented);
//     }
// }

// #pragma mark - Device Methods

// - (void)startScanDevices:(FlutterResult)result {
//     [self.peripherals removeAllObjects];
//     [self.rssiList removeAllObjects];
//     [self.bleManager startScan];
//     result(@YES);
// }

// - (void)stopScan:(FlutterResult)result {
//     [self.bleManager stopScan];
//     result(@YES);
// }
// - (void)connectDevice:(id)arguments result:(FlutterResult)result {
//     NSDictionary *args = arguments;
//     NSInteger index = [args[@"index"] integerValue];
    
//     if (index >= 0 && index < [self.peripherals count]) {
//         // Disconnect any existing connection first
//         [self.bleManager disconnectRootPeripheral];
        
//         // Reset internal state
//         [self.peripherals removeAllObjects];
//         [self.rssiList removeAllObjects];
        
//         CBPeripheral *peripheral = self.peripherals[index];
//         [self.bleManager connectDevice:peripheral];
        
//         // Wait briefly to ensure connection is established
//         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//             if (self.bleManager.isConnecting) {
//                 // Send initialization command to printer
//                 [self initializePrinterWithResult:result];
//             } else {
//                 result([FlutterError errorWithCode:@"CONNECTION_FAILED"
//                                           message:@"Failed to connect to printer"
//                                           details:nil]);
//             }
//         });
//     } else {
//         result([FlutterError errorWithCode:@"INVALID_INDEX"
//                                   message:@"Invalid device index"
//                                   details:nil]);
//     }
// }
// - (void)initializePrinterWithResult:(FlutterResult)result {
//     NSMutableData *dataM = [[NSMutableData alloc] init];
//     // Manually create the ESC @ command
//     const char initCommand[] = {0x1B, 0x40};
//     [dataM appendBytes:initCommand length:sizeof(initCommand)];
//     [self sendDataToPrinter:dataM result:result];
// }
// // - (void)initializePrinterWithResult:(FlutterResult)result {
// //     NSMutableData *dataM = [[NSMutableData alloc] init];
// //     [dataM appendData:[TSCCommand initialize]]; // Assuming TSCCommand has an initialize command
// //     [self sendDataToPrinter:dataM result:result];
// // }
// // - (void)connectDevice:(id)arguments result:(FlutterResult)result {
// //     NSDictionary *args = arguments;
// //     NSInteger index = [args[@"index"] integerValue];
    
// //     if (index >= 0 && index < [self.peripherals count]) {
// //         CBPeripheral *peripheral = self.peripherals[index];
// //         [self.bleManager connectDevice:peripheral];
// //         result(@YES);
// //     } else {
// //         result([FlutterError errorWithCode:@"INVALID_INDEX"
// //                                    message:@"Invalid device index"
// //                                    details:nil]);
// //     }
// // }

// - (void)disconnectDevice:(FlutterResult)result {
//     [self.bleManager disconnectRootPeripheral];
//     result(@YES);
// }

// #pragma mark - Printing Methods

// - (void)printText:(id)arguments result:(FlutterResult)result {
//     if (!self.bleManager.isConnecting) {
//         result([FlutterError errorWithCode:@"NOT_CONNECTED"
//                                    message:@"Printer not connected"
//                                    details:nil]);
//         return;
//     }
    
//     NSDictionary *args = arguments;
//     NSString *text = args[@"text"];
//     NSInteger fontSize = [args[@"fontSize"] integerValue];
    
//     if (!text) {
//         result([FlutterError errorWithCode:@"INVALID_ARGUMENTS"
//                                    message:@"Text is required"
//                                    details:nil]);
//         return;
//     }
    
//     NSMutableData *dataM = [[NSMutableData alloc] init];
//     NSStringEncoding gbkEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    
//     [dataM appendData:[TSCCommand sizeBymmWithWidth:70 andHeight:85]];
//     [dataM appendData:[TSCCommand gapBymmWithWidth:2 andHeight:0]];
//     [dataM appendData:[TSCCommand cls]];
    
//     // Choose font based on fontSize parameter
//     NSString *font = @"2";
//     if (fontSize == 2) {
//         font = @"3";
//     } else if (fontSize == 3) {
//         font = @"4";
//     } else if (fontSize == 4) {
//         font = @"5";
//     }
    
//     [dataM appendData:[TSCCommand textWithX:0 andY:10 andFont:font andRotation:0 andX_mul:1 andY_mul:1 andContent:text usStrEnCoding:gbkEncoding]];
//     [dataM appendData:[TSCCommand print:1]];
    
//     [self sendDataToPrinter:dataM result:result];
// }

// - (void)printBarcode:(id)arguments result:(FlutterResult)result {
//     if (!self.bleManager.isConnecting) {
//         result([FlutterError errorWithCode:@"NOT_CONNECTED"
//                                    message:@"Printer not connected"
//                                    details:nil]);
//         return;
//     }
    
//     NSDictionary *args = arguments;
//     NSString *content = args[@"content"];
//     NSInteger x = [args[@"x"] integerValue];
//     NSInteger y = [args[@"y"] integerValue];
//     NSInteger height = [args[@"height"] integerValue];
//     NSString *barcodeType = args[@"type"] ?: @"128";
    
//     if (!content) {
//         result([FlutterError errorWithCode:@"INVALID_ARGUMENTS"
//                                    message:@"Barcode content is required"
//                                    details:nil]);
//         return;
//     }
    
//     NSMutableData *dataM = [[NSMutableData alloc] init];
    
//     [dataM appendData:[TSCCommand sizeBymmWithWidth:80 andHeight:100]];
//     [dataM appendData:[TSCCommand gapBymmWithWidth:2 andHeight:0]];
//     [dataM appendData:[TSCCommand cls]];
//     [dataM appendData:[TSCCommand barcodeWithX:x andY:y andCodeType:barcodeType andHeight:height andHunabReadable:2 andRotation:0 andNarrow:2 andWide:2 andContent:content usStrEnCoding:NSUTF8StringEncoding]];
//     [dataM appendData:[TSCCommand print:1]];
    
//     [self sendDataToPrinter:dataM result:result];
// }

// - (void)printQRCode:(id)arguments result:(FlutterResult)result {
//     if (!self.bleManager.isConnecting) {
//         result([FlutterError errorWithCode:@"NOT_CONNECTED"
//                                    message:@"Printer not connected"
//                                    details:nil]);
//         return;
//     }
    
//     NSDictionary *args = arguments;
//     NSString *content = args[@"content"];
//     NSInteger x = [args[@"x"] integerValue];
//     NSInteger y = [args[@"y"] integerValue];
//     NSInteger cellWidth = [args[@"cellWidth"] integerValue] ?: 8;
    
//     if (!content) {
//         result([FlutterError errorWithCode:@"INVALID_ARGUMENTS"
//                                    message:@"QR code content is required"
//                                    details:nil]);
//         return;
//     }
    
//     NSMutableData *dataM = [[NSMutableData alloc] init];
    
//     [dataM appendData:[TSCCommand sizeBymmWithWidth:80 andHeight:100]];
//     [dataM appendData:[TSCCommand gapBymmWithWidth:2 andHeight:0]];
//     [dataM appendData:[TSCCommand cls]];
//     [dataM appendData:[TSCCommand qrCodeWithX:x andY:y andEccLevel:@"M" andCellWidth:cellWidth andMode:@"A" andRotation:0 andContent:content usStrEnCoding:NSUTF8StringEncoding]];
//     [dataM appendData:[TSCCommand print:1]];
    
//     [self sendDataToPrinter:dataM result:result];
// } 
 






















// - (void)printImage:(id)arguments result:(FlutterResult)result {
//     if (!self.bleManager.isConnecting) {
//         result([FlutterError errorWithCode:@"NOT_CONNECTED"
//                                   message:@"Printer not connected"
//                                   details:nil]);
//         return;
//     }
    
//     NSDictionary *args = arguments;
//     FlutterStandardTypedData *imageData = args[@"imageData"];
    
//     if (!imageData) {
//         result([FlutterError errorWithCode:@"INVALID_ARGUMENTS"
//                                   message:@"Image data is required"
//                                   details:nil]);
//         return;
//     }
    
//     NSData *data = [imageData data];
//     UIImage *image = [UIImage imageWithData:data];
    
//     if (!image) {
//         NSLog(@"Failed to create UIImage from data of length: %lu", (unsigned long)data.length);
//         result([FlutterError errorWithCode:@"INVALID_IMAGE"
//                                   message:@"Invalid image data"
//                                   details:nil]);
//         return;
//     }
    
//     NSMutableData *dataM = [[NSMutableData alloc] init];
    
//     // Get command type from arguments (default to TSC/0 if not provided)
//     NSNumber *commandTypeNum = args[@"commandType"];
//     int commandType = commandTypeNum ? [commandTypeNum intValue] : 0;
    
//     // Get printer parameters
//     NSNumber *printerWidthNum = args[@"printerWidth"];
//     NSNumber *printerHeightNum = args[@"printerHeight"];
//     int printerWidth = printerWidthNum ? [printerWidthNum intValue] : 384; // Default printer width in dots
//     int printerHeight = printerHeightNum ? [printerHeightNum intValue] : 600; // Default printer height in dots
    
//     // Get rotation angle from arguments (default to 0 if not provided)
//     NSNumber *rotationAngleNum = args[@"rotation"];
//     int rotationAngle = rotationAngleNum ? [rotationAngleNum intValue] : 0;
    
//     // Get scale (default to 0.9 if not provided)
//     NSNumber *scaleNum = args[@"scale"];
//     CGFloat scale = scaleNum ? [scaleNum floatValue] : 0.9; // Default 90% of printer width
    
//     // Calculate target size based on printer width and scale
//     CGFloat imageRatio = image.size.width / image.size.height;
//     CGSize targetSize = CGSizeMake(printerWidth * scale, printerWidth * scale / imageRatio);
    
//     // If height exceeds printer height, scale down based on height
//     if (targetSize.height > printerHeight * scale) {
//         targetSize = CGSizeMake(printerHeight * scale * imageRatio, printerHeight * scale);
//     }
    
//     // Resize image to fit printer
//     UIGraphicsBeginImageContextWithOptions(targetSize, NO, 1.0);
//     [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
//     UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
//     UIGraphicsEndImageContext();
    
//     if (resizedImage) {
//         image = resizedImage;
//     }
    
//     // Apply rotation if needed
//     if (rotationAngle != 0) {
//         // Convert degrees to radians
//         CGFloat radians = rotationAngle * M_PI / 180.0;
        
//         // Calculate the size of the rotated image
//         CGRect rotatedRect = CGRectApplyAffineTransform(
//             CGRectMake(0, 0, image.size.width, image.size.height),
//             CGAffineTransformMakeRotation(radians));
        
//         CGSize rotatedSize = rotatedRect.size;
        
//         // Create a new context with the rotated size
//         UIGraphicsBeginImageContextWithOptions(rotatedSize, NO, image.scale);
//         CGContextRef context = UIGraphicsGetCurrentContext();
        
//         // Move to center and rotate
//         CGContextTranslateCTM(context, rotatedSize.width/2, rotatedSize.height/2);
//         CGContextRotateCTM(context, radians);
        
//         // Draw the original image centered
//         [image drawInRect:CGRectMake(-image.size.width/2, -image.size.height/2, 
//                                     image.size.width, image.size.height)];
        
//         // Get the rotated image
//         UIImage *rotatedImage = UIGraphicsGetImageFromCurrentImageContext();
//         UIGraphicsEndImageContext();
        
//         if (rotatedImage) {
//             image = rotatedImage;
//         }
//     }
    
//     // Calculate centered position
//     int xPos = (printerWidth - image.size.width) / 2;
//     int yPos = (printerHeight - image.size.height) / 2;
    
//     // Convert to mm for TSC
//     int xPosMM = xPos / 8;
//     int yPosMM = yPos / 8;
    
//     switch (commandType) {
//         // TSPL
//         case 0:
//         {
//             int mmWidth = printerWidth / 8; // Approximate conversion from dots to mm
//             int mmHeight = printerHeight / 8;
            
//             [dataM appendData:[TSCCommand sizeBymmWithWidth:mmWidth andHeight:mmHeight]];
//             [dataM appendData:[TSCCommand gapBymmWithWidth:0 andHeight:0]];
//             [dataM appendData:[TSCCommand cls]];
            
//             [dataM appendData:[TSCCommand bitmapWithX:xPosMM andY:yPosMM andMode:0 andImage:image]];
//             [dataM appendData:[TSCCommand print:1]];
//         }
//             break;
            
//         // ZPL
//         case 1:
//         {
//             [dataM appendData:[ZPLCommand XA]];
//             [dataM appendData:[ZPLCommand setLabelWidth:printerWidth]];
            
//             [dataM appendData:[ZPLCommand drawImageWithx:xPos y:yPos image:image]];
//             [dataM appendData:[ZPLCommand XZ]];
//         }
//             break;
            
//         // CPCL
//         case 2:
//         {
//             [dataM appendData:[CPCLCommand initLabelWithHeight:printerHeight count:1 offsetx:0]];
            
//             [dataM appendData:[CPCLCommand drawImageWithx:xPos y:yPos image:image]];
//             [dataM appendData:[CPCLCommand form]];
//             [dataM appendData:[CPCLCommand print]];
//         }
//             break;
            
//         default:
//             break;
//     }
    
//     [self sendDataToPrinter:dataM result:result];
// }














// - (void)printPDF:(id)arguments result:(FlutterResult)result {
//     if (!self.bleManager.isConnecting) {
//         result([FlutterError errorWithCode:@"NOT_CONNECTED"
//                                   message:@"Printer not connected"
//                                   details:nil]);
//         return;
//     }
    
//     NSDictionary *args = arguments;
//     NSString *pdfPath = args[@"pdfPath"];
    
//     if (!pdfPath || [pdfPath length] == 0) {
//         result([FlutterError errorWithCode:@"INVALID_ARGUMENTS"
//                                   message:@"PDF path is required"
//                                   details:nil]);
//         return;
//     }
    
//     // Verify file exists
//     BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:pdfPath];
//     NSLog(@"PDF path: %@, File exists: %@", pdfPath, fileExists ? @"YES" : @"NO");
    
//     if (!fileExists) {
//         result([FlutterError errorWithCode:@"FILE_NOT_FOUND"
//                                   message:@"PDF file not found at provided path"
//                                   details:nil]);
//         return;
//     }
    
//     // Get total page count first
//     int totalPages = [LabelDocument getPDFPages:pdfPath pdfPassword:nil];
//     NSLog(@"PDF total pages: %d", totalPages);
    
//     if (totalPages <= 0) {
//         result([FlutterError errorWithCode:@"PDF_INVALID"
//                                   message:@"Could not determine PDF page count or PDF is invalid"
//                                   details:nil]);
//         return;
//     }
    
//     // Get command type from arguments (default to TSC/0 if not provided)
//     NSNumber *commandTypeNum = args[@"commandType"];
//     int commandType = commandTypeNum ? [commandTypeNum intValue] : 0;
    
//     // Get printer parameters
//     NSNumber *printerWidthNum = args[@"printerWidth"];
//     NSNumber *printerHeightNum = args[@"printerHeight"];
//     int printerWidth = printerWidthNum ? [printerWidthNum intValue] : 384; // Default printer width in dots
//     int printerHeight = printerHeightNum ? [printerHeightNum intValue] : 600; // Default printer height in dots
    
//     // Get rotation angle from arguments (default to 0 if not provided)
//     NSNumber *rotationAngleNum = args[@"rotation"];
//     int rotationAngle = rotationAngleNum ? [rotationAngleNum intValue] : 0;
    
//     // Get scale (default to 0.9 if not provided)
//     NSNumber *scaleNum = args[@"scale"];
//     CGFloat scale = scaleNum ? [scaleNum floatValue] : 0.9; // Default 90% of printer width
    
//     // Get specific page to print (if specified)
//     NSNumber *startPageNum = args[@"startPage"];
//     NSNumber *endPageNum = args[@"endPage"];
//     int startPage = startPageNum ? [startPageNum intValue] : 1; // Default to first page
//     int endPage = endPageNum ? [endPageNum intValue] : totalPages; // Default to all pages
    
//     // Validate page numbers
//     if (startPage < 1) startPage = 1;
//     if (startPage > totalPages) startPage = totalPages;
//     if (endPage > totalPages) endPage = totalPages;
//     if (endPage < startPage) endPage = startPage;
    
//     // Password for protected PDFs (if provided)
//     NSString *password = args[@"password"];
    
//     // Log the parsing attempt
//     NSLog(@"Attempting to parse PDF: %@, pages %d to %d of %d total pages", 
//           pdfPath, startPage, endPage, totalPages);
    
//     // Parse PDF using LabelDocument
//     [LabelDocument parsingDoc:pdfPath start:startPage end:endPage password:password DataCallBack:^(NSMutableArray<UIImage *> *sourceImages, DocErrorCode errorCode) {
//         NSLog(@"PDF parsing complete with error code: %ld, images count: %lu", 
//               (long)errorCode, (unsigned long)sourceImages.count);
        
//         if (errorCode != DocSuccess) {
//             NSString *errorMessage;
//             switch (errorCode) {
//                 case CGPDFDocumentRefNULL:
//                     errorMessage = @"Failed to create PDF document reference";
//                     break;
//                 case PageNumberExceeds:
//                     errorMessage = @"Requested page number exceeds document length";
//                     break;
//                 default:
//                     errorMessage = @"Unknown error parsing PDF";
//                     break;
//             }
            
//             NSLog(@"PDF parsing error: %@", errorMessage);
//             result([FlutterError errorWithCode:@"PDF_PARSING_ERROR"
//                                       message:errorMessage
//                                       details:nil]);
//             return;
//         }
        
//         if ([sourceImages count] == 0) {
//             result([FlutterError errorWithCode:@"PDF_EMPTY"
//                                       message:@"No pages in PDF or no pages in selected range"
//                                       details:nil]);
//             return;
//         }
        
//         // Process each page
//         dispatch_group_t group = dispatch_group_create();
//         __block BOOL printSuccess = YES;
//         __block NSString *errorMessage = nil;
        
//         for (UIImage *pageImage in sourceImages) {
//             dispatch_group_enter(group);
            
//             NSMutableData *dataM = [[NSMutableData alloc] init];
            
//             // Resize image to fit printer
//             UIImage *image = pageImage;
//             NSLog(@"Original image size: %.0f x %.0f", image.size.width, image.size.height);
            
//             CGFloat imageRatio = image.size.width / image.size.height;
//             CGSize targetSize = CGSizeMake(printerWidth * scale, printerWidth * scale / imageRatio);
            
//             // If height exceeds printer height, scale down based on height
//             if (targetSize.height > printerHeight * scale) {
//                 targetSize = CGSizeMake(printerHeight * scale * imageRatio, printerHeight * scale);
//             }
            
//             NSLog(@"Target image size: %.0f x %.0f", targetSize.width, targetSize.height);
            
//             // Resize image to fit printer
//             UIGraphicsBeginImageContextWithOptions(targetSize, NO, 1.0);
//             [image drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
//             UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
//             UIGraphicsEndImageContext();
            
//             if (resizedImage) {
//                 image = resizedImage;
//                 NSLog(@"Resized image size: %.0f x %.0f", image.size.width, image.size.height);
//             }
            
//             // Apply rotation if needed
//             if (rotationAngle != 0) {
//                 // Convert degrees to radians
//                 CGFloat radians = rotationAngle * M_PI / 180.0;
                
//                 // Calculate the size of the rotated image
//                 CGRect rotatedRect = CGRectApplyAffineTransform(
//                     CGRectMake(0, 0, image.size.width, image.size.height),
//                     CGAffineTransformMakeRotation(radians));
                
//                 CGSize rotatedSize = rotatedRect.size;
                
//                 // Create a new context with the rotated size
//                 UIGraphicsBeginImageContextWithOptions(rotatedSize, NO, image.scale);
//                 CGContextRef context = UIGraphicsGetCurrentContext();
                
//                 // Move to center and rotate
//                 CGContextTranslateCTM(context, rotatedSize.width/2, rotatedSize.height/2);
//                 CGContextRotateCTM(context, radians);
                
//                 // Draw the original image centered
//                 [image drawInRect:CGRectMake(-image.size.width/2, -image.size.height/2, 
//                                             image.size.width, image.size.height)];
                
//                 // Get the rotated image
//                 UIImage *rotatedImage = UIGraphicsGetImageFromCurrentImageContext();
//                 UIGraphicsEndImageContext();
                
//                 if (rotatedImage) {
//                     image = rotatedImage;
//                     NSLog(@"Rotated image size: %.0f x %.0f", image.size.width, image.size.height);
//                 }
//             }
            
//             // Calculate centered position
//             int xPos = (printerWidth - image.size.width) / 2;
//             int yPos = (printerHeight - image.size.height) / 2;
            
//             // Convert to mm for TSC
//             int xPosMM = xPos / 8;
//             int yPosMM = yPos / 8;
            
//             NSLog(@"Printing with command type: %d, position: %d,%d", commandType, xPos, yPos);
            
//             switch (commandType) {
//                 // TSPL
//                 case 0:
//                 {
//                     int mmWidth = printerWidth / 8; // Approximate conversion from dots to mm
//                     int mmHeight = printerHeight / 8;
                    
//                     [dataM appendData:[TSCCommand sizeBymmWithWidth:mmWidth andHeight:mmHeight]];
//                     [dataM appendData:[TSCCommand gapBymmWithWidth:0 andHeight:0]];
//                     [dataM appendData:[TSCCommand cls]];
                    
//                     [dataM appendData:[TSCCommand bitmapWithX:xPosMM andY:yPosMM andMode:0 andImage:image]];
//                     [dataM appendData:[TSCCommand print:1]];
//                 }
//                     break;
                    
//                 // ZPL
//                 case 1:
//                 {
//                     [dataM appendData:[ZPLCommand XA]];
//                     [dataM appendData:[ZPLCommand setLabelWidth:printerWidth]];
                    
//                     [dataM appendData:[ZPLCommand drawImageWithx:xPos y:yPos image:image]];
//                     [dataM appendData:[ZPLCommand XZ]];
//                 }
//                     break;
                    
//                 // CPCL
//                 case 2:
//                 {
//                     [dataM appendData:[CPCLCommand initLabelWithHeight:printerHeight count:1 offsetx:0]];
                    
//                     [dataM appendData:[CPCLCommand drawImageWithx:xPos y:yPos image:image]];
//                     [dataM appendData:[CPCLCommand form]];
//                     [dataM appendData:[CPCLCommand print]];
//                 }
//                     break;
                    
//                 default:
//                     break;
//             }
            
//             // Send the data to printer
//             [self.bleManager writeCommandWithData:dataM writeCallBack:^(CBCharacteristic *characteristic, NSError *error) {
//                 if (error) {
//                     printSuccess = NO;
//                     errorMessage = error.localizedDescription;
//                     NSLog(@"Print error: %@", error);
//                 } else {
//                     NSLog(@"Page printed successfully");
//                 }
//                 dispatch_group_leave(group);
//             }];
            
//             // Add a small delay between pages to avoid overwhelming the printer
//             [NSThread sleepForTimeInterval:0.5];
//         }
        
//         dispatch_group_notify(group, dispatch_get_main_queue(), ^{
//             if (printSuccess) {
//                 NSLog(@"All pages printed successfully");
//                 result(@YES);
//             } else {
//                 NSLog(@"Print failed: %@", errorMessage ?: @"Unknown error");
//                 result([FlutterError errorWithCode:@"PRINT_ERROR"
//                                           message:errorMessage ?: @"Error printing PDF"
//                                           details:nil]);
//             }
//         });
//     }];
// }




















































































 
// - (void)getPrinterStatus:(FlutterResult)result {
//     if (!self.bleManager.isConnecting) {
//         result([FlutterError errorWithCode:@"NOT_CONNECTED"
//                                    message:@"Printer not connected"
//                                    details:nil]);
//         return;
//     }
    
//     [self.bleManager printerStatus:^(NSData *status) {
//         unsigned statusCode = 0;
//         if (status.length == 1) {
//             const Byte *byte = (Byte *)[status bytes];
//             statusCode = byte[0];
//         } else if (status.length == 2) {
//             const Byte *byte = (Byte *)[status bytes];
//             statusCode = byte[1];
//         }
        
//         NSString *statusMessage = @"Unknown status";
        
//         if (statusCode == 0x00) {
//             statusMessage = @"Ready";
//         } else if (statusCode == 0x01) {
//             statusMessage = @"Cover opened";
//         } else if (statusCode == 0x02) {
//             statusMessage = @"Paper jam";
//         } else if (statusCode == 0x03) {
//             statusMessage = @"Cover opened and paper jam";
//         } else if (statusCode == 0x04) {
//             statusMessage = @"Paper end";
//         } else if (statusCode == 0x05) {
//             statusMessage = @"Cover opened and Paper end";
//         } else if (statusCode == 0x08) {
//             statusMessage = @"No Ribbon";
//         } else if (statusCode == 0x09) {
//             statusMessage = @"Cover opened and no Ribbon";
//         } else if (statusCode == 0x10) {
//             statusMessage = @"Pause";
//         } else if (statusCode == 0x20) {
//             statusMessage = @"Printing";
//         }
        
//         result(@{
//             @"code": @(statusCode),
//             @"message": statusMessage
//         });
//     }];
// }

// #pragma mark - Helper Methods

// // - (void)sendDataToPrinter:(NSMutableData *)data result:(FlutterResult)result {
// //     __weak typeof(self) weakSelf = self;
// //     [self.bleManager writeCommandWithData:data writeCallBack:^(CBCharacteristic *characteristic, NSError *error) {
// //         if (error) {
// //             result([FlutterError errorWithCode:@"PRINT_ERROR"
// //                                        message:error.localizedDescription
// //                                        details:nil]);
// //             return;
// //         }
// //         result(@YES);
// //     }];
// // }
// - (void)sendDataToPrinter:(NSMutableData *)data result:(FlutterResult)result {
//     [self.commandQueue addObject:data];
//     [self processNextCommandWithResult:result];
// }

// - (void)processNextCommandWithResult:(FlutterResult)result {
//     if (self.isPrinting || self.commandQueue.count == 0) {
//         return;
//     }
    
//     self.isPrinting = YES;
//     NSData *data = self.commandQueue[0];
    
//     [self.bleManager writeCommandWithData:data writeCallBack:^(CBCharacteristic *characteristic, NSError *error) {
//         self.isPrinting = NO;
//         [self.commandQueue removeObjectAtIndex:0];
        
//         if (error) {
//             result([FlutterError errorWithCode:@"PRINT_ERROR"
//                                       message:error.localizedDescription
//                                       details:nil]);
//             return;
//         }
        
//         result(@YES);
//         [self processNextCommandWithResult:result];
//     }];
// }



// #pragma mark - TSCBLEManagerDelegate

// - (void)TSCbleUpdatePeripheralList:(NSArray *)peripherals RSSIList:(NSArray *)rssiList {
//     // Update local copies
//     [self.peripherals removeAllObjects];
//     [self.peripherals addObjectsFromArray:peripherals];
    
//     [self.rssiList removeAllObjects];
//     [self.rssiList addObjectsFromArray:rssiList];
    
//     // Convert peripherals to map for Flutter
//     NSMutableArray *deviceList = [NSMutableArray array];
    
//     for (int i = 0; i < [peripherals count]; i++) {
//         CBPeripheral *peripheral = peripherals[i];
//         NSNumber *rssi = rssiList[i];
        
//         NSMutableDictionary *deviceInfo = [NSMutableDictionary dictionary];
//         deviceInfo[@"name"] = peripheral.name ?: @"Unknown";
//         deviceInfo[@"address"] = peripheral.identifier.UUIDString;
//         deviceInfo[@"rssi"] = rssi;
        
//         [deviceList addObject:deviceInfo];
//     }
    
//     [self.channel invokeMethod:@"onScanResults" arguments:deviceList];
// }

// - (void)TSCbleConnectPeripheral:(CBPeripheral *)peripheral {
//     NSDictionary *deviceInfo = @{
//         @"name": peripheral.name ?: @"Unknown",
//         @"address": peripheral.identifier.UUIDString,
//         @"status": @"connected"
//     };
    
//     [self.channel invokeMethod:@"onConnectionChanged" arguments:deviceInfo];
// }
// - (void)TSCbleDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
//     [self.peripherals removeAllObjects];
//     [self.rssiList removeAllObjects];
//     [self.commandQueue removeAllObjects];
//     self.isPrinting = NO;
    
//     NSDictionary *deviceInfo = @{
//         @"name": peripheral.name ?: @"Unknown",
//         @"address": peripheral.identifier.UUIDString,
//         @"status": @"disconnected",
//         @"error": error ? error.localizedDescription : @""
//     };
    
//     [self.channel invokeMethod:@"onConnectionChanged" arguments:deviceInfo];
// }
// // - (void)TSCbleDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
// //     NSDictionary *deviceInfo = @{
// //         @"name": peripheral.name ?: @"Unknown",
// //         @"address": peripheral.identifier.UUIDString,
// //         @"status": @"disconnected",
// //         @"error": error ? error.localizedDescription : @""
// //     };
    
// //     [self.channel invokeMethod:@"onConnectionChanged" arguments:deviceInfo];
// // }

// // - (void)TSCbleFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
// //     NSDictionary *deviceInfo = @{
// //         @"name": peripheral.name ?: @"Unknown",
// //         @"address": peripheral.identifier.UUIDString,
// //         @"status": @"failed",
// //         @"error": error ? error.localizedDescription : @"Failed to connect"
// //     };
    
// //     [self.channel invokeMethod:@"onConnectionChanged" arguments:deviceInfo];
// // }

// - (void)TSCbleFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
//     [self.peripherals removeAllObjects];
//     [self.rssiList removeAllObjects];
//     [self.commandQueue removeAllObjects];
//     self.isPrinting = NO;
    
//     NSDictionary *deviceInfo = @{
//         @"name": peripheral.name ?: @"Unknown",
//         @"address": peripheral.identifier.UUIDString,
//         @"status": @"failed",
//         @"error": error ? error.localizedDescription : @"Failed to connect"
//     };
    
//     [self.channel invokeMethod:@"onConnectionChanged" arguments:deviceInfo];
// }

// @end
