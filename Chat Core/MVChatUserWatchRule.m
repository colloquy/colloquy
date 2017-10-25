#import "MVChatUserWatchRule.h"

#import "MVChatUser.h"
#import "MVChatUserPrivate.h"
#import "MVUtilities.h"
#import "NSNotificationAdditions.h"
#import "NSStringAdditions.h"

#import "MVChatConnection.h"

NS_ASSUME_NONNULL_BEGIN

NSString *MVChatUserWatchRuleMatchedNotification = @"MVChatUserWatchRuleMatchedNotification";
NSString *MVChatUserWatchRuleRemovedMatchedUserNotification = @"MVChatUserWatchRuleRemovedMatchedUserNotification";

@implementation MVChatUserWatchRule {
	NSMutableSet *_matchedChatUsers;
	NSString *_nickname;
	NSString *_realName;
	NSString *_username;
	NSString *_address;
	NSData *_publicKey;
	NSArray <NSString *> *_applicableServerDomains;
	BOOL _nicknameIsRegex;
	BOOL _realNameIsRegex;
	BOOL _usernameIsRegex;
	BOOL _addressIsRegex;
	BOOL _interim;
}
@synthesize usernameIsRegularExpression = _usernameIsRegex;
@synthesize address = _address;
@synthesize username = _username;
@synthesize addressIsRegularExpression = _addressIsRegex;
@synthesize nickname = _nickname;
@synthesize nicknameIsRegularExpression = _nicknameIsRegex;
@synthesize realNameIsRegularExpression = _realNameIsRegex;
@synthesize realName = _realName;

- (instancetype) initWithDictionaryRepresentation:(NSDictionary *) dictionary {
	if( ( self = [super init] ) ) {
		[self setUsername:dictionary[@"username"]];
		[self setNickname:dictionary[@"nickname"]];
		[self setRealName:dictionary[@"realName"]];
		[self setAddress:dictionary[@"address"]];
		[self setPublicKey:dictionary[@"publicKey"]];
		[self setInterim:[dictionary[@"interim"] boolValue]];
		[self setApplicableServerDomains:dictionary[@"applicableServerDomains"]];
	}

	return self;
}

- (id) copyWithZone:(NSZone * __nullable) zone {
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
	if( _username ) dictionary[@"username"] = [self username];
	if( _nickname ) dictionary[@"nickname"] = [self nickname];
	if( _realName ) dictionary[@"realName"] = [self realName];
	if( _address ) dictionary[@"address"] = [self address];
	if( _publicKey ) dictionary[@"publicKey"] = _publicKey;
	if( _interim ) dictionary[@"interim"] = @(_interim);
	if( _applicableServerDomains ) dictionary[@"applicableServerDomains"] = _applicableServerDomains;
	return [dictionary copy];
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
	if( _nicknameIsRegex && _nickname && ! [string isMatchedByRegex:_nickname options:NSRegularExpressionCaseInsensitive inRange:maxRange error:NULL] ) return NO;
	if( ! _nicknameIsRegex && _nickname && _nickname.length && ! [_nickname isEqualToString:string] ) return NO;

	string = [user username];
	if( _usernameIsRegex && _username && ! [string isMatchedByRegex:_username options:NSRegularExpressionCaseInsensitive inRange:maxRange error:NULL] ) return NO;
	if( ! _usernameIsRegex && _username && _username.length && ! [_username isEqualToString:string] ) return NO;

	string = [user address];
	if( _addressIsRegex && _address && ! [string isMatchedByRegex:_address options:NSRegularExpressionCaseInsensitive inRange:maxRange error:NULL] ) return NO;
	if( ! _addressIsRegex && _address && _address.length && ! [_address isEqualToString:string] ) return NO;

	string = [user realName];
	if( _realNameIsRegex && _realName && ! [string isMatchedByRegex:_realName options:NSRegularExpressionCaseInsensitive inRange:maxRange error:NULL] ) return NO;
	if( ! _realNameIsRegex && _realName && _realName.length && ! [_realName isEqualToString:string] ) return NO;

	NSData *data = [user publicKey];
	if( _publicKey && _publicKey.length && ! [_publicKey isEqualToData:data] ) return NO;

	@synchronized( _matchedChatUsers ) {
		if( ! [_matchedChatUsers containsObject:user] ) {
			[_matchedChatUsers addObject:user];
			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatUserWatchRuleMatchedNotification object:self userInfo:@{ @"user": user }];
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
			[_matchedChatUsers removeObject:user];
			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatUserWatchRuleRemovedMatchedUserNotification object:self userInfo:@{ @"user": user }];
		}
	}
}

- (void) removeMatchedUsersForConnection:(MVChatConnection *) connection {
	@synchronized( _matchedChatUsers ) {
		for( MVChatUser *user in [_matchedChatUsers copy] ) {
			if( [[user connection] isEqual:connection] ) {
				[_matchedChatUsers removeObject:user];
				[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVChatUserWatchRuleRemovedMatchedUserNotification object:self userInfo:@{ @"user": user }];
			}
		}
	}
}

- (NSString *__nullable) nickname {
	return (_nicknameIsRegex && _nickname ? [NSString stringWithFormat:@"/%@/", _nickname] : _nickname);
}

- (void) setNickname:(NSString *__nullable) newNickname {
	_nicknameIsRegex = ( newNickname.length > 2 && [newNickname hasPrefix:@"/"] && [newNickname hasSuffix:@"/"] );

	if( _nicknameIsRegex )
		newNickname = [newNickname substringWithRange:NSMakeRange( 1, newNickname.length - 2)];

	MVSafeCopyAssign( _nickname, newNickname );
}

- (NSString *__nullable) realName {
	return (_realNameIsRegex && _realName ? [NSString stringWithFormat:@"/%@/", _realName] : _realName);
}

- (void) setRealName:(NSString *__nullable) newRealName {
	_realNameIsRegex = ( newRealName.length > 2 && [newRealName hasPrefix:@"/"] && [newRealName hasSuffix:@"/"] );

	if( _realNameIsRegex )
		newRealName = [newRealName substringWithRange:NSMakeRange( 1, newRealName.length - 2)];

	MVSafeCopyAssign( _realName, newRealName );
}

- (NSString *__nullable) username {
	return (_usernameIsRegex && _username ? [NSString stringWithFormat:@"/%@/", _username] : _username);
}

- (void) setUsername:(NSString *__nullable) newUsername {
	_usernameIsRegex = ( newUsername.length > 2 && [newUsername hasPrefix:@"/"] && [newUsername hasSuffix:@"/"] );

	if( _usernameIsRegex )
		newUsername = [newUsername substringWithRange:NSMakeRange( 1, newUsername.length - 2)];

	MVSafeCopyAssign( _username, newUsername );
}

- (NSString *__nullable) address {
	return (_addressIsRegex && _address ? [NSString stringWithFormat:@"/%@/", _address] : _address);
}

- (void) setAddress:(NSString *__nullable) newAddress {
	_addressIsRegex = ( newAddress.length > 2 && [newAddress hasPrefix:@"/"] && [newAddress hasSuffix:@"/"] );

	if( _addressIsRegex )
		newAddress = [newAddress substringWithRange:NSMakeRange( 1, newAddress.length - 2)];

	MVSafeCopyAssign( _address, newAddress );
}

@end

NS_ASSUME_NONNULL_END
