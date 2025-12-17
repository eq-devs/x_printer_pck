//
//  XPrinterPckPlugin.h
//  Flutter POS Printer Plugin
//

#import <Flutter/Flutter.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "TSCBLEManager.h"

@interface XPrinterPckPlugin : NSObject <FlutterPlugin, TSCBLEManagerDelegate>

@property (nonatomic, strong) FlutterMethodChannel *channel;
@property (nonatomic, strong) TSCBLEManager *bleManager;
@property (nonatomic, strong) NSMutableArray *peripherals;
@property (nonatomic, strong) NSMutableArray *rssiList;

// Add initialization tracking property
@property (nonatomic, assign) BOOL isInitialized;

// Method declarations
// - (void)initializePlugin:(FlutterResult)result;
- (BOOL)checkInitialization:(FlutterResult)result;
- (void)printImageBase64:(id)arguments result:(FlutterResult)result;

// Image processing helper methods
- (UIImage *)processImage:(UIImage *)originalImage 
             printerWidth:(int)printerWidth 
            printerHeight:(int)printerHeight 
                    scale:(CGFloat)scale 
                 rotation:(int)rotationAngle 
                  quality:(CGFloat)quality;

- (UIImage *)rotateImage:(UIImage *)image byAngle:(int)degrees;

- (CGPoint)calculatePosition:(CGSize)imageSize 
                printerWidth:(int)printerWidth 
               printerHeight:(int)printerHeight 
                   alignment:(NSString *)alignment 
                     customX:(int)customX 
                     customY:(int)customY;

- (NSMutableData *)generatePrintCommands:(UIImage *)image 
                                position:(CGPoint)position 
                            commandType:(int)commandType 
                           printerWidth:(int)printerWidth 
                          printerHeight:(int)printerHeight;

@end