//  KAConnectionHandler.m
//  Colloquy
//  Created by Karl Adam on Thu Apr 15 2004.

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/NSAttributedStringAdditions.h>

#import "KAIgnoreRule.h"

@implementation KAInternalIgnoreRule
- (id) initWithString:(NSString *)inString inRooms:(NSArray *)inRooms usesRegex:(BOOL) inRegex ignoreMember:(BOOL) inMemberIgnore {
	if ( self = [super init] ) {
		_ignoredKey = [inString retain];
		_inChannels	= [inRooms retain];
		
		_regex		= inRegex;
		_memberIgnore = inMemberIgnore;
	}
	
	return self;
}

+ (id) ruleWithString:(NSString *)inString inRooms:(NSArray *)inRooms usesRegex:(BOOL) inRegex ignoreMember:(BOOL) inMemberIgnore {
	return [[[KAInternalIgnoreRule alloc] initWithString:inString inRooms:inRooms usesRegex:inRegex ignoreMember:inMemberIgnore] autorelease];
}


- (void) dealloc {
	[_ignoredKey release];
	_ignoredKey = nil;
	[_inChannels release];
	_inChannels = nil;
	
	[super dealloc];
}

- (NSString *) key {
	return [[_ignoredKey retain] autorelease];
}
- (NSArray *) channels {
	return [[_inChannels retain] autorelease];
}
- (BOOL) isMember {
	return _memberIgnore;
}
- (BOOL) regex {
	return _regex;
}
@end