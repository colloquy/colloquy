//  KAIgnoreRule.m
//  Colloquy
//  Created by Karl Adam on Thu Apr 15 2004.

#import "KAIgnoreRule.h"
#import "JVChatWindowController.h"
#import "JVDirectChatPanel.h"

@implementation KAIgnoreRule
+ (id) ruleForUser:(NSString *) user message:(NSString *) message inRooms:(NSArray *) rooms isPermanent:(BOOL) permanent friendlyName:(NSString *) friendlyName {
	return [[[KAIgnoreRule alloc] initForUser:user message:message inRooms:rooms isPermanent:permanent friendlyName:friendlyName] autorelease];
}

#pragma mark -

- (id) initForUser:(NSString *) user message:(NSString *) message inRooms:(NSArray *) rooms isPermanent:(BOOL) permanent friendlyName:(NSString *) friendlyName {
	if( ( self = [super init] ) ) {
		_userRegex = nil;
		_messageRegex = nil;
		_ignoredUser = nil;
		_ignoredMessage = nil;

		[self setUser:user];
		[self setMessage:message];

		_rooms = [rooms copyWithZone:[self zone]];
		_friendlyName = [friendlyName copyWithZone:[self zone]];
		_permanent = permanent;
	}

	return self;
}

- (id) initWithCoder:(NSCoder *) coder {
	if( [coder allowsKeyedCoding] )
		return [self initForUser:[coder decodeObjectForKey:@"KAIgnoreUser"] message:[coder decodeObjectForKey:@"KAIgnoreMessage"] inRooms:[coder decodeObjectForKey:@"KAIgnoreRooms"] isPermanent:[coder decodeBoolForKey:@"KAIgnorePermanent"] friendlyName:[coder decodeObjectForKey:@"KAIgnoreFriendlyName"]];
	[NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
	return nil; // Never reached, but gcc and clang both warn about "Control reaches end of non-void function"
}

- (void) encodeWithCoder:(NSCoder *)coder {
	if( [coder allowsKeyedCoding] ) {
		[coder encodeObject:_ignoredUser forKey:@"KAIgnoreUser"];
		[coder encodeObject:_ignoredMessage forKey:@"KAIgnoreMessage"];
		[coder encodeObject:_rooms forKey:@"KAIgnoreRooms"];
		[coder encodeBool:_permanent forKey:@"KAIgnorePermanent"];
		[coder encodeObject:_friendlyName forKey:@"KAIgnoreFriendlyName"];
	}

	[NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
}

- (void) dealloc {
	[_ignoredUser release];
	[_ignoredMessage release];
	[_rooms release];
	[_userRegex release];
	[_messageRegex release];
	[_friendlyName release];

	_ignoredUser = nil;
	_ignoredMessage = nil;
	_rooms = nil;
	_userRegex = nil;
	_messageRegex = nil;
	_friendlyName = nil;

	[super dealloc];
}

#pragma mark -

- (JVIgnoreMatchResult) matchUser:(MVChatUser *) user message:(NSString *) message inView:(id <JVChatViewController>) view {
	if( ! [_rooms count] || ! view || ( [view isKindOfClass:[JVDirectChatPanel class]] && [_rooms containsObject:[[(JVDirectChatPanel *)view target] displayName]] ) ) {
		BOOL userFound = NO;
		BOOL messageFound = NO;
		BOOL userRequired = ( _userRegex || [_ignoredUser length] );
		BOOL messageRequired = ( _messageRegex || [_ignoredMessage length] );

		if( _userRegex && [_userRegex findInString:[user nickname]] ) userFound = YES;
		else if( [_ignoredUser length] ) userFound = [_ignoredUser isEqualToString:[user nickname]];

		if( _messageRegex && message && [_messageRegex findInString:message] ) messageFound = YES;
		else if( [_ignoredMessage length] && message ) messageFound = ( [message rangeOfString:_ignoredMessage options:NSCaseInsensitiveSearch].location != NSNotFound );

		if( userRequired ) {
			if( ! userFound || ( messageRequired && ! messageFound ) ) return JVNotIgnored;
			else return JVUserIgnored;
		} else {
			if( messageRequired && messageFound ) return JVMessageIgnored;
			else return JVNotIgnored;
		}
	}

	return JVNotIgnored;
}

#pragma mark -

- (BOOL) isPermanent {
	return _permanent;
}

- (void) setPermanent:(BOOL) permanent {
	_permanent = permanent;
}

#pragma mark -

- (NSString *) friendlyName {
	if( ! [_friendlyName length] ) {
		if( [_ignoredUser length] && [_ignoredMessage length] ) return [NSString stringWithFormat:@"%@ - %@", _ignoredUser, _ignoredMessage];
		else if( [_ignoredUser length] ) return _ignoredUser;
		else if( [_ignoredMessage length] ) return _ignoredMessage;
		else return NSLocalizedString( @"Blank Ignore", "blank ignore name" );
	} else return _friendlyName;
}

- (void) setFriendlyName:(NSString *) friendlyName {
    if( _friendlyName != friendlyName ) {
        [_friendlyName release];
        _friendlyName = [friendlyName copyWithZone:[self zone]];
    }
}

#pragma mark -

- (NSArray *) rooms {
    return _rooms;
}

- (void) setRooms:(NSArray *) rooms {
    [_rooms autorelease];
	_rooms = [rooms copyWithZone:[self zone]];
}

#pragma mark -

- (NSString *) message {
    return _ignoredMessage;
}

- (void) setMessage:(NSString *) message {
    if( _ignoredMessage != message ) {
        [_ignoredMessage release];
        _ignoredMessage = [message copyWithZone:[self zone]];
    }

	[_messageRegex release];
	_messageRegex = nil;

	if( message && ( [message length] > 2 ) && [message hasPrefix:@"/"] && [message hasSuffix:@"/"] )
		_messageRegex = [[AGRegex alloc] initWithPattern:[message substringWithRange:NSMakeRange( 1, [message length] - 2)] options:AGRegexCaseInsensitive];
}

#pragma mark -

- (NSString *) user {
    return _ignoredUser;
}

- (void) setUser:(NSString *) user {
    if( _ignoredUser != user ) {
        [_ignoredUser release];
        _ignoredUser = [user copyWithZone:[self zone]];
    }

	[_userRegex release];
	_userRegex = nil;

	if( user && ( [user length] > 2 ) && [user hasPrefix:@"/"] && [user hasSuffix:@"/"] )
		_userRegex = [[AGRegex alloc] initWithPattern:[user substringWithRange:NSMakeRange( 1, [user length] - 2 )] options:AGRegexCaseInsensitive];
}
@end
