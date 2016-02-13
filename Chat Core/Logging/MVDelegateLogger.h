#import "DDLogMacros.h"

@class MVDelegateLogger;

@protocol MVLoggingDelegate <NSObject>
@required
- (void) delegateLogger:(MVDelegateLogger *) delegateLogger socketTrafficDidOccur:(NSString *) socketTraffic context:(int) context;
@end

@interface MVDelegateLogger : DDAbstractLogger
- (instancetype) init NS_UNAVAILABLE;
- (instancetype) initWithDelegate:(id <MVLoggingDelegate>) delegate NS_DESIGNATED_INITIALIZER;
@end
