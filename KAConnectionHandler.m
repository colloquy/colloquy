//  KAConnectionHandler.m
//  Colloquy
//  Created by Karl Adam on Thu Apr 15 2004.

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/NSAttributedStringAdditions.h>
#import <AGRegex/AGRegex.h>

#import "KAConnectionHandler.h"
#import "MVApplicationController.h"
#import "JVChatController.h"
#import "JVNotificationController.h"
#import "JVChatRoom.h"

static KAConnectionHandler *sharedHandler = nil;

@interface KAConnectionHandler (PrivateParts)
- (BOOL) _ignoreUser:(NSString *) name withMessage:(NSAttributedString *) message inRoom:(NSString *) room withConnection:(MVChatConnection *) connection;

@end;

@interface KAInternalIgnoreRule : NSObject {
	NSString	*_ignoredKey;
	NSArray		*_inChannels;
	BOOL		_regex;
	BOOL		_memberIgnore;
}

- (id) initWithString:(NSString *)inString inRooms:(NSArray *)inRooms usesRegex:(BOOL) inRegex ignoreMember:(BOOL) inMemberIgnore;
+ (id) ruleWithString:(NSString *)inString inRooms:(NSArray *)inRooms usesRegex:(BOOL) inRegex ignoreMember:(BOOL) inMemberIgnore;

- (NSString *) key;
- (NSArray *) channels;
- (BOOL) isMember;
- (BOOL) regex;

@end

@implementation KAConnectionHandler
+ (KAConnectionHandler *) defaultHandler {
	extern KAConnectionHandler *sharedHandler;
	if( ! sharedHandler && [MVApplicationController isTerminating] ) return nil;
	return ( sharedHandler ? sharedHandler : ( sharedHandler = [[self alloc] init] ) );
}

- (id) init {
	if ( self = [super init] ) {
		_ignoreRules = [[NSMutableDictionary alloc] initWithCapacity:10];
	}
	return self;
}

- (void) dealloc {
	[_ignoreRules release];
	_ignoreRules = nil;
	
	[super dealloc];
}

#pragma mark Delegate Actions

- (BOOL) connection:(MVChatConnection *) connection willPostMessage:(NSData *) message from:(NSString *) user toRoom:(BOOL) flag withInfo:(NSDictionary *) info {
	BOOL hideFromUser = YES;

	if( [[JVChatController defaultManager] chatViewControllerForUser:user withConnection:connection ifExists:YES] )
		hideFromUser = NO;

	NSString *curMsg = [[[NSString alloc] initWithData:message encoding:NSUTF8StringEncoding] autorelease];
	if( ! curMsg ) curMsg = [NSString stringWithCString:[message bytes] length:[message length]];

	if( [user isEqualToString:@"NickServ"] ) {
		if( [curMsg rangeOfString:@"password accepted" options:NSCaseInsensitiveSearch].location != NSNotFound ) {
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			[context setObject:NSLocalizedString( @"You Have Been Identified", "identified bubble title" ) forKey:@"title"];
			[context setObject:[NSString stringWithFormat:@"%@ on %@", curMsg, [connection server]] forKey:@"description"];
			[context setObject:[NSImage imageNamed:@"Keychain"] forKey:@"image"];
			[context setObject:[connection nickname] forKey:@"performedOn"];
			[context setObject:user forKey:@"performedBy"];
			[[JVNotificationController defaultManager] performNotification:@"JVNickNameIdentifiedWithServer" withContextInfo:context];
		}
	}

	if( [user isEqualToString:@"MemoServ"] ) {
		if( [curMsg rangeOfString:@"new memo" options:NSCaseInsensitiveSearch].location != NSNotFound && [curMsg rangeOfString:@" no " options:NSCaseInsensitiveSearch].location == NSNotFound ) {
			NSAttributedString *curAMsg = [NSAttributedString attributedStringWithHTMLFragment:[NSString stringWithFormat:@"<span style=\"font-size: 11px; font-family: Lucida Grande, san-serif\">%@ on %@</span>", curMsg, [connection server]] baseURL:NULL]; 
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			[context setObject:NSLocalizedString( @"You Have New Memos", "new memos bubble title" ) forKey:@"title"];
			[context setObject:curAMsg forKey:@"description"];
			[context setObject:[NSImage imageNamed:@"Stickies"] forKey:@"image"];
			[context setObject:[connection nickname] forKey:@"performedOn"];
			[context setObject:user forKey:@"performedBy"];
			[context setObject:self forKey:@"target"];
			[context setObject:NSStringFromSelector( @selector( checkMemos: ) ) forKey:@"action"];
			[context setObject:connection forKey:@"representedObject"];
			[[JVNotificationController defaultManager] performNotification:@"JVNewMemosFromServer" withContextInfo:context];
		}	
	}
	
	if ( flag ) { //user/message ignores
		hideFromUser = NO; //we don't intercept the message, we add it to the screen, but the style hides it
		NSAttributedString *curAMsg = [NSAttributedString attributedStringWithHTMLFragment:[NSString stringWithFormat:@"<span style=\"font-size: 11px; font-family: Lucida Grande, san-serif\">%@ on %@</span>", curMsg, [connection server]] baseURL:NULL]; 

		if ( [self shouldIgnoreMessage:curAMsg inRoom:[info objectForKey:@"room"]] ) {
			NSLog( @"stuff was said, and was said to be ignored" );
			[self _ignoreUser:user withMessage:curAMsg inRoom:[info objectForKey:@"room"] withConnection:connection];
		}
	}

	return hideFromUser;
}

#pragma mark Ignores
- (void) addIgnore:(NSString *)inIgnoreName withKey:(NSString *)ignoreKeyExpression inRooms:(NSArray *) rooms usesRegex:(BOOL) regex isMember:(BOOL) member {
	// USAGE: /ignore -[e|m|n] nickname message #rooms...
	// e activates regex matching, m is primarily for when there is no nickname to affix this to
	// m is to specify a message
	// n is to specify a nickname
	// EXAMPLES: 
	// /ignore Loser23094 - ignore Loser23094 in the current room
	// /ignore -em "is listening *" - ignore the message expression "is listening *" from everyone
	// /ignore -emn eevyl* "is listening *" #adium #colloquy #here
	// /ignore -en bunny* ##ALL
	
	[_ignoreRules setObject:[KAInternalIgnoreRule ruleWithString:ignoreKeyExpression inRooms:rooms usesRegex:regex ignoreMember:member] 
					 forKey:inIgnoreName];
}


- (BOOL) shouldIgnoreUser:(NSString *) user inRoom:(NSString *) room {
	BOOL ignoreThisUser = NO;
	NSEnumerator *kenum = [_ignoreRules keyEnumerator];
	NSString *key = nil;
	KAInternalIgnoreRule *rule = nil;

	while ( key = [kenum nextObject] ) {
		if ( [key isEqualToString:user] ) ignoreThisUser = YES;
		
		rule = [_ignoreRules objectForKey:key];
		
		if ( [rule regex] && !ignoreThisUser && [rule isMember] ) {
			AGRegex *matchString = [AGRegex regexWithPattern:[rule key] options:AGRegexCaseInsensitive];
			if ( [matchString findInString:key] ) ignoreThisUser = YES;
		}
	}
	
	return ignoreThisUser;
}

- (BOOL) shouldIgnoreMessage:(NSAttributedString *) message inRoom:(NSString *) room {
	BOOL ignoreThisMessage = NO;
	NSEnumerator *oenum = [_ignoreRules objectEnumerator];
	KAInternalIgnoreRule *rule = nil;
	
	while ( rule = [oenum nextObject] ) {		
		if ( [rule regex] && ![rule isMember] ) {
			AGRegex *matchPattern = [AGRegex regexWithPattern:[rule key] options:AGRegexCaseInsensitive];
			if ( [matchPattern findInString:[rule key]] ) ignoreThisMessage = YES;
		} else if ( [[rule key] isEqualToString:[message string]] ) ignoreThisMessage = YES;
	}
	
	
	return ignoreThisMessage;
}

- (BOOL) shouldIgnoreMessage:(NSAttributedString *) message fromUser:(NSString *)user inRoom:(NSString *) room {
	return ( [self shouldIgnoreUser:user inRoom:room] || [self shouldIgnoreMessage:message inRoom:room] );
}
@end

#pragma mark -

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

#pragma mark -

@implementation KAConnectionHandler (PrivateParts)
- (BOOL) _ignoreUser:(NSString *) name withMessage:(NSAttributedString *) message inRoom:(NSString *) room withConnection:(MVChatConnection *) connection {
	BOOL wasIgnored = NO;
	//second check for ignore: if the object in the dictionary is nil, we ignore the user everywhere
	//if we have an array we check that the array contains our current room and ignore them
	
	if ( [self shouldIgnoreUser:name inRoom:room] ) {
		NSArray *ignoredRooms = [[_ignoreRules objectForKey:name] channels];
		
		if ( ignoredRooms == nil ) {
			//send an ignored Notificatoin
			NSMutableDictionary *context = [NSMutableDictionary dictionary];
			[context setObject:NSLocalizedString( @"User Message Ignored", "user ignored bubble title" ) forKey:@"title"];
			[context setObject:[NSString stringWithFormat:@"%@'s message was ignored in %@", name, room] forKey:@"description"];
			[context setObject:[NSImage imageNamed:@"activity"] forKey:@"image"];
			[context setObject:name forKey:@"performedOn"];
			[context setObject:[connection nickname] forKey:@"performedBy"];
			[context setObject:connection forKey:@"representedObject"];
			[[JVNotificationController defaultManager] performNotification:@"JVUserMessageIgnored" withContextInfo:context];
			wasIgnored = YES;
		}
	} else if ( [self shouldIgnoreMessage:message inRoom:room] ) {
		//send an ignored Notificatoin
		NSMutableDictionary *context = [NSMutableDictionary dictionary];
		[context setObject:NSLocalizedString( @"Message Ignored", "message ignored bubble title" ) forKey:@"title"];
		[context setObject:[NSString stringWithFormat:@"%@'s message was ignored in %@", name, room] forKey:@"description"];
		[context setObject:[NSImage imageNamed:@"activity"] forKey:@"image"];
		[context setObject:name forKey:@"performedOn"];
		[context setObject:[connection nickname] forKey:@"performedBy"];
		[context setObject:connection forKey:@"representedObject"];
		[[JVNotificationController defaultManager] performNotification:@"JVMessageIgnored" withContextInfo:context];
	}
	
	return wasIgnored;
}
@end