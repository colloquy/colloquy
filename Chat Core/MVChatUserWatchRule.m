#import "MVChatUserWatchRule.h"
#import "MVChatUser.h"
#import "MVChatUserPrivate.h"
#import "NSNotificationAdditions.h"

#import <AGRegex/AGRegex.h>

NSString *MVChatUserWatchRuleMatchedNotification = @"MVChatUserWatchRuleMatchedNotification";

@implementation MVChatUserWatchRule
- (id) initWithDictionaryRepresentation:(NSDictionary *) dictionary {
	if( ( self = [super init] ) ) {
		[self setUsername:[dictionary objectForKey:@"username"]];
		[self setNickname:[dictionary objectForKey:@"nickname"]];
		[self setRealName:[dictionary objectForKey:@"realName"]];
		[self setAddress:[dictionary objectForKey:@"address"]];
		[self setPublicKey:[dictionary objectForKey:@"publicKey"]];
	}

	return self;
}

- (NSDictionary *) dictionaryRepresentation {
	NSMutableDictionary *dictionary = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:5];
	if( _username ) [dictionary setObject:_nickname forKey:@"username"];
	if( _nickname ) [dictionary setObject:_nickname forKey:@"nickname"];
	if( _realName ) [dictionary setObject:_nickname forKey:@"realName"];
	if( _address ) [dictionary setObject:_nickname forKey:@"address"];
	if( _publicKey ) [dictionary setObject:_nickname forKey:@"publicKey"];
	return [dictionary autorelease];
}

- (BOOL) matchChatUser:(MVChatUser *) user {
	if( ! user ) return NO;

	@synchronized( _matchedChatUsers ) {
		if( [_matchedChatUsers containsObject:user] )
			return YES;
	}

	NSString *string = [user nickname];
	if( _nicknameRegex && string && ! [_nicknameRegex findInString:string] ) return NO;
	if( ! _nicknameRegex && _nickname && string && [_nickname length] && ! [_nickname isEqualToString:string] ) return NO;

	string = [user username];
	if( _usernameRegex && string && ! [_usernameRegex findInString:string] ) return NO;
	if( ! _usernameRegex && _username && string && [_username length] && ! [_username isEqualToString:string] ) return NO;

	string = [user address];
	if( _addressRegex && string && ! [_addressRegex findInString:string] ) return NO;
	if( ! _addressRegex && _address && string && [_address length] && ! [_address isEqualToString:string] ) return NO;

	string = [user realName];
	if( _realNameRegex && string && ! [_realNameRegex findInString:string] ) return NO;
	if( ! _realNameRegex && _realName && string && [_realName length] && ! [_realName isEqualToString:string] ) return NO;

	NSData *data = [user publicKey];
	if( _publicKey && data && [_publicKey length] && ! [_publicKey isEqualToData:data] ) return NO;

	@synchronized( _matchedChatUsers ) {
		if( ! [_matchedChatUsers containsObject:user] ) {
			[user _setWatched:YES];
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

- (BOOL) nicknameIsRegularExpression {
	return ( _nicknameRegex ? YES : NO );
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

- (BOOL) realNameIsRegularExpression {
	return ( _realNameRegex ? YES : NO );
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

- (BOOL) usernameIsRegularExpression {
	return ( _usernameRegex ? YES : NO );
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

- (BOOL) addressIsRegularExpression {
	return ( _addressRegex ? YES : NO );
}

- (NSData *) publicKey {
	return [[_publicKey retain] autorelease];
}

- (void) setPublicKey:(NSData *) publicKey {
	id old = _publicKey;
	_publicKey = [publicKey copyWithZone:nil];
	[old release];
}
@end
