#import "CQBouncerSettings.h"

#import "CQKeychain.h"

@implementation CQBouncerSettings
- (id) init {
	if (!(self = [super init]))
		return nil;

	_identifier = [[NSString locallyUniqueString] copy];
	_type = MVChatConnectionColloquyBouncer;
	_pushNotifications = YES;
	_serverPort = 6667;

	return self;
}

- (id) initWithDictionaryRepresentation:(NSDictionary *) info {
	if (!(self = [super init]))
		return nil;

	_type = MVChatConnectionColloquyBouncer;

	if (info[@"identifier"])
		_identifier = [info[@"identifier"] copy];
	else _identifier = [[NSString locallyUniqueString] copy];

	if (info[@"bouncerType"])
		self.type = [info[@"bouncerType"] unsignedLongValue];

	if (info[@"bouncerDescription"])
		self.displayName = info[@"bouncerDescription"];

	if (info[@"bouncerServer"])
		self.server = info[@"bouncerServer"];

	if (info[@"bouncerServerPort"])
		self.serverPort = [info[@"bouncerServerPort"] unsignedShortValue];

	if (info[@"bouncerUsername"])
		self.username = info[@"bouncerUsername"];

	if (info[@"bouncerPassword"])
		self.password = info[@"bouncerPassword"];

	if (info[@"pushNotifications"])
		self.pushNotifications = [info[@"pushNotifications"] boolValue];

	return self;
}

- (void) dealloc {
	[_identifier release];
	[_displayName release];
	[_server release];
	[_username release];
	[_password release];

	[super dealloc];
}

- (NSMutableDictionary *) dictionaryRepresentation {
	NSMutableDictionary *result = [[NSMutableDictionary alloc] init];

	result[@"identifier"] = _identifier;
	result[@"bouncerType"] = [NSNumber numberWithLongLong:_type];

	if (_displayName.length)
		result[@"bouncerDescription"] = _displayName;

	if (_server.length)
		result[@"bouncerServer"] = _server;

	if (_serverPort)
		result[@"bouncerServerPort"] = @(_serverPort);

	if (_pushNotifications)
		result[@"pushNotifications"] = @(_pushNotifications);

	if (_username.length)
		result[@"bouncerUsername"] = _username;

	// Password is not included so it wont get written to NSUserDefaults be accident.
	// The password is stored in the keychain and retrieved when needed.

	return [result autorelease];
}

@synthesize identifier = _identifier;
@synthesize type = _type;
@synthesize displayName = _displayName;
@synthesize server = _server;
@synthesize username = _username;
@synthesize password = _password;
@synthesize serverPort = _serverPort;
@synthesize pushNotifications = _pushNotifications;

- (NSString *) displayName {
	return (_displayName.length ? _displayName : _server);
}

- (void) setType:(MVChatConnectionBouncer) type {
	NSParameterAssert(type != MVChatConnectionNoProxy);
	_type = type;
}

- (NSString *) password {
	if (!_password && _server && _username)
		_password = [[[CQKeychain standardKeychain] passwordForServer:_identifier area:@"Bouncer"] copy];
	return _password;
}

- (void) setPassword:(NSString *) password {
	if (_password != password) {
		id old = _password;
		_password = [password copy];
		[old release];
	}

	if (!_server.length || !_username.length)
		return;

	[[CQKeychain standardKeychain] setPassword:password forServer:_identifier area:@"Bouncer"];
}
@end
