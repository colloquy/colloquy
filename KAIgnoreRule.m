//  KAIgnoreRule.m
//  Colloquy
//  Created by Karl Adam on Thu Apr 15 2004.

#import <Cocoa/Cocoa.h>

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/NSAttributedStringAdditions.h>

#import "KAIgnoreRule.h"

@implementation KAInternalIgnoreRule
+ (id) ruleWithString:(NSString *) string inRooms:(NSArray *) rooms usesRegex:(BOOL) regex ignoreMember:(BOOL) member {
	return [[[KAInternalIgnoreRule alloc] initWithString:string inRooms:rooms usesRegex:regex ignoreMember:member] autorelease];
}

- (id) initWithString:(NSString *) string inRooms:(NSArray *) rooms usesRegex:(BOOL) regex ignoreMember:(BOOL) member {
	if( ( self = [super init] ) ) {
		_ignoredKey = [string retain];
		_inChannels	= [rooms retain];
		_regex = regex;
		_memberIgnore = member;
	}

	return self;
}

- (void) dealloc {
	[_ignoredKey release];
	[_inChannels release];

	_ignoredKey = nil;
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