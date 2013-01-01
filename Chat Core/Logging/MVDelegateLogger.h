#import "DDLog.h"

@protocol MVLoggingDelegate <NSObject>
@required
- (void) socketTrafficDidOccur:(NSString *) socketTraffic context:(void *) context;
@end

@interface MVDelegateLogger : DDAbstractLogger {
	id <MVLoggingDelegate> _delegate;
}

- (id) initWithDelegate:(id <MVLoggingDelegate>) delegate;
@end
