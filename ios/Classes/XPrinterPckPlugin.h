//
//  XPrinterPckPlugin.h
//  Flutter POS Printer Plugin
//

#import <Flutter/Flutter.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "TSCBLEManager.h"
@protocol TSCBLEManagerDelegate;
@interface XPrinterPckPlugin : NSObject <FlutterPlugin, TSCBLEManagerDelegate>
// @property (nonatomic, strong) NSMutableArray<NSData *> *commandQueue;
// @property (nonatomic, assign) BOOL isInitialized; // Track initialization status
// @property (nonatomic, strong) FlutterMethodChannel *channel;
// @property (nonatomic, strong) TSCBLEManager *bleManager;
// @property (nonatomic, strong) NSMutableArray *peripherals;
// @property (nonatomic, strong) NSMutableArray *rssiList;

@end

