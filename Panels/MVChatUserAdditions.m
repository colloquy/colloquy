#import "MVChatUserAdditions.h"

#import "JVChatController.h"
#import "JVChatUserInspector.h"
#import "MVBuddyListController.h"
#import "MVConnectionsController.h"
#import "MVFileTransferController.h"
#import "KAIgnoreRule.h"

@implementation MVChatUser (MVChatUserAdditions)
- (NSString *) xmlDescription {
	return [self xmlDescriptionWithTagName:@"user"];
}

- (NSString *) xmlDescriptionWithTagName:(NSString *) tag {
	NSParameterAssert( [tag length] != 0 );

	// Full format will look like:
	// <user self="yes" nickname="..." hostmask="..." identifier="...">...</user>

	NSMutableString *ret = [NSMutableString string];
	[ret appendFormat:@"<%@", tag];

	if( [self isLocalUser] ) [ret appendString:@" self=\"yes\""];

	if( ! [[self displayName] isEqualToString:[self nickname]] )
		[ret appendFormat:@" nickname=\"%@\"", [[self nickname] stringByEncodingXMLSpecialCharactersAsEntities]];

	if( [[self username] length] && [[self address] length] )
		[ret appendFormat:@" hostmask=\"%@@%@\"", [[self username] stringByEncodingXMLSpecialCharactersAsEntities], [[self address] stringByEncodingXMLSpecialCharactersAsEntities]];

	id uniqueId = [self uniqueIdentifier];
	if( ! [uniqueId isEqual:[self nickname]] ) {
		if( [uniqueId isKindOfClass:[NSData class]] ) uniqueId = [uniqueId base64Encoding];
		else if( [uniqueId isKindOfClass:[NSString class]] ) uniqueId = [uniqueId stringByEncodingXMLSpecialCharactersAsEntities];
		[ret appendFormat:@" identifier=\"%@\"", uniqueId];
	}

	if( [self isServerOperator] ) [ret appendFormat:@" class=\"%@\"", @"server operator"];

	[ret appendFormat:@">%@</%@>", [[self displayName] stringByEncodingXMLSpecialCharactersAsEntities], tag];

	[ret stripIllegalXMLCharacters];
	return [NSString stringWithString:ret];
}

- (KAIgnoreRule *) _tempIgnoreRule {
	NSString *ignoreSuffix = NSLocalizedString( @" (Temporary)", "temporary ignore title suffix" );
	NSMutableArray *rules = [[MVConnectionsController defaultController] ignoreRulesForConnection:[self connection]];

	for( KAIgnoreRule *rule in rules )
		if( ! [rule isPermanent] && [[rule friendlyName] hasSuffix:ignoreSuffix] && [rule matchUser:self message:nil inView:nil] != JVNotIgnored )
			return rule;

	return nil;
}

- (NSArray *) standardMenuItems {
	NSMutableArray *items = [[NSMutableArray alloc] initWithCapacity:5];
	NSMenuItem *item = nil;

	item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Get Info", "get info contextual menu item title" ) action:@selector( getInfo: ) keyEquivalent:@""];
	[item setTarget:self];
	[items addObject:item];
	[item release];

	if( ! [self isLocalUser] ) {
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Send Message", "send message contextual menu") action:@selector( startChat: ) keyEquivalent:@""];
		[item setTarget:self];
		[items addObject:item];
		[item release];

		if( [[self connection] type] == MVChatConnectionIRCType ) {
			item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Initiate DCC Chat", "initiate DCC chat contextual menu") action:@selector( startDirectChat: ) keyEquivalent:@""];
			[item setTarget:self];
			[items addObject:item];
			[item release];
		}

		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Send File...", "send file contextual menu") action:@selector( sendFile: ) keyEquivalent:@""];
		[item setTarget:self];
		[items addObject:item];
		[item release];
	}

	if( ! [[MVBuddyListController sharedBuddyList] buddyForUser:self] ) {
		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Add To Buddy List", "add to buddy list contextual menu") action:@selector( addBuddy: ) keyEquivalent:@""];
		[item setTarget:self];
		[items addObject:item];
		[item release];
	}

	if( ! [self isLocalUser] ) {
		[items addObject:[NSMenuItem separatorItem]];

		item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Ignore", "ignore user contextual menu") action:@selector( toggleIgnore: ) keyEquivalent:@""];
		[item setTarget:self];
		[items addObject:item];
		[item release];
	}

	return [items autorelease];
}

- (IBAction) getInfo:(id) sender {
	[[JVInspectorController inspectorOfObject:self] show:sender];
}

- (IBAction) startChat:(id) sender {
	if( [self isLocalUser] ) return;
	[[JVChatController defaultController] chatViewControllerForUser:self ifExists:NO];
}

- (IBAction) startDirectChat:(id) sender {
	if( [self isLocalUser] ) return;

	BOOL passive = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSendFilesPassively"];
	MVDirectChatConnection *connection = [MVDirectChatConnection directChatConnectionWithUser:self passively:passive];
	[[JVChatController defaultController] chatViewControllerForDirectChatConnection:connection ifExists:NO];
}

- (IBAction) sendFile:(id) sender {
	BOOL passive = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSendFilesPassively"];
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setResolvesAliases:YES];
	[panel setCanChooseFiles:YES];
	[panel setCanChooseDirectories:NO];
	[panel setAllowsMultipleSelection:YES];

	NSView *view = [[NSView alloc] initWithFrame:NSMakeRect( 0., 0., 200., 28. )];
	[view setAutoresizingMask:( NSViewWidthSizable | NSViewMaxXMargin )];

	NSButton *passiveButton = [[NSButton alloc] initWithFrame:NSMakeRect( 0., 6., 200., 18. )];
	[[passiveButton cell] setButtonType:NSSwitchButton];
	[passiveButton setState:passive];
	[passiveButton setTitle:NSLocalizedString( @"Send File Passively", "send files passively file send open dialog button" )];
	[passiveButton sizeToFit];

	NSRect frame = [view frame];
	frame.size.width = NSWidth( [passiveButton frame] );

	[view setFrame:frame];
	[view addSubview:passiveButton];
	[passiveButton release];

	[panel setAccessoryView:view];
	[view release];

	if( [panel runModalForTypes:nil] == NSOKButton ) {
		passive = [passiveButton state];
		for( NSString *path in [panel filenames] )
			[[MVFileTransferController defaultController] addFileTransfer:[self sendFile:path passively:passive]];
	}
}

- (IBAction) addBuddy:(id) sender {
	[[MVBuddyListController sharedBuddyList] showBuddyPickerSheet:self];
	[[MVBuddyListController sharedBuddyList] setNewBuddyNickname:[self nickname]];
	[[MVBuddyListController sharedBuddyList] setNewBuddyFullname:[self realName]];
	[[MVBuddyListController sharedBuddyList] setNewBuddyServer:[self connection]];
}

- (IBAction) toggleIgnore:(id) sender {
	NSMutableArray *rules = [[MVConnectionsController defaultController] ignoreRulesForConnection:[self connection]];
	KAIgnoreRule *rule = [self _tempIgnoreRule];
	if( rule ) [rules removeObjectIdenticalTo:rule];
	else [rules addObject:[KAIgnoreRule ruleForUser:[self nickname] message:nil inRooms:nil isPermanent:NO friendlyName:[NSString stringWithFormat:@"%@ %@", [self displayName], NSLocalizedString( @" (Temporary)", "temporary ignore title suffix" )]]];
}

- (BOOL) validateMenuItem:(NSMenuItem *) menuItem {
	 if( [menuItem action] == @selector( toggleIgnore: ) ) {
		KAIgnoreRule *rule = [self _tempIgnoreRule];
		if( rule ) [menuItem setState:NSOnState];
		else [menuItem setState:NSOffState];
		return YES;
	}

	return YES;
}
@end
