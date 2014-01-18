#import "DDLog.h"

@class MVDelegateLogger;

@protocol MVLoggingDelegate <NSObject>
@required
- (void) delegateLogger:(MVDelegateLogger *) delegateLogger socketTrafficDidOccur:(NSString *) socketTraffic context:(void *) context;
@end

@interface MVDelegateLogger : DDAbstractLogger {
	__weak id <MVLoggingDelegate> _delegate;
}

- (id) initWithDelegate:(id <MVLoggingDelegate>) delegate;
@end
