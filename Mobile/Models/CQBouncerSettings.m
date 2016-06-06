#import "CQBouncerSettings.h"

#import "CQKeychain.h"

NS_ASSUME_NONNULL_BEGIN

@implementation CQBouncerSettings {
	NSString *_password;
}

- (instancetype) init {
	return [self initWithDictionaryRepresentation:@{ @"pushNotifications": @(YES), @"serverPort": @(6667) }];
}

- (instancetype) initWithDictionaryRepresentation:(NSDictionary *) info {
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

- (NSMutableDictionary *) dictionaryRepresentation {
	NSMutableDictionary *result = [[NSMutableDictionary alloc] init];

	result[@"identifier"] = _identifier;
	result[@"bouncerType"] = @(_type);

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

	return result;
}

- (NSString *) displayName {
	return (_displayName.length ? _displayName : _server);
}

- (void) setType:(MVChatConnectionBouncer) type {
	NSParameterAssert(type != MVChatConnectionNoBouncer);
	_type = type;
}

- (NSString *__nullable) password {
	if (!_password && _server && _username)
		_password = [[[CQKeychain standardKeychain] passwordForServer:_identifier area:@"Bouncer"] copy];
	return _password;
}

- (void) setPassword:(NSString *__nullable) password {
	if (_password != password) {
		_password = [password copy];
	}

	if (!_server.length || !_username.length)
		return;

	[[CQKeychain standardKeychain] setPassword:password forServer:_identifier area:@"Bouncer"];
}
@end

NS_ASSUME_NONNULL_END
