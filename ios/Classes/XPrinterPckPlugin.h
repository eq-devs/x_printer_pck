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

@end

