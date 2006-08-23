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
	if( ( self = [self init] ) )
		_member = [member retain];
	return self;
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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( errorOccurred: ) name:MVChatConnectionErrorNotification object:[[_member user] connection]];

	_addressResolved = NO;
	[progress startAnimation:nil];
	[[_member user] refreshInformation];

	[_updateTimer invalidate];
	[_updateTimer release];
	_updateTimer = [[NSTimer scheduledTimerWithTimeInterval:30. target:self selector:@selector( updateInformation ) userInfo:nil repeats:YES] retain];

	[nickname setObjectValue:[_member nickname]];
	if( [[_member buddy] picture] ) [image setImage:[[_member buddy] picture]];
}

- (BOOL) shouldUnload {
	[[view window] makeFirstResponder:view];
	return YES;
}

- (void) didUnload {
	[_localTimeUpdateTimer invalidate];
	[_localTimeUpdateTimer release];
	_localTimeUpdateTimer = nil;

	[_updateTimer invalidate];
	[_updateTimer release];
	_updateTimer = nil;
}

#pragma mark -

- (void) updateInformation {
	[[_member user] refreshInformation];
	[progress startAnimation:nil];
}

#pragma mark -

- (NSMutableAttributedString *) _convertRawMessage:(NSData *) message withBaseFont:(NSFont *) baseFont {
	if( ! message || ! [message length] ) return nil;
	if( ! baseFont ) baseFont = [NSFont labelFontOfSize:11.];

	NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:[[_member connection] encoding]], @"StringEncoding", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageColors"]], @"IgnoreFontColors", [NSNumber numberWithBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageFormatting"]], @"IgnoreFontTraits", baseFont, @"BaseFont", nil];
	NSMutableAttributedString *messageString = [NSMutableAttributedString attributedStringWithChatFormat:message options:options];

	if( ! messageString ) {
		[options setObject:[NSNumber numberWithUnsignedInt:NSISOLatin1StringEncoding] forKey:@"StringEncoding"];
		messageString = [NSMutableAttributedString attributedStringWithChatFormat:message options:options];
	}

	return messageString;
}

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
	
	NSData *awayData = [[_member user] awayStatusMessage];
	NSAttributedString *awayString = [self _convertRawMessage:awayData withBaseFont:nil];
	if( ! awayString || ! [awayString length] ) [away setObjectValue:NSLocalizedString( @"n/a", "not applicable or not available" )];
	else [away setObjectValue:awayString];

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
	if( [key isEqualToString:MVChatUserPingAttribute] ) {
		NSTimeInterval pingSeconds = [[[_member user] attributeForKey:key] doubleValue];
		NSString *pingString = [NSString stringWithFormat:@"%.2f %@", pingSeconds, NSLocalizedString( @"seconds", "plural seconds" )];
		[ping setObjectValue:pingString];
		[ping setToolTip:pingString];
	} else if( [key isEqualToString:MVChatUserLocalTimeDifferenceAttribute] ) {
		if( ! _localTimeUpdateTimer )
			_localTimeUpdateTimer = [[NSTimer scheduledTimerWithTimeInterval:10. target:self selector:@selector( updateLocalTime ) userInfo:nil repeats:YES] retain];
	} else if( [key isEqualToString:MVChatUserClientInfoAttribute] ) {
		[clientInfo setObjectValue:[[_member user] attributeForKey:key]];
		[clientInfo setToolTip:[[_member user] attributeForKey:key]];
	} else if( [key isEqualToString:MVChatUserKnownRoomsAttribute] ) {
		NSString *rms = [[[_member user] attributeForKey:key] componentsJoinedByString:NSLocalizedString( @", ", "room list separator" )];
		[rooms setObjectValue:rms];
		[rooms setToolTip:rms];
	}
}

- (void) errorOccurred:(NSNotification *) notification {
	NSError *error = [[notification userInfo] objectForKey:@"error"];
	if( [error code] == MVChatConnectionNoSuchUserError ) {
		MVChatUser *user = [[error userInfo] objectForKey:@"user"];
		if( [user isEqualTo:[_member user]] )
			[self gotAddress:nil];
	}
}

- (void) updateLocalTime {
	NSString *format = [[NSUserDefaults standardUserDefaults] objectForKey:NSShortTimeDateFormatString];
	NSDate *current = [[NSDate dateWithTimeIntervalSinceNow:[[[_member user] attributeForKey:MVChatUserLocalTimeDifferenceAttribute] doubleValue]] dateWithCalendarFormat:format timeZone:nil];
	[localTime setObjectValue:current];
}

- (IBAction) sendPing:(id) sender {
	[[_member user] refreshAttributeForKey:MVChatUserPingAttribute];
}

- (IBAction) requestLocalTime:(id) sender {
	[[_member user] refreshAttributeForKey:MVChatUserLocalTimeDifferenceAttribute];
}

- (IBAction) requestClientInfo:(id) sender {
	[[_member user] refreshAttributeForKey:MVChatUserClientInfoAttribute];
}
@end