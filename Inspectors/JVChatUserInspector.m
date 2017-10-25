#import "JVChatUserInspector.h"
#import "JVChatRoomPanel.h"
#import "JVBuddy.h"
#import "MVFileTransferController.h"
#import <ChatCore/NSDateAdditions.h>

@implementation JVDirectChatPanel (JVDirectChatPanelInspection)
- (id <JVInspector>) inspector {
	return [[JVChatUserInspector alloc] initWithChatUser:[self target]];
}
@end

#pragma mark -

@implementation JVChatRoomMember (JVChatRoomMemberInspection)
- (id <JVInspector>) inspector {
	return [[JVChatUserInspector alloc] initWithChatUser:[self user]];
}
@end

#pragma mark -

@implementation MVChatUser (MVChatUserInspection)
- (id <JVInspector>) inspector {
	return [[JVChatUserInspector alloc] initWithChatUser:self];
}
@end

#pragma mark -

@implementation JVChatUserInspector
- (instancetype) initWithChatUser:(MVChatUser *) user {
	if( ( self = [super init] ) )
		_user = user;
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter chatCenter] removeObserver:self];
}

#pragma mark -

- (NSView *) view {
	if( ! _nibLoaded ) _nibLoaded = [[NSBundle mainBundle] loadNibNamed:@"JVChatMemberInspector" owner:self topLevelObjects:NULL];
	return view;
}

- (NSSize) minSize {
	return NSMakeSize( 220., 359. );
}

- (NSString *) title {
	return [_user nickname];
}

- (NSString *) type {
	return NSLocalizedString( @"User", "chat user inspector type" );
}

- (void) willLoad {
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( infoUpdated: ) name:MVChatUserInformationUpdatedNotification object:_user];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( attributeUpdated: ) name:MVChatUserAttributeUpdatedNotification object:_user];
	[[NSNotificationCenter chatCenter] addObserver:self selector:@selector( errorOccurred: ) name:MVChatConnectionErrorNotification object:[_user connection]];

	_addressResolved = NO;
	[progress startAnimation:nil];
	[_user refreshInformation];

	[_updateTimer invalidate];
	_updateTimer = [NSTimer scheduledTimerWithTimeInterval:120. target:self selector:@selector( updateInformation ) userInfo:nil repeats:YES];

	[nickname setObjectValue:[_user nickname]];
//	if( [[_user buddy] picture] )
//		[image setImage:[[_user buddy] picture]];
}

- (BOOL) shouldUnload {
	[[view window] makeFirstResponder:view];
	return YES;
}

- (void) didUnload {
	_localTimeUpdated = nil;

	[_localTimeUpdateTimer invalidate];
	_localTimeUpdateTimer = nil;

	[_updateTimer invalidate];
	_updateTimer = nil;
}

#pragma mark -

- (void) updateInformation {
	[_user refreshInformation];
	[progress startAnimation:nil];
}

#pragma mark -

- (NSMutableAttributedString *) _convertRawMessage:(NSData *) message withBaseFont:(NSFont *) baseFont {
	if( ! message || ! [message length] ) return nil;
	if( ! baseFont ) baseFont = [NSFont labelFontOfSize:11.];

	NSMutableDictionary *options = [NSMutableDictionary dictionaryWithObjectsAndKeys:@([[_user connection] encoding]), @"StringEncoding", @([[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageColors"]), @"IgnoreFontColors", @([[NSUserDefaults standardUserDefaults] boolForKey:@"JVChatStripMessageFormatting"]), @"IgnoreFontTraits", baseFont, @"BaseFont", nil];
	NSMutableAttributedString *messageString = [NSMutableAttributedString attributedStringWithChatFormat:message options:options];

	if( ! messageString ) {
		options[@"StringEncoding"] = @(NSISOLatin1StringEncoding);
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
	@autoreleasepool {
		NSString *ip = [[NSHost hostWithName:[_user address]] address];
		[self performSelectorOnMainThread:@selector( gotAddress: ) withObject:ip waitUntilDone:YES];
	}
}

- (void) infoUpdated:(NSNotification *) notification {
	if( [_user isIdentified] ) {
		[class setObjectValue:NSLocalizedString( @"Registered user", "registered user class" )];
	} else if( [_user isServerOperator] ) {
		[class setObjectValue:NSLocalizedString( @"Server operator", "server operator class" )];
	} else {
		[class setObjectValue:NSLocalizedString( @"Normal user", "normal user class" )];
	}

	NSData *awayData = [_user awayStatusMessage];
	NSAttributedString *awayString = [self _convertRawMessage:awayData withBaseFont:nil];
	[away setObjectValue:( awayString && [awayString length] ? awayString : (NSAttributedString *)NSLocalizedString( @"n/a", "not applicable or not available" ) )];

	[username setObjectValue:( [_user username] ? [_user username] : NSLocalizedString( @"n/a", "not applicable or not available" ) )];

	[hostname setObjectValue:( [_user address] ? [_user address] : NSLocalizedString( @"n/a", "not applicable or not available" ) )];
	[hostname setToolTip:( [_user address] ? [_user address] : NSLocalizedString( @"n/a", "not applicable or not available" ) )];

	if( ! _addressResolved ) [NSThread detachNewThreadSelector:@selector( lookupAddress ) toTarget:self withObject:nil];

	[server setObjectValue:( [_user serverAddress] ? [_user serverAddress] : NSLocalizedString( @"n/a", "not applicable or not available" ) )];
	[server setToolTip:( [_user serverAddress] ? [_user serverAddress] : NSLocalizedString( @"n/a", "not applicable or not available" ) )];

	[realName setObjectValue:( [_user realName] ? [_user realName] : NSLocalizedString( @"n/a", "not applicable or not available" ) )];
	[realName setToolTip:( [_user realName] ? [_user realName] : NSLocalizedString( @"n/a", "not applicable or not available" ) )];

	[connected setObjectValue:( ! ( [_user status] == MVChatUserOfflineStatus ) ? MVReadableTime( [[_user dateConnected] timeIntervalSince1970], YES ) : NSLocalizedString( @"offline", "offline, not connected" ) )];
	[idle setObjectValue:( ! ( [_user status] == MVChatUserOfflineStatus ) ? MVReadableTime( [[NSDate date] timeIntervalSince1970] + [_user idleTime], YES ) : NSLocalizedString( @"n/a", "not applicable or not available" ) )];

	if( _addressResolved ) [progress stopAnimation:nil];
}

- (void) attributeUpdated:(NSNotification *) notification {
	NSString *key = [notification userInfo][@"attribute"];
	if( [key isEqualToString:MVChatUserPingAttribute] ) {
		NSTimeInterval pingSeconds = [[_user attributeForKey:key] doubleValue];
		NSString *pingString = [NSString stringWithFormat:@"%.2f %@", pingSeconds, NSLocalizedString( @"seconds", "plural seconds" )];
		[ping setObjectValue:pingString];
		[ping setToolTip:pingString];
	} else if( [key isEqualToString:MVChatUserLocalTimeAttribute] ) {
		_localTimeUpdated = [NSDate date];

		[self updateLocalTime];
		if( ! _localTimeUpdateTimer )
			_localTimeUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:10. target:self selector:@selector( updateLocalTime ) userInfo:nil repeats:YES];
	} else if( [key isEqualToString:MVChatUserClientInfoAttribute] ) {
		[clientInfo setObjectValue:[_user attributeForKey:key]];
		[clientInfo setToolTip:[_user attributeForKey:key]];
	} else if( [key isEqualToString:MVChatUserKnownRoomsAttribute] ) {
		NSString *rms = [[_user attributeForKey:key] componentsJoinedByString:NSLocalizedString( @", ", "room list separator" )];
		[rooms setObjectValue:rms];
		[rooms setToolTip:rms];
	}
}

- (void) errorOccurred:(NSNotification *) notification {
	NSError *error = [notification userInfo][@"error"];
	if( [error code] == MVChatConnectionNoSuchUserError ) {
		MVChatUser *user = [error userInfo][@"user"];
		if( [user isEqualTo:_user] )
			[self gotAddress:nil];
	}
}

- (void) updateLocalTime {
	NSTimeInterval now = ABS( [_localTimeUpdated timeIntervalSinceNow] );
	NSDate *adjustedDate = [[NSDate alloc] initWithTimeIntervalSinceNow:now];
	NSString *formatedDate = [NSDate formattedShortDateAndTimeStringForDate:adjustedDate];

	[localTime setObjectValue:formatedDate];
	[localTime setToolTip:[formatedDate description]];
}

- (IBAction) sendPing:(id) sender {
	[_user refreshAttributeForKey:MVChatUserPingAttribute];
}

- (IBAction) requestLocalTime:(id) sender {
	[_user refreshAttributeForKey:MVChatUserLocalTimeAttribute];
}

- (IBAction) requestClientInfo:(id) sender {
	[_user refreshAttributeForKey:MVChatUserClientInfoAttribute];
}
@end
