#import "CQProcessConsoleMessageOperation.h"

#import "NSStringAdditions.h"

static NSRegularExpression *numericRegularExpression;

@implementation CQProcessConsoleMessageOperation
+ (void) initialize {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		numericRegularExpression = [[NSRegularExpression alloc] initWithPattern:@"\\d{3}|CAP|AUTHENTICATE" options:NSRegularExpressionCaseInsensitive error:nil];
	});
}
@synthesize processedMessageInfo = _processedMessage;
@synthesize encoding = _encoding;
@synthesize fallbackEncoding = _fallbackEncoding;
@synthesize target = _target;
@synthesize action = _action;
@synthesize userInfo = _userInfo;
@synthesize messageType = _messageType;

- (id) initWithMessage:(NSString *) message outbound:(BOOL) outbound {
	NSParameterAssert(message != nil);

	if (!(self = [self init]))
		return nil;

	_outbound = outbound;
	_message = [message mutableCopy];
	_encoding = NSUTF8StringEncoding;
	_fallbackEncoding = NSISOLatin1StringEncoding;

	return self;
}

- (void) dealloc {
	[_message release];
	[_processedMessage release];
	[_highlightNickname release];
	[_target release];
	[_userInfo release];

	[super dealloc];
}

#pragma mark -

- (NSString *) processedMessageAsHTML {
	return [_processedMessage objectForKey:@"message"];
}

- (NSString *) processedMessageAsPlainText {
	return [_processedMessage objectForKey:@"messagePlain"];
}

#pragma mark -

- (void) _determineMessageType {
	if (([_message hasCaseInsensitivePrefix:@"PRIVMSG"] || [_message hasCaseInsensitivePrefix:@"NOTICE"]))
		_messageType = CQConsoleMessageTypeMessage;
	else if (([_message hasCaseInsensitivePrefix:@"JOIN"] || [_message hasCaseInsensitivePrefix:@"PART"] || [_message hasCaseInsensitivePrefix:@"KICK"] || [_message hasCaseInsensitivePrefix:@"INVITE"]))
		_messageType = CQConsoleMessageTypeTraffic;
	else if ([_message hasCaseInsensitivePrefix:@"NICK"])
		_messageType = CQConsoleMessageTypeNick;
	else if ([_message hasCaseInsensitivePrefix:@"TOPIC"])
		_messageType = CQConsoleMessageTypeTopic;
	else if ([_message hasCaseInsensitivePrefix:@"MODE"])
		_messageType = CQConsoleMessageTypeMode;
	else if ([numericRegularExpression matchesInString:_message options:NSMatchingAnchored range:NSMakeRange(0, MIN(12, (int)_message.length))])
		_messageType = CQConsoleMessageTypeNumeric;
	else if ([_message hasCaseInsensitivePrefix:@"CTCP"])
		_messageType = CQConsoleMessageTypeCTCP;
	else if (([_message hasCaseInsensitivePrefix:@"PING"] || [_message hasCaseInsensitivePrefix:@"PONG"]))
		_messageType = CQConsoleMessageTypePing;
	else _messageType = CQConsoleMessageTypeUnknown;
}

#pragma mark -

- (void) main {
	[_message replaceOccurrencesOfString:@"\n" withString:@"" options:(NSAnchoredSearch | NSBackwardsSearch) range:NSMakeRange(_message.length - 2, 2)];
	[_message replaceOccurrencesOfString:@"\r" withString:@"" options:(NSAnchoredSearch | NSBackwardsSearch) range:NSMakeRange(_message.length - 1, 1)];
	[_message replaceOccurrencesOfString:@":" withString:@"" options:NSAnchoredSearch range:NSMakeRange(0, MIN(1, (int)_message.length))];
	[_message replaceOccurrencesOfString:@" :" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, _message.length)];

	[self _determineMessageType];

	NSString *messageString = [_message stringByAddingPercentEscapesUsingEncoding:_encoding];
	if (!messageString)
		messageString = [_message stringByAddingPercentEscapesUsingEncoding:_fallbackEncoding];

	_processedMessage = [[NSMutableDictionary alloc] init];

	[_processedMessage setObject:@"console" forKey:@"type"];
	[_processedMessage setObject:_message forKey:@"message"];
	[_processedMessage setObject:@(_outbound) forKey:@"outbound"];

	[_processedMessage setObject:_message forKey:@"messagePlain"];

	if (_target && _action)
		[_target performSelectorOnMainThread:_action withObject:self waitUntilDone:NO];
}
@end
