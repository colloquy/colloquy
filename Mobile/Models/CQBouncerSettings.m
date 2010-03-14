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

	if ([info objectForKey:@"identifier"])
		_identifier = [[info objectForKey:@"identifier"] copy];
	else _identifier = [[NSString locallyUniqueString] copy];

	if ([info objectForKey:@"bouncerType"])
		self.type = [[info objectForKey:@"bouncerType"] unsignedLongLongValue];

	if ([info objectForKey:@"bouncerDescription"])
		self.displayName = [info objectForKey:@"bouncerDescription"];

	if ([info objectForKey:@"bouncerServer"])
		self.server = [info objectForKey:@"bouncerServer"];

	if ([info objectForKey:@"bouncerServerPort"])
		self.serverPort = [[info objectForKey:@"bouncerServerPort"] unsignedShortValue];

	if ([info objectForKey:@"bouncerUsername"])
		self.username = [info objectForKey:@"bouncerUsername"];

	if ([info objectForKey:@"bouncerPassword"])
		self.password = [info objectForKey:@"bouncerPassword"];

	if ([info objectForKey:@"pushNotifications"])
		self.pushNotifications = [[info objectForKey:@"pushNotifications"] boolValue];

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

	[result setObject:_identifier forKey:@"identifier"];
	[result setObject:[NSNumber numberWithLongLong:_type] forKey:@"bouncerType"];

	if (_displayName.length)
		[result setObject:_displayName forKey:@"bouncerDescription"];

	if (_server.length)
		[result setObject:_server forKey:@"bouncerServer"];

	if (_serverPort)
		[result setObject:[NSNumber numberWithUnsignedShort:_serverPort] forKey:@"bouncerServerPort"];

	if (_pushNotifications)
		[result setObject:[NSNumber numberWithBool:_pushNotifications] forKey:@"pushNotifications"];

	if (_username.length)
		[result setObject:_username forKey:@"bouncerUsername"];

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
