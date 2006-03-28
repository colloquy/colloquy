#import "MVChatUserWatchRule.h"
#import "MVChatUser.h"

#import <AGRegex/AGRegex.h>

NSString *MVChatUserWatchRuleMatchedNotification = @"MVChatUserWatchRuleMatchedNotification";

@implementation MVChatUserWatchRule
- (BOOL) matchChatUser:(MVChatUser *) user {
	if( ! user ) return NO;

	@synchronized( _matchedChatUsers ) {
		if( [_matchedChatUsers containsObject:user] )
			return YES;
	}

	if( _nicknameRegex && ! [_nicknameRegex findInString:[user nickname]] ) return NO;
	if( [_nickname length] && ! [_nickname isEqualToString:[user nickname]] ) return NO;

	if( _usernameRegex && ! [_usernameRegex findInString:[user username]] ) return NO;
	if( [_username length] && ! [_username isEqualToString:[user username]] ) return NO;

	if( _addressRegex && ! [_addressRegex findInString:[user address]] ) return NO;
	if( [_address length] && ! [_address isEqualToString:[user address]] ) return NO;

	if( _realNameRegex && ! [_realNameRegex findInString:[user realName]] ) return NO;
	if( [_realName length] && ! [_realName isEqualToString:[user realName]] ) return NO;

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
	} return nil;
}

- (NSString *) nickname {
	return [[_nickname retain] autorelease];
}

- (void) setNickname:(NSString *) nickname {
	id old = _nickname;
	_nickname = [nickname copyWithZone:nil];
	[old release];

	old = _nicknameRegex;
	if( _nickname && ( [_nickname length] > 2 ) && [_nickname hasPrefix:@"/"] && [_nickname hasSuffix:@"/"] )
		_nicknameRegex = [[AGRegex alloc] initWithPattern:[_nickname substringWithRange:NSMakeRange( 1, [_nickname length] - 2)] options:AGRegexCaseInsensitive];
	else _nicknameRegex = nil;
	[old release];
}

- (NSString *) realName {
	return [[_realName retain] autorelease];
}

- (void) setRealName:(NSString *) realName {
	id old = _realName;
	_realName = [realName copyWithZone:nil];
	[old release];

	old = _realNameRegex;
	if( _realName && ( [_realName length] > 2 ) && [_realName hasPrefix:@"/"] && [_realName hasSuffix:@"/"] )
		_realNameRegex = [[AGRegex alloc] initWithPattern:[_realName substringWithRange:NSMakeRange( 1, [_realName length] - 2)] options:AGRegexCaseInsensitive];
	else _realNameRegex = nil;
	[old release];
}

- (NSString *) username {
	return [[_username retain] autorelease];
}

- (void) setUsername:(NSString *) username {
	id old = _username;
	_username = [username copyWithZone:nil];
	[old release];

	old = _usernameRegex;
	if( _username && ( [_username length] > 2 ) && [_username hasPrefix:@"/"] && [_username hasSuffix:@"/"] )
		_usernameRegex = [[AGRegex alloc] initWithPattern:[_username substringWithRange:NSMakeRange( 1, [_username length] - 2)] options:AGRegexCaseInsensitive];
	else _usernameRegex = nil;
	[old release];
}

- (NSString *) address {
	return [[_address retain] autorelease];
}

- (void) setAddress:(NSString *) address {
	id old = _address;
	_address = [address copyWithZone:nil];
	[old release];

	old = _addressRegex;
	if( _address && ( [_address length] > 2 ) && [_address hasPrefix:@"/"] && [_address hasSuffix:@"/"] )
		_addressRegex = [[AGRegex alloc] initWithPattern:[_address substringWithRange:NSMakeRange( 1, [_address length] - 2)] options:AGRegexCaseInsensitive];
	else _addressRegex = nil;
	[old release];
}

- (NSData *) publicKey {
	return [[_publicKey retain] autorelease];
}

- (void) setPublicKey:(NSData *) publicKey {
	id old = _publicKey;
	_publicKey = [publicKey copyWithZone:nil];
	[old release];
}

- (NSString *) fingerprint {
	return [[_fingerprint retain] autorelease];
}

- (void) setFingerprint:(NSString *) fingerprint {
	id old = _fingerprint;
	_fingerprint = [fingerprint copyWithZone:nil];
	[old release];
}
@end
