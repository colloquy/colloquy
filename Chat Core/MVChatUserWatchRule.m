#import "MVChatUserWatchRule.h"

#import "MVChatUser.h"
#import "MVChatUserPrivate.h"
#import "MVUtilities.h"
#import "NSNotificationAdditions.h"
#import "RegexKitLite.h"

NSString *MVChatUserWatchRuleMatchedNotification = @"MVChatUserWatchRuleMatchedNotification";
NSString *MVChatUserWatchRuleRemovedMatchedUserNotification = @"MVChatUserWatchRuleRemovedMatchedUserNotification";

@implementation MVChatUserWatchRule
- (id) initWithDictionaryRepresentation:(NSDictionary *) dictionary {
	if( ( self = [super init] ) ) {
		[self setUsername:[dictionary objectForKey:@"username"]];
		[self setNickname:[dictionary objectForKey:@"nickname"]];
		[self setRealName:[dictionary objectForKey:@"realName"]];
		[self setAddress:[dictionary objectForKey:@"address"]];
		[self setPublicKey:[dictionary objectForKey:@"publicKey"]];
		[self setInterim:[[dictionary objectForKey:@"interim"] boolValue]];
		[self setApplicableServerDomains:[dictionary objectForKey:@"applicableServerDomains"]];
	}

	return self;
}

- (void) dealloc {
	[_matchedChatUsers release];
	[_nickname release];
	[_realName release];
	[_username release];
	[_address release];
	[_publicKey release];
	[_applicableServerDomains release];

	[super dealloc];
}

- (id) copyWithZone:(NSZone *) zone {
	MVChatUserWatchRule *copy = [[MVChatUserWatchRule alloc] init];

	MVSafeCopyAssign( copy->_username, _username );
	MVSafeCopyAssign( copy->_nickname, _nickname );
	MVSafeCopyAssign( copy->_realName, _realName );
	MVSafeCopyAssign( copy->_address, _address );
	MVSafeCopyAssign( copy->_publicKey, _publicKey );
	MVSafeCopyAssign( copy->_applicableServerDomains, _applicableServerDomains );

	copy->_interim = _interim;
	copy->_nicknameIsRegex = _nicknameIsRegex;
	copy->_usernameIsRegex = _usernameIsRegex;
	copy->_realNameIsRegex = _realNameIsRegex;
	copy->_addressIsRegex = _addressIsRegex;

	return copy;
}

- (NSDictionary *) dictionaryRepresentation {
	NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithCapacity:5];
	if( _username ) [dictionary setObject:[self username] forKey:@"username"];
	if( _nickname ) [dictionary setObject:[self nickname] forKey:@"nickname"];
	if( _realName ) [dictionary setObject:[self realName] forKey:@"realName"];
	if( _address ) [dictionary setObject:[self address] forKey:@"address"];
	if( _publicKey ) [dictionary setObject:_publicKey forKey:@"publicKey"];
	if( _interim ) [dictionary setObject:[NSNumber numberWithBool:_interim] forKey:@"interim"];
	if( _applicableServerDomains ) [dictionary setObject:_applicableServerDomains forKey:@"applicableServerDomains"];
	return [dictionary autorelease];
}

- (BOOL) isEqual:(id) object {
	if( object == self ) return YES;
	if( ! object || ! [object isKindOfClass:[self class]] ) return NO;
	return [self isEqualToChatUserWatchRule:object];
}

- (BOOL) isEqualToChatUserWatchRule:(MVChatUserWatchRule *) anotherRule {
	if( ! anotherRule ) return NO;
	if( anotherRule == self ) return YES;

	if( [self nicknameIsRegularExpression] != [anotherRule nicknameIsRegularExpression] )
		return NO;

	if( [self usernameIsRegularExpression] != [anotherRule usernameIsRegularExpression] )
		return NO;

	if( [self realNameIsRegularExpression] != [anotherRule realNameIsRegularExpression] )
		return NO;

	if( [self addressIsRegularExpression] != [anotherRule addressIsRegularExpression] )
		return NO;

	if( ( ! [self nickname] && ! [anotherRule nickname] ) || ! [[self nickname] isEqualToString:[anotherRule nickname]] )
		return NO;

	if( ( ! [self username] && ! [anotherRule username] ) || ! [[self username] isEqualToString:[anotherRule username]] )
		return NO;

	if( ( ! [self realName] && ! [anotherRule realName] ) || ! [[self realName] isEqualToString:[anotherRule realName]] )
		return NO;

	if( ( ! [self address] && ! [anotherRule address] ) || ! [[self address] isEqualToString:[anotherRule address]] )
		return NO;

	if( ( ! [self publicKey] && ! [anotherRule publicKey] ) || ! [[self publicKey] isEqualToData:[anotherRule publicKey]] )
		return NO;

	return YES;
}

- (BOOL) matchChatUser:(MVChatUser *) user {
	if( ! user ) return NO;

	if( ! _matchedChatUsers )
		_matchedChatUsers = [[NSMutableSet alloc] initWithCapacity:10];

	NSRange maxRange = NSMakeRange(0, NSUIntegerMax);

	@synchronized( _matchedChatUsers ) {
		if( [_matchedChatUsers containsObject:user] )
			return YES;
	}

	NSString *string = [user nickname];
	if( _nicknameIsRegex && _nickname && ! [string isMatchedByRegex:_nickname options:RKLCaseless inRange:maxRange error:NULL] ) return NO;
	if( ! _nicknameIsRegex && _nickname && _nickname.length && ! [_nickname isEqualToString:string] ) return NO;

	string = [user username];
	if( _usernameIsRegex && _username && ! [string isMatchedByRegex:_username options:RKLCaseless inRange:maxRange error:NULL] ) return NO;
	if( ! _usernameIsRegex && _username && _username.length && ! [_username isEqualToString:string] ) return NO;

	string = [user address];
	if( _addressIsRegex && _address && ! [string isMatchedByRegex:_address options:RKLCaseless inRange:maxRange error:NULL] ) return NO;
	if( ! _addressIsRegex && _address && _address.length && ! [_address isEqualToString:string] ) return NO;

	string = [user realName];
	if( _realNameIsRegex && _realName && ! [string isMatchedByRegex:_realName options:RKLCaseless inRange:maxRange error:NULL] ) return NO;
	if( ! _realNameIsRegex && _realName && _realName.length && ! [_realName isEqualToString:string] ) return NO;

	NSData *data = [user publicKey];
	if( _publicKey && _publicKey.length && ! [_publicKey isEqualToData:data] ) return NO;

	@synchronized( _matchedChatUsers ) {
		if( ! [_matchedChatUsers containsObject:user] ) {
			[_matchedChatUsers addObject:user];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatUserWatchRuleMatchedNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", nil]];
		}
	}

	return YES;
}

- (NSSet *) matchedChatUsers {
	@synchronized( _matchedChatUsers ) {
		return [NSSet setWithSet:_matchedChatUsers];
	}
}

- (void) removeMatchedUser:(MVChatUser *) user {
	@synchronized( _matchedChatUsers ) {
		if( [_matchedChatUsers containsObject:user] ) {
			[user retain];
			[_matchedChatUsers removeObject:user];
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatUserWatchRuleRemovedMatchedUserNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", nil]];
			[user release];
		}
	}
}

- (void) removeMatchedUsersForConnection:(MVChatConnection *) connection {
	@synchronized( _matchedChatUsers ) {
		for( MVChatUser *user in [[_matchedChatUsers copy] autorelease] ) {
			if( [[user connection] isEqual:connection] ) {
				[user retain];
				[_matchedChatUsers removeObject:user];
				[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVChatUserWatchRuleRemovedMatchedUserNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:user, @"user", nil]];
				[user release];
			}
		}
	}
}

- (NSString *) nickname {
	return (_nicknameIsRegex && _nickname ? [NSString stringWithFormat:@"/%@/", _nickname] : _nickname);
}

- (void) setNickname:(NSString *) newNickname {
	_nicknameIsRegex = ( newNickname.length > 2 && [newNickname hasPrefix:@"/"] && [newNickname hasSuffix:@"/"] );

	if( _nicknameIsRegex )
		newNickname = [newNickname substringWithRange:NSMakeRange( 1, newNickname.length - 2)];

	MVSafeCopyAssign( _nickname, newNickname );
}

- (BOOL) nicknameIsRegularExpression {
	return _nicknameIsRegex;
}

- (NSString *) realName {
	return (_realNameIsRegex && _realName ? [NSString stringWithFormat:@"/%@/", _realName] : _realName);
}

- (void) setRealName:(NSString *) newRealName {
	_realNameIsRegex = ( newRealName.length > 2 && [newRealName hasPrefix:@"/"] && [newRealName hasSuffix:@"/"] );

	if( _realNameIsRegex )
		newRealName = [newRealName substringWithRange:NSMakeRange( 1, newRealName.length - 2)];

	MVSafeCopyAssign( _realName, newRealName );
}

- (BOOL) realNameIsRegularExpression {
	return _realNameIsRegex;
}

- (NSString *) username {
	return (_usernameIsRegex && _username ? [NSString stringWithFormat:@"/%@/", _username] : _username);
}

- (void) setUsername:(NSString *) newUsername {
	_usernameIsRegex = ( newUsername.length > 2 && [newUsername hasPrefix:@"/"] && [newUsername hasSuffix:@"/"] );

	if( _usernameIsRegex )
		newUsername = [newUsername substringWithRange:NSMakeRange( 1, newUsername.length - 2)];

	MVSafeCopyAssign( _username, newUsername );
}

- (BOOL) usernameIsRegularExpression {
	return _usernameIsRegex;
}

- (NSString *) address {
	return (_addressIsRegex && _address ? [NSString stringWithFormat:@"/%@/", _address] : _address);
}

- (void) setAddress:(NSString *) newAddress {
	_addressIsRegex = ( newAddress.length > 2 && [newAddress hasPrefix:@"/"] && [newAddress hasSuffix:@"/"] );

	if( _addressIsRegex )
		newAddress = [newAddress substringWithRange:NSMakeRange( 1, newAddress.length - 2)];

	MVSafeCopyAssign( _address, newAddress );
}

- (BOOL) addressIsRegularExpression {
	return _addressIsRegex;
}

- (NSData *) publicKey {
	return _publicKey;
}

- (void) setPublicKey:(NSData *) publicKey {
	MVSafeCopyAssign( _publicKey, publicKey );
}

- (BOOL) isInterim {
	return _interim;
}

- (void) setInterim:(BOOL) interim {
	_interim = interim;
}

- (NSArray *) applicableServerDomains {
	return _applicableServerDomains;
}

- (void) setApplicableServerDomains:(NSArray *) serverDomains {
	MVSafeCopyAssign( _applicableServerDomains, serverDomains );
}
@end
