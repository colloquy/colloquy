#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatUser.h>
#import <ChatCore/MVChatRoom.h>
#import "JVChatMemberInspector.h"
#import "JVChatRoomPanel.h"
#import "JVBuddy.h"
#import "MVFileTransferController.h"

@implementation JVChatRoomMember (JVChatRoomMemberInspection)
- (id <JVInspector>) inspector {
	return [[[JVChatMemberInspector alloc] initWithChatMember:self] autorelease];
}
@end

#pragma mark -

@implementation JVChatMemberInspector
- (id) initWithChatMember:(JVChatRoomMember *) member {
	if( ( self = [self init] ) ) {
		_member = [member retain];
		_localTimeUpdateTimer = nil;
		_updateTimer = [[NSTimer scheduledTimerWithTimeInterval:30. target:self selector:@selector( updateInformation ) userInfo:nil repeats:YES] retain];
	}
	return self;
}

- (void) release {
	if( ( [self retainCount] - ( _localTimeUpdateTimer ? 2 : 1 ) ) == 1 ) {
		[_localTimeUpdateTimer invalidate];
		[_updateTimer invalidate];
	}
	[super release];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_localTimeUpdateTimer release];
	[_updateTimer release];
	[_member release];

	_localTimeUpdateTimer = nil;
	_updateTimer = nil;
	_member = nil;

	[super dealloc];
}

#pragma mark -

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [NSBundle loadNibNamed:@"JVChatMemberInspector" owner:self];
	return view;
}

- (NSSize) minSize {
	return NSMakeSize( 220., 359. );
}

- (NSString *) title {
	return [_member nickname];
}

- (NSString *) type {
	return NSLocalizedString( @"User", "chat user inspector type" );
}

- (void) willLoad {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( infoUpdated: ) name:MVChatUserInformationUpdatedNotification object:[_member user]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( attributeUpdated: ) name:MVChatUserAttributeUpdatedNotification object:[_member user]];

	[[_member user] refreshInformation];
	[progress startAnimation:nil];
	_addressResolved = NO;
	[nickname setObjectValue:[_member nickname]];
	if( [[_member buddy] picture] ) [image setImage:[[_member buddy] picture]];
}

#pragma mark -

- (void) updateInformation {
	[[_member user] refreshInformation];	
	[progress startAnimation:nil];
}

#pragma mark -

- (void) gotAddress:(NSString *) ip {
	[address setObjectValue:( ip ? ip : NSLocalizedString( @"n/a", "not applicable or not available" ) )];
	[address setToolTip:( ip ? ip : nil )];
	_addressResolved = YES;
	[progress stopAnimation:nil];
}

- (oneway void) lookupAddress {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *ip = [[NSHost hostWithName:[[_member user] address]] address];
	[self performSelectorOnMainThread:@selector( gotAddress: ) withObject:ip waitUntilDone:YES];
	[pool release];
}

- (void) infoUpdated:(NSNotification *) notification {
	if( [[_member user] isIdentified] ) {
		[class setObjectValue:NSLocalizedString( @"Registered user", "registered user class" )];
	} else if( [[_member user] isServerOperator] ) {
		[class setObjectValue:NSLocalizedString( @"Server operator", "server operator class" )];
	} else {
		[class setObjectValue:NSLocalizedString( @"Normal user", "normal user class" )];
	}

	[username setObjectValue:[[_member user] username]];

	[hostname setObjectValue:[[_member user] address]];
	[hostname setToolTip:[[_member user] address]];

	if( ! _addressResolved ) [NSThread detachNewThreadSelector:@selector( lookupAddress ) toTarget:self withObject:nil];

	[server setObjectValue:[[_member user] serverAddress]];
	[server setToolTip:[[_member user] serverAddress]];

	[realName setObjectValue:[[_member user] realName]];
	[realName setToolTip:[[_member user] realName]];

	[connected setObjectValue:MVReadableTime( [[[_member user] dateConnected] timeIntervalSince1970], YES )];
	[idle setObjectValue:MVReadableTime( [[NSDate date] timeIntervalSince1970] + [[_member user] idleTime], YES )];

	if( _addressResolved ) [progress stopAnimation:nil];
}

- (void) attributeUpdated:(NSNotification *) notification {
	NSString *key = [[notification userInfo] objectForKey:@"attribute"];
	if( [key isEqualToString:MVChatUserLocalTimeDifferenceAttribute] ) {
		if( ! _localTimeUpdateTimer )
			_localTimeUpdateTimer = [[NSTimer scheduledTimerWithTimeInterval:10. target:self selector:@selector( updateLocalTime ) userInfo:nil repeats:YES] retain];
	} else if( [key isEqualToString:MVChatUserClientInfoAttribute] ) {
		[clientInfo setObjectValue:[[_member user] attributeForKey:key]];
		[clientInfo setToolTip:[[_member user] attributeForKey:key]];
	}
}

- (void) updateLocalTime {
	NSString *format = [[NSUserDefaults standardUserDefaults] objectForKey:NSShortTimeDateFormatString];
	NSDate *current = [[NSDate dateWithTimeIntervalSinceNow:[[[_member user] attributeForKey:MVChatUserLocalTimeDifferenceAttribute] doubleValue]] dateWithCalendarFormat:format timeZone:nil];
	[localTime setObjectValue:current];
}

- (IBAction) sendPing:(id) sender {

}

- (IBAction) requestLocalTime:(id) sender {
	[[_member user] refreshAttributeForKey:MVChatUserLocalTimeDifferenceAttribute];
}

- (IBAction) requestClientInfo:(id) sender {
	[[_member user] refreshAttributeForKey:MVChatUserClientInfoAttribute];
}
@end