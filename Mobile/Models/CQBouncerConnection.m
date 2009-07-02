#import "CQBouncerConnection.h"

#import "AsyncSocket.h"
#import "CQBouncerSettings.h"
#import "NSDataAdditions.h"
#import "NSStringAdditions.h"
#import "MVUtilities.h"

#import <objc/objc-runtime.h>

@interface CQBouncerConnection (CQBouncerConnectionPrivate)
- (void) _readNextMessage;
- (NSString *) _newStringWithBytes:(const char *) bytes length:(unsigned) length;
@end

@implementation CQBouncerConnection
- (id) initWithBouncerSettings:(CQBouncerSettings *) settings {
	if (!(self = [super init]))
		return nil;

	self.settings = settings;

	return self;
}

- (void) dealloc {
	[self disconnect];

	[_settings release];
	[_socket release];

	[_connectionIdentifier release];
	[_serverAddress release];
	[_username release];
	[_realName release];
	[_password release];
	[_nickname release];
	[_nicknamePassword release];
	[_alternateNicknames release];

	[super dealloc];
}

@synthesize settings = _settings;
@synthesize delegate = _delegate;

- (void) sendRawMessage:(id) raw {
	NSParameterAssert(raw != nil);
	NSParameterAssert([raw isKindOfClass:[NSData class]] || [raw isKindOfClass:[NSString class]]);

	NSData *message = raw;
	if ([raw isKindOfClass:[NSString class]])
		message = [raw dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];

	if ([message hasSuffixBytes:"\x0D" length:1]) {
		NSMutableData *mutableMessage = [message mutableCopy];
		[mutableMessage appendBytes:"\x0A" length:1];
		message = [mutableMessage autorelease];
	} else if (![message hasSuffixBytes:"\x0D\x0A" length:2]) {
		NSMutableData *mutableMessage = [message mutableCopy];
		if ([mutableMessage hasSuffixBytes:"\x0A" length:1])
			[mutableMessage replaceBytesInRange:NSMakeRange((mutableMessage.length - 1), 1) withBytes:"\x0D\x0A" length:2];
		else [mutableMessage appendBytes:"\x0D\x0A" length:2];
		message = [mutableMessage autorelease];
	}

	[_socket writeData:message withTimeout:-1. tag:0];
}

- (void) sendRawMessageWithFormat:(NSString *) format, ... {
	NSParameterAssert(format != nil);

	va_list ap;
	va_start(ap, format);

	NSString *command = [[NSString alloc] initWithFormat:format arguments:ap];

	va_end(ap);

	[self sendRawMessage:command];
	[command release];
}

- (void) connect {
	if (_socket || !_settings)
		return;

	NSAssert(_settings.server.length, @"Bouncer server required");
	NSAssert(_settings.serverPort, @"Bouncer server port required");

	if (!_settings.server.length || !_settings.serverPort)
		return;

	_socket = [[AsyncSocket alloc] initWithDelegate:self];
	[_socket connectToHost:_settings.server onPort:_settings.serverPort error:NULL];
}

- (void) disconnect {
	[_socket disconnectAfterWriting];
}

- (void) socket:(AsyncSocket *) sock didConnectToHost:(NSString *) host port:(UInt16)port {
	if ([_delegate respondsToSelector:@selector(bouncerConnectionDidConnect:)])
		[_delegate bouncerConnectionDidConnect:self];

	NSAssert(_settings.username.length, @"Bouncer username required");
	NSAssert(_settings.password.length, @"Bouncer password required");

	if (!_settings.username.length || !_settings.password.length) {
		[self disconnect];
		return;
	}

	[self sendRawMessageWithFormat:@"PASS %@:%@", _settings.username, _settings.password];
	[self sendRawMessage:@"CONNECTIONS"];

	[self _readNextMessage];
}

- (void) socketDidDisconnect:(AsyncSocket *) sock {
	[_socket release];
	_socket = nil;

	if ([_delegate respondsToSelector:@selector(bouncerConnectionDidDisconnect:)])
		[_delegate bouncerConnectionDidDisconnect:self];
}

- (void) socket:(AsyncSocket *) sock didWriteDataWithTag:(long) tag {
	if (tag < 0)
		[self disconnect];
}

static inline NSString *newStringWithBytes(const char *bytes, NSUInteger length) {
	if (bytes && length)
		return [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
	if (bytes && !length)
		return @"";
	return nil;
}

- (void) socket:(AsyncSocket *) sock didReadData:(NSData *) data withTag:(long) tag {
	const char *line = (const char *)data.bytes;
	unsigned int len = data.length;
	const char *end = line + len - 2; // minus the line endings

	if (*end != '\x0D')
		end = line + len - 1; // this server only uses \x0A for the message line ending, lets work with it

	const char *command = NULL;
	unsigned commandLength = 0;

	NSMutableArray *parameters = [[NSMutableArray alloc] initWithCapacity:15];

	if (len <= 2)
		goto end; // bad message

#define checkAndMarkIfDone() if (line == end) done = YES
#define consumeWhitespace() while (*line == ' ' && line != end && !done) line++
#define notEndOfLine() line != end && !done

	BOOL done = NO;
	if (notEndOfLine()) {
		// command: <letter> { <letter> } | <number> <number> <number>
		// letter: 'a' ... 'z' | 'A' ... 'Z'
		// number: '0' ... '9'
		command = line;
		while (notEndOfLine() && *line != ' ') line++;
		commandLength = (line - command);
		checkAndMarkIfDone();

		if (!done) line++;
		consumeWhitespace();
	}

	while (notEndOfLine()) {
		// params: [ ':' <trailing data> | <letter> { <letter> } ] [ ' ' { ' ' } ] [ <params> ]
		const char *currentParameter = NULL;
		id param = nil;
		if (*line == ':') {
			currentParameter = ++line;
			param = newStringWithBytes(currentParameter, (end - currentParameter));
			done = YES;
		} else {
			currentParameter = line;
			while (notEndOfLine() && *line != ' ') line++;
			param = newStringWithBytes(currentParameter, (line - currentParameter));
			checkAndMarkIfDone();
			if (!done) line++;
		}

		if (param) [parameters addObject:param];
		[param release];

		consumeWhitespace();
	}

#undef checkAndMarkIfDone()
#undef consumeWhitespace()
#undef notEndOfLine()

end:
	if (command && commandLength) {
		NSString *commandString = [[NSString alloc] initWithBytes:command length:commandLength encoding:NSASCIIStringEncoding];
		NSString *selectorString = [[NSString alloc] initWithFormat:@"_handle%@WithParameters:", [commandString capitalizedString]];
		SEL selector = NSSelectorFromString(selectorString);
		[selectorString release];

		if ([self respondsToSelector:selector])
			((void(*)(id, SEL, id))objc_msgSend)(self, selector, parameters);

		[commandString release];
	}

	[parameters release];

	[self _readNextMessage];
}

- (void) _resetState {
	[_connectionIdentifier release];
	[_serverAddress release];
	[_username release];
	[_realName release];
	[_password release];
	[_nickname release];
	[_nicknamePassword release];
	[_alternateNicknames release];

	_connectionIdentifier = nil;
	_serverAddress = nil;
	_username = nil;
	_realName = nil;
	_password = nil;
	_nickname = nil;
	_nicknamePassword = nil;
	_alternateNicknames = nil;

	_secure = NO;
	_serverPort = 0;
	_encoding = 0;
	_connectedTime = 0.0;
}

- (void) _handle801WithParameters:(NSArray *) parameters {
	if (parameters.count < 3) {
		[self disconnect];
		return;
	}

	[self _resetState];

	MVSafeRetainAssign(&_connectionIdentifier, [parameters objectAtIndex:0]);
	MVSafeRetainAssign(&_serverAddress, [parameters objectAtIndex:1]);
	_serverPort = ([[parameters objectAtIndex:2] integerValue] % 65536);
	_secure = (parameters.count > 3 ? [[parameters objectAtIndex:3] isCaseInsensitiveEqualToString:@"SSL"] : NO);
}

- (void) _handle802WithParameters:(NSArray *) parameters {
	if (parameters.count < 2) {
		[self disconnect];
		return;
	}

	MVSafeRetainAssign(&_username, [parameters objectAtIndex:0]);
	MVSafeRetainAssign(&_realName, [parameters objectAtIndex:1]);
}

- (void) _handle803WithParameters:(NSArray *) parameters {
	if (parameters.count < 1) {
		[self disconnect];
		return;
	}

	MVSafeRetainAssign(&_password, [parameters objectAtIndex:0]);
}

- (void) _handle804WithParameters:(NSArray *) parameters {
	if (!parameters.count) {
		[self disconnect];
		return;
	}

	MVSafeRetainAssign(&_nickname, [parameters objectAtIndex:0]);
	MVSafeRetainAssign(&_nicknamePassword, (parameters.count > 1 ? [parameters objectAtIndex:1] : nil));
}

- (void) _handle805WithParameters:(NSArray *) parameters {
	if (!parameters.count) {
		[self disconnect];
		return;
	}

	MVSafeRetainAssign(&_alternateNicknames, parameters);
}

- (void) _handle806WithParameters:(NSArray *) parameters {
	if (!parameters.count) {
		[self disconnect];
		return;
	}

	_encoding = [[parameters objectAtIndex:0] integerValue];
}

- (void) _handle807WithParameters:(NSArray *) parameters {
	if (!parameters.count) {
		[self disconnect];
		return;
	}

	_connectedTime = [[parameters objectAtIndex:0] doubleValue];
}

- (void) _handle810WithParameters:(NSArray *) parameters {
	if ([_delegate respondsToSelector:@selector(bouncerConnection:didRecieveConnectionInfo:)]) {
		NSMutableDictionary *info = [[NSMutableDictionary alloc] initWithCapacity:10];

		if (_connectionIdentifier.length)
			[info setObject:_connectionIdentifier forKey:@"connectionIdentifier"];
		if (_serverAddress.length)
			[info setObject:_serverAddress forKey:@"serverAddress"];
		if (_serverPort)
			[info setObject:[NSNumber numberWithUnsignedShort:_serverPort] forKey:@"serverPort"];
		if (_secure)
			[info setObject:[NSNumber numberWithBool:_secure] forKey:@"secure"];
		if (_username.length)
			[info setObject:_username forKey:@"username"];
		if (_realName.length)
			[info setObject:_realName forKey:@"realName"];
		if (_password.length)
			[info setObject:_password forKey:@"password"];
		if (_nickname.length)
			[info setObject:_nickname forKey:@"nickname"];
		if (_nicknamePassword.length)
			[info setObject:_nicknamePassword forKey:@"nicknamePassword"];
		if (_alternateNicknames.count)
			[info setObject:_alternateNicknames forKey:@"alternateNicknames"];
		if (_connectedTime)
			[info setObject:[NSNumber numberWithDouble:_connectedTime] forKey:@"connectedTime"];
		if (_encoding)
			[info setObject:[NSNumber numberWithInteger:_encoding] forKey:@"encoding"];

		[_delegate bouncerConnection:self didRecieveConnectionInfo:info];

		[info release];
	}

	[self _resetState];
}

- (void) _handle811WithParameters:(NSArray *) parameters {
	if ([_delegate respondsToSelector:@selector(bouncerConnectionDidFinishConnectionList:)])
		[_delegate bouncerConnectionDidFinishConnectionList:self];
	[self disconnect];
}

- (void) _readNextMessage {
	// IRC messages end in \x0D\x0A, but some non-compliant servers only use \x0A during the connecting phase
	static NSData *delimiter = nil;
	if (!delimiter) delimiter = [[NSData alloc] initWithBytes:"\x0A" length:1];

	[_socket readDataToData:delimiter withTimeout:-1. tag:0];
}
@end
