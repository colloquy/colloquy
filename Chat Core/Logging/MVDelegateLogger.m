#import "MVDelegateLogger.h"

@implementation MVDelegateLogger
- (id) initWithDelegate:(id <MVLoggingDelegate>) delegate {
	if (!(self = [super init]))
		return nil;

	_delegate = delegate;

	return self;
}

- (void) logMessage:(DDLogMessage *) logMessage {
	[_delegate socketTrafficDidOccur:logMessage->logMsg context:(void *)logMessage->logContext];
}

- (NSString *) loggerName {
	return @"info.colloquy.delegateLogger";
}
@end
