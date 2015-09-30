#import "CQProcessConsoleMessageOperation.h"

static NSRegularExpression *numericRegularExpression;

NS_ASSUME_NONNULL_BEGIN

@implementation CQProcessConsoleMessageOperation {
	NSMutableString *_message;
	NSString *_highlightNickname;
	BOOL _outbound;
}

@synthesize processedMessageInfo = _processedMessage;

+ (void) initialize {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		numericRegularExpression = [[NSRegularExpression alloc] initWithPattern:@"\\d{3}|CAP|AUTHENTICATE" options:NSRegularExpressionCaseInsensitive error:nil];
	});
}

- (instancetype) initWithMessage:(NSString *) message outbound:(BOOL) outbound {
	NSParameterAssert(message != nil);

	if (!(self = [self init]))
		return nil;

	_outbound = outbound;
	_message = [message mutableCopy];

	return self;
}

#pragma mark -

- (NSString *) processedMessageAsHTML {
	return _processedMessage[@"message"];
}

- (NSString *) processedMessageAsPlainText {
	return _processedMessage[@"messagePlain"];
}

#pragma mark -

- (void) _determineMessageType:(NSString *) message {
	if (([message hasCaseInsensitivePrefix:@"PRIVMSG"] || [message hasCaseInsensitivePrefix:@"NOTICE"]))
		_messageType = CQConsoleMessageTypeMessage;
	else if (([message hasCaseInsensitivePrefix:@"JOIN"] || [message hasCaseInsensitivePrefix:@"PART"] || [message hasCaseInsensitivePrefix:@"KICK"] || [message hasCaseInsensitivePrefix:@"INVITE"]))
		_messageType = CQConsoleMessageTypeTraffic;
	else if ([message hasCaseInsensitivePrefix:@"NICK"])
		_messageType = CQConsoleMessageTypeNick;
	else if ([message hasCaseInsensitivePrefix:@"TOPIC"])
		_messageType = CQConsoleMessageTypeTopic;
	else if ([message hasCaseInsensitivePrefix:@"MODE"])
		_messageType = CQConsoleMessageTypeMode;
	else if ([numericRegularExpression matchesInString:message options:NSMatchingAnchored range:NSMakeRange(0, MIN(12, (int)message.length))])
		_messageType = CQConsoleMessageTypeNumeric;
	else if ([message hasCaseInsensitivePrefix:@"CTCP"])
		_messageType = CQConsoleMessageTypeCTCP;
	else if (([message hasCaseInsensitivePrefix:@"PING"] || [message hasCaseInsensitivePrefix:@"PONG"]))
		_messageType = CQConsoleMessageTypePing;
	else _messageType = CQConsoleMessageTypeUnknown;
}

- (NSString *) _stripServerFromMessage:(NSMutableString *) message {
	NSRange spaceRange = [message rangeOfString:@" "];
	if (spaceRange.location == NSNotFound)
		return message;

	NSString *potentialServer = [message substringToIndex:spaceRange.location];
	if ([potentialServer rangeOfString:@"@"].location != NSNotFound)
		return message;

	if ([potentialServer rangeOfString:@"!"].location != NSNotFound)
		return message;

	if ([potentialServer rangeOfString:@"."].location == NSNotFound)
		return message;

	return [message substringFromIndex:(spaceRange.location + spaceRange.length)];
}

#pragma mark -

- (void) main {
	[_message replaceOccurrencesOfString:@"\n" withString:@"" options:(NSAnchoredSearch | NSBackwardsSearch) range:NSMakeRange(_message.length - 2, 2)];
	[_message replaceOccurrencesOfString:@"\r" withString:@"" options:(NSAnchoredSearch | NSBackwardsSearch) range:NSMakeRange(_message.length - 1, 1)];

	NSMutableString *verboseMessage = [_message mutableCopy];

	[_message replaceOccurrencesOfString:@":" withString:@"" options:NSAnchoredSearch range:NSMakeRange(0, MIN(1, (int)_message.length))];
	[_message replaceOccurrencesOfString:@" :" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, _message.length)];

	NSString *strippedMessage = [self _stripServerFromMessage:_message];

	[self _determineMessageType:strippedMessage];

	_processedMessage = [[NSMutableDictionary alloc] init];
	_processedMessage[@"type"] = @"console";
	_processedMessage[@"outbound"] = @(_outbound);

	if (_verbose) {
		_processedMessage[@"message"] = verboseMessage;
		_processedMessage[@"messagePlain"] = verboseMessage;
	} else {
		_processedMessage[@"message"] = strippedMessage;
		_processedMessage[@"messagePlain"] = strippedMessage;
	}

	__strong __typeof__((_target)) strongTarget = _target;
	if (strongTarget && _action)
		[strongTarget performSelectorOnMainThread:_action withObject:self waitUntilDone:NO];
}
@end

NS_ASSUME_NONNULL_END
