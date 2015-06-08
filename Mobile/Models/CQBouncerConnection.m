#import "CQBouncerConnection.h"

#import "GCDAsyncSocket.h"
#import "CQBouncerSettings.h"

#import <objc/message.h>

@implementation CQBouncerConnection
- (instancetype) init {
	NSAssert(NO, @"use [CQBouncerConnection initWithBouncerSettings:] instead");
	return nil;
}

- (instancetype) initWithBouncerSettings:(CQBouncerSettings *) settings {
	if (!(self = [super init]))
		return nil;

	self.settings = settings;

	return self;
}

- (void) dealloc {
	[self disconnect];
}

- (void) sendRawMessage:(id) raw {
	NSParameterAssert(raw != nil);
	NSParameterAssert([raw isKindOfClass:[NSData class]] || [raw isKindOfClass:[NSString class]]);

	NSData *message = raw;
	if ([raw isKindOfClass:[NSString class]])
		message = [raw dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];

	if ([message hasSuffixBytes:"\x0D" length:1]) {
		NSMutableData *mutableMessage = [message mutableCopy];
		[mutableMessage appendBytes:"\x0A" length:1];
		message = mutableMessage;
	} else if (![message hasSuffixBytes:"\x0D\x0A" length:2]) {
		NSMutableData *mutableMessage = [message mutableCopy];
		if ([mutableMessage hasSuffixBytes:"\x0A" length:1])
			[mutableMessage replaceBytesInRange:NSMakeRange((mutableMessage.length - 1), 1) withBytes:"\x0D\x0A" length:2];
		else [mutableMessage appendBytes:"\x0D\x0A" length:2];
		message = mutableMessage;
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
}

- (void) connect {
	if (_socket || !_settings)
		return;

	NSAssert(_settings.server.length, @"Bouncer server required");
	NSAssert(_settings.serverPort, @"Bouncer server port required");

	if (!_settings.server.length || !_settings.serverPort)
		return;

	_socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)];
	[_socket connectToHost:_settings.server onPort:_settings.serverPort error:NULL];
}

- (void) disconnect {
	[_socket disconnectAfterWriting];
}

- (void) socket:(GCDAsyncSocket *) sock didConnectToHost:(NSString *) host port:(UInt16)port {
	_error = nil;

	__strong __typeof__((_delegate)) delegate = _delegate;
	if ([delegate respondsToSelector:@selector(bouncerConnectionDidConnect:)])
		[delegate bouncerConnectionDidConnect:self];

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

- (void) socket:(GCDAsyncSocket *) sock willDisconnectWithError:(NSError *) error {
	_error = error;
}

- (void) socketDidDisconnect:(GCDAsyncSocket *) sock {
	_socket = nil;

	__strong __typeof__((_delegate)) delegate = _delegate;
	if ([delegate respondsToSelector:@selector(bouncerConnectionDidDisconnect:withError:)])
		[delegate bouncerConnectionDidDisconnect:self withError:_error];
}

- (void) socket:(GCDAsyncSocket *) sock didWriteDataWithTag:(long) tag {
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

- (void) socket:(GCDAsyncSocket *) sock didReadData:(NSData *) data withTag:(long) tag {
	const char *line = (const char *)data.bytes;
	NSUInteger len = data.length;
	const char *end = line + len - 2; // minus the line endings

	if (*end != '\x0D')
		end = line + len - 1; // this server only uses \x0A for the message line ending, lets work with it

	const char *command = NULL;
	NSUInteger commandLength = 0;

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

		consumeWhitespace();
	}

#undef checkAndMarkIfDone
#undef consumeWhitespace
#undef notEndOfLine

end:
	if (command && commandLength) {
		NSString *commandString = [[NSString alloc] initWithBytes:command length:commandLength encoding:NSASCIIStringEncoding];
		NSString *selectorString = [[NSString alloc] initWithFormat:@"_handle%@WithParameters:", [commandString capitalizedString]];
		SEL selector = NSSelectorFromString(selectorString);

		if ([self respondsToSelector:selector])
			((void(*)(id, SEL, id))objc_msgSend)(self, selector, parameters);
	}

	[self _readNextMessage];
}

- (void) _resetState {
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

	MVSafeRetainAssign( _connectionIdentifier, parameters[0] );
	MVSafeRetainAssign( _serverAddress, parameters[1] );
	_serverPort = ([parameters[2] integerValue] % 65536);
	_secure = (parameters.count > 3 ? [parameters[3] isCaseInsensitiveEqualToString:@"SSL"] : NO);
}

- (void) _handle802WithParameters:(NSArray *) parameters {
	if (parameters.count < 2) {
		[self disconnect];
		return;
	}

	MVSafeRetainAssign( _username, parameters[0] );
	MVSafeRetainAssign( _realName, parameters[1] );
}

- (void) _handle803WithParameters:(NSArray *) parameters {
	if (parameters.count < 1) {
		[self disconnect];
		return;
	}

	MVSafeRetainAssign( _password, parameters[0] );
}

- (void) _handle804WithParameters:(NSArray *) parameters {
	if (!parameters.count) {
		[self disconnect];
		return;
	}

	MVSafeRetainAssign( _nickname, parameters[0] );
	MVSafeRetainAssign( _nicknamePassword, (parameters.count > 1 ? parameters[1] : nil) );
}

- (void) _handle805WithParameters:(NSArray *) parameters {
	if (!parameters.count) {
		[self disconnect];
		return;
	}

	MVSafeRetainAssign( _alternateNicknames, parameters );
}

- (void) _handle806WithParameters:(NSArray *) parameters {
	if (!parameters.count) {
		[self disconnect];
		return;
	}

	_encoding = [parameters[0] integerValue];
}

- (void) _handle807WithParameters:(NSArray *) parameters {
	if (!parameters.count) {
		[self disconnect];
		return;
	}

	_connectedTime = [parameters[0] doubleValue];
}

- (void) _handle810WithParameters:(NSArray *) parameters {
	__strong __typeof__((_delegate)) delegate = _delegate;

	if ([delegate respondsToSelector:@selector(bouncerConnection:didRecieveConnectionInfo:)]) {
		NSMutableDictionary *info = [[NSMutableDictionary alloc] initWithCapacity:10];

		if (_connectionIdentifier.length)
			info[@"connectionIdentifier"] = _connectionIdentifier;
		if (_serverAddress.length)
			info[@"serverAddress"] = _serverAddress;
		if (_serverPort)
			info[@"serverPort"] = @(_serverPort);
		if (_secure)
			info[@"secure"] = @(_secure);
		if (_username.length)
			info[@"username"] = _username;
		if (_realName.length)
			info[@"realName"] = _realName;
		if (_password.length)
			info[@"password"] = _password;
		if (_nickname.length)
			info[@"nickname"] = _nickname;
		if (_nicknamePassword.length)
			info[@"nicknamePassword"] = _nicknamePassword;
		if (_alternateNicknames.count)
			info[@"alternateNicknames"] = _alternateNicknames;
		if (_connectedTime)
			info[@"connectedTime"] = @(_connectedTime);
		if (_encoding)
			info[@"encoding"] = @(_encoding);

		__strong __typeof__((_delegate)) delegate = _delegate;
		[delegate bouncerConnection:self didRecieveConnectionInfo:info];
	}

	[self _resetState];
}

- (void) _handle811WithParameters:(NSArray *) parameters {
	__strong __typeof__((_delegate)) delegate = _delegate;
	if ([delegate respondsToSelector:@selector(bouncerConnectionDidFinishConnectionList:)])
		[delegate bouncerConnectionDidFinishConnectionList:self];
	[self disconnect];
}

- (void) _readNextMessage {
	// IRC messages end in \x0D\x0A, but some non-compliant servers only use \x0A during the connecting phase
	static NSData *delimiter = nil;
	if (!delimiter) delimiter = [[NSData alloc] initWithBytes:"\x0A" length:1];

	[_socket readDataToData:delimiter withTimeout:-1. tag:0];
}
@end
