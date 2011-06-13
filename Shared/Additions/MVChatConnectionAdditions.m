#import "MVChatConnectionAdditions.h"

#import "CQKeychain.h"

#if SYSTEM(IOS)
#import "CQBouncerSettings.h"
#endif

@implementation MVChatConnection (MVChatConnectionAdditions)
+ (NSString *) defaultNickname {
	NSString *defaultNickname = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQDefaultNickname"];
	if (defaultNickname.length)
		return defaultNickname;

#if SYSTEM(MAC) || SYSTEM(IOS_SIMULATOR)
	return NSUserName();
#elif SYSTEM(IOS)
	static NSString *generatedNickname;
	if (!generatedNickname) {
		NSCharacterSet *badCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890"] invertedSet];
		NSArray *components = [[UIDevice currentDevice].name componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		for (NSString *compontent in components) {
			if ([compontent isCaseInsensitiveEqualToString:@"iPhone"] || [compontent isCaseInsensitiveEqualToString:@"iPod"] || [compontent isCaseInsensitiveEqualToString:@"iPad"])
				continue;
			if ([compontent isEqualToString:@"3G"] || [compontent isEqualToString:@"3GS"] || [compontent isEqualToString:@"S"] || [compontent isCaseInsensitiveEqualToString:@"Touch"])
				continue;
			if ([compontent hasCaseInsensitiveSuffix:@"'s"])
				compontent = [compontent substringWithRange:NSMakeRange(0, (compontent.length - 2))];
			if (!compontent.length)
				continue;
			generatedNickname = [[compontent stringByReplacingCharactersInSet:badCharacters withString:@""] copy];
			break;
		}
	}

	if (generatedNickname.length)
		return generatedNickname;
#endif

	return NSLocalizedString(@"ColloquyUser", @"Default nickname");
}

+ (NSString *) defaultRealName {
	NSString *defaultRealName = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQDefaultRealName"];
	if (defaultRealName.length)
		return defaultRealName;

#if SYSTEM(MAC) || SYSTEM(IOS_SIMULATOR)
	return NSFullUserName();
#elif SYSTEM(IOS)
	static NSString *generatedRealName;
	if (!generatedRealName) {
		// This might only work for English users, but it is fine for now.
		NSString *deviceName = [UIDevice currentDevice].name;
		NSRange range = [deviceName rangeOfString:@"'s" options:NSLiteralSearch];
		if (range.location != NSNotFound)
			generatedRealName = [[deviceName substringToIndex:range.location] copy];
	}

	if (generatedRealName.length)
		return generatedRealName;
#endif

	return NSLocalizedString(@"Colloquy User", @"Default real name");
}

+ (NSString *) defaultUsernameWithNickname:(NSString *) nickname {
	NSCharacterSet *badCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz"] invertedSet];
	NSString *username = [[nickname lowercaseString] stringByReplacingCharactersInSet:badCharacters withString:@""];
	if (username.length)
		return username;
#if SYSTEM(IOS)
	return @"mobile";
#else
	return @"user";
#endif
}

+ (NSString *) defaultQuitMessage {
	return [[NSUserDefaults standardUserDefaults] stringForKey:@"JVQuitMessage"];
}

+ (NSStringEncoding) defaultEncoding {
	return [[NSUserDefaults standardUserDefaults] integerForKey:@"JVChatEncoding"];
}

#pragma mark -

- (void) setDisplayName:(NSString *) name {
	NSParameterAssert(name != nil);

	if ([name isEqualToString:self.displayName])
		return;

	[self setPersistentInformationObject:name forKey:@"description"];
}

- (NSString *) displayName {
	NSString *name = [self persistentInformationObjectForKey:@"description"];
	if (!name.length)
		return self.server;
	return name;
}

#pragma mark -

- (void) joinChatRoomNamed:(NSString *) room {
	room = [self properNameForChatRoomNamed:room];
	NSString *password = [[CQKeychain standardKeychain] passwordForServer:self.uniqueIdentifier area:room];
	[self joinChatRoomNamed:room withPassphrase:password];
}

#pragma mark -

- (void) setAutomaticJoinedRooms:(NSArray *) rooms {
	NSParameterAssert(rooms != nil);

	[self setPersistentInformationObject:rooms forKey:@"rooms"];
}

- (NSArray *) automaticJoinedRooms {
	return [self persistentInformationObjectForKey:@"rooms"];
}

#pragma mark -

- (void) setAutomaticCommands:(NSArray *) commands {
	NSParameterAssert(commands != nil);

	[self setPersistentInformationObject:commands forKey:@"commands"];
}

- (NSArray *) automaticCommands {
	return [self persistentInformationObjectForKey:@"commands"];
}

#pragma mark -

- (void) setAutomaticallyConnect:(BOOL) autoConnect {
	if (autoConnect == self.automaticallyConnect)
		return;

	[self setPersistentInformationObject:[NSNumber numberWithBool:autoConnect] forKey:@"automatic"];
}

- (BOOL) automaticallyConnect {
	return [[self persistentInformationObjectForKey:@"automatic"] boolValue];
}

#pragma mark -

- (void) savePasswordsToKeychain {
	[[CQKeychain standardKeychain] setPassword:self.nicknamePassword forServer:self.uniqueIdentifier area:[NSString stringWithFormat:@"Nickname %@", self.preferredNickname]];
	[[CQKeychain standardKeychain] setPassword:self.password forServer:self.uniqueIdentifier area:@"Server"];
}

- (void) loadPasswordsFromKeychain {
	NSString *password = nil;

	if ((password = [[CQKeychain standardKeychain] passwordForServer:self.uniqueIdentifier area:[NSString stringWithFormat:@"Nickname %@", self.preferredNickname]]) && password.length)
		self.nicknamePassword = password;

	if ((password = [[CQKeychain standardKeychain] passwordForServer:self.uniqueIdentifier area:@"Server"]) && password.length)
		self.password = password;
}

#pragma mark -

#if SYSTEM(IOS)
- (void) setMultitaskingSupported:(BOOL) multitaskingSupported {
	if (multitaskingSupported == self.multitaskingSupported)
		return;

	[self setPersistentInformationObject:[NSNumber numberWithBool:multitaskingSupported] forKey:@"multitasking"];
}

- (BOOL) multitaskingSupported {
	return [[self persistentInformationObjectForKey:@"multitasking"] boolValue];
}

#pragma mark -

- (void) setPushNotificationsEnabled:(BOOL) push {
	if (push == self.pushNotificationsEnabled)
		return;

	[self setPersistentInformationObject:[NSNumber numberWithBool:push] forKey:@"push"];
	
	[self sendPushNotificationCommands];
}

- (BOOL) pushNotificationsEnabled {
	return [[self persistentInformationObjectForKey:@"push"] boolValue];
}

#pragma mark -

- (BOOL) isTemporaryDirectConnection {
	return [[self persistentInformationObjectForKey:@"direct"] boolValue];
}

- (void) setTemporaryDirectConnection:(BOOL) direct {
	if (direct == self.temporaryDirectConnection)
		return;

	[self setPersistentInformationObject:[NSNumber numberWithBool:direct] forKey:@"direct"];
}

- (BOOL) isDirectConnection {
	return (self.bouncerType == MVChatConnectionNoBouncer);
}

#pragma mark -

- (void) setBouncerSettings:(CQBouncerSettings *) settings {
	self.bouncerIdentifier = settings.identifier;
}

- (CQBouncerSettings *) bouncerSettings {
	return [[CQConnectionsController defaultController] bouncerSettingsForIdentifier:self.bouncerIdentifier];
}

#pragma mark -

- (void) setBouncerIdentifier:(NSString *) identifier {
	if ([identifier isEqualToString:self.bouncerIdentifier])
		return;

	if (identifier.length)
		[self setPersistentInformationObject:identifier forKey:@"bouncerIdentifier"];
	else [self removePersistentInformationObjectForKey:@"bouncerIdentifier"];
}

- (NSString *) bouncerIdentifier {
	return [self persistentInformationObjectForKey:@"bouncerIdentifier"];
}

#pragma mark -

- (void) connectAppropriately {
	[self setPersistentInformationObject:[NSNumber numberWithBool:YES] forKey:@"tryBouncerFirst"];

	[self connect];
}

- (void) connectDirectly {
	[self removePersistentInformationObjectForKey:@"tryBouncerFirst"];

	self.temporaryDirectConnection = YES;

	[self connect];
}

#pragma mark -

- (void) sendPushNotificationCommands {
	if (!self.connected && self.status != MVChatConnectionConnectingStatus)
		return;

	NSString *deviceToken = [CQColloquyApplication sharedApplication].deviceToken;
	if (!deviceToken.length)
		return;

	NSNumber *currentState = [self persistentInformationObjectForKey:@"pushState"];

	CQBouncerSettings *settings = self.bouncerSettings;
	if ((!settings || settings.pushNotifications) && self.pushNotifications && (!currentState || ![currentState boolValue])) {
		[self setPersistentInformationObject:[NSNumber numberWithBool:YES] forKey:@"pushState"];

		[self sendRawMessageWithFormat:@"PUSH add-device %@ :%@", deviceToken, [UIDevice currentDevice].name];

		[self sendRawMessage:@"PUSH service colloquy.mobi 7906"];

		[self sendRawMessageWithFormat:@"PUSH connection %@ :%@", self.uniqueIdentifier, self.displayName];

		NSArray *highlightWords = [CQColloquyApplication sharedApplication].highlightWords;
		for (NSString *highlightWord in highlightWords)
			[self sendRawMessageWithFormat:@"PUSH highlight-word :%@", highlightWord];

		NSString *sound = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQSoundOnHighlight"];
		if (sound.length && ![sound isEqualToString:@"None"])
			[self sendRawMessageWithFormat:@"PUSH highlight-sound :%@.aiff", sound];
		else [self sendRawMessageWithFormat:@"PUSH highlight-sound none"];

		sound = [[NSUserDefaults standardUserDefaults] stringForKey:@"CQSoundOnPrivateMessage"];
		if (sound.length && ![sound isEqualToString:@"None"])
			[self sendRawMessageWithFormat:@"PUSH message-sound :%@.aiff", sound];
		else [self sendRawMessageWithFormat:@"PUSH message-sound none"];

		[self sendRawMessage:@"PUSH end-device"];
	} else if ((!currentState || [currentState boolValue])) {
		[self setPersistentInformationObject:[NSNumber numberWithBool:NO] forKey:@"pushState"];

		[self sendRawMessageWithFormat:@"PUSH remove-device :%@", deviceToken];
	}
}
#endif // SYSTEM(IOS)
@end
