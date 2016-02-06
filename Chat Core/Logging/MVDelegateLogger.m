#import "MVDelegateLogger.h"

@implementation MVDelegateLogger {
	__weak id <MVLoggingDelegate> _delegate;
}

- (instancetype) init {
	NSAssert(NO, @"use [MVDelegateLogger initWithDelegate:] instead");
	return nil;
}


- (instancetype) initWithDelegate:(id <MVLoggingDelegate>) delegate {
	if (!(self = [super init]))
		return nil;

	_delegate = delegate;

	return self;
}

- (void) logMessage:(DDLogMessage *) logMessage {
	__strong __typeof__((_delegate)) delegate = _delegate;
	[delegate delegateLogger:self socketTrafficDidOccur:logMessage->logMsg context:(int)logMessage->logContext];
}

- (NSString *) loggerName {
	return [[NSString alloc] initWithFormat:@"info.colloquy.delegateLogger-%p", self];
}
@end
