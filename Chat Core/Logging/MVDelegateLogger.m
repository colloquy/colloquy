#import "MVDelegateLogger.h"

@implementation MVDelegateLogger
- (id) initWithDelegate:(id <MVLoggingDelegate>) delegate {
	if (!(self = [super init]))
		return nil;

	_delegate = delegate;

	return self;
}

- (void) logMessage:(DDLogMessage *) logMessage {
	[_delegate delegateLogger:self socketTrafficDidOccur:logMessage->logMsg context:(uintptr_t)logMessage->logContext];
}

- (NSString *) loggerName {
	return [NSString stringWithFormat:@"info.colloquy.delegateLogger-%p", self];
}
@end
