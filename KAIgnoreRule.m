//  KAIgnoreRule.m
//  Colloquy
//  Created by Karl Adam on Thu Apr 15 2004.

#import <Cocoa/Cocoa.h>
#import <AGRegex/AGRegex.h>
#import <ChatCore/MVChatConnection.h>

#import "KAIgnoreRule.h"
#import "JVChatWindowController.h"
#import "JVDirectChat.h"

@implementation KAIgnoreRule
+ (id) ruleForUser:(NSString *) user message:(NSString *)message inRooms:(NSArray *) rooms usesRegex:(BOOL)regex isPermanent:(BOOL) permanent {
	return [[[KAIgnoreRule alloc] initForUser:user message:message inRooms:rooms usesRegex:regex isPermanent:permanent] autorelease];
}

- (id) initForUser:(NSString *) user message:(NSString *)message inRooms:(NSArray *) rooms usesRegex:(BOOL)regex isPermanent:(BOOL) permanent {
	if( ( self = [super init] ) ) {
		_ignoredUser = [user copy];
		_ignoredMessage = [message copy];
		_inRooms = [rooms copy];
		_userRegex = nil;
		_messageRegex = nil;
		_permanent = permanent;

		if( regex ) {
			if( user ) _userRegex = [[AGRegex alloc] initWithPattern:user options:AGRegexCaseInsensitive];
			if( message ) _messageRegex = [[AGRegex alloc] initWithPattern:message options:AGRegexCaseInsensitive];
		}
	}

	return self;
}

- (id) initWithCoder:(NSCoder *) coder {
	if( [coder allowsKeyedCoding] )
		return [self initForUser:[coder decodeObjectForKey:@"KAIgnoreUser"] message:[coder decodeObjectForKey:@"KAIgnoreMessage"] inRooms:[coder decodeObjectForKey:@"KAIgnoreRooms"] usesRegex:[coder decodeBoolForKey:@"KAIgnoreUseRegex"] isPermanent:[coder decodeBoolForKey:@"KAIgnorePermanent"]];
	else [NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
	return nil;
}

- (void) encodeWithCoder:(NSCoder *)coder {
	if( [coder allowsKeyedCoding] ) {
		[coder encodeObject:_ignoredUser forKey:@"KAIgnoreUser"];
		[coder encodeObject:_ignoredMessage forKey:@"KAIgnoreMessage"];
		[coder encodeObject:_inRooms forKey:@"KAIgnoreRooms"];
		[coder encodeBool:( _userRegex || _messageRegex ) forKey:@"KAIgnoreUseRegex"];
		[coder encodeBool:_permanent forKey:@"KAIgnorePermanent"];
	} else [NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
}

- (void) dealloc {
	[_ignoredUser release];
	[_ignoredMessage release];
	[_inRooms release];
	[_userRegex release];
	[_messageRegex release];
	[super dealloc];
}

- (JVIgnoreMatchResult) matchUser:(NSString *) user message:(NSString *) message inView:(id <JVChatViewController>) view {
	if( [view isKindOfClass:[JVDirectChat class]] && ( [_inRooms containsObject:[(JVDirectChat *)view targetURL]] || [_inRooms containsObject:[[view connection] url]] ) ) {
		BOOL userFound = NO, messageFound = NO;
		BOOL userRequired = ( _userRegex || _ignoredUser ), messageRequired = ( _messageRegex || _ignoredMessage );

		if( _userRegex && [_userRegex findInString:user] ) userFound = YES;
		else if( _ignoredUser ) userFound = [_ignoredUser isEqualToString:user];

		if( _messageRegex && [_messageRegex findInString:message] ) messageFound = YES;
		else if( _ignoredMessage ) messageFound = [_ignoredMessage isEqualToString:message];

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

- (BOOL) isPermanent {
	return _permanent;
}
@end