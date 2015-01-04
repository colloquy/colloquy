#import "DDLog.h"

@class MVDelegateLogger;

@protocol MVLoggingDelegate <NSObject>
@required
- (void) delegateLogger:(MVDelegateLogger *) delegateLogger socketTrafficDidOccur:(NSString *) socketTraffic context:(void *) context;
@end

@interface MVDelegateLogger : DDAbstractLogger {
	__weak id <MVLoggingDelegate> _delegate;
}

- (instancetype) initWithDelegate:(id <MVLoggingDelegate>) delegate NS_DESIGNATED_INITIALIZER;
@end
