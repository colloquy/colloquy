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

- (KAIgnoreRule *) tempIgnoreRule {
	NSString *ignoreSuffix = NSLocalizedString( @" (Temporary)", "temporary ignore title suffix" );
	NSMutableArray *rules = [[MVConnectionsController defaultController] ignoreRulesForConnection:[self connection]];
	NSEnumerator *enumerator = [rules objectEnumerator];
	KAIgnoreRule *rule = nil;

	while( ( rule = [enumerator nextObject] ) )
		if( ! [rule isPermanent] && [[rule friendlyName] hasSuffix:ignoreSuffix]
			&& [rule matchUser:self message:nil inView:nil] != JVNotIgnored ) break;

	return rule;
}

- (NSArray *) standardMenuItems {
	NSMutableArray *items = [[NSMutableArray alloc] initWithCapacity:5];
	NSMenuItem *item = nil;

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Get Info", "get info contextual menu item title" ) action:@selector( getInfo: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[items addObject:item];

	if( ! [self isLocalUser] ) {
		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Send Message", "send message contextual menu") action:@selector( startChat: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[items addObject:item];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Send File...", "send file contextual menu") action:@selector( sendFile: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[items addObject:item];
	}

	if( ! [[MVBuddyListController sharedBuddyList] buddyForUser:self] ) {
		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Add To Buddy List", "add to buddy list contextual menu") action:@selector( addBuddy: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[items addObject:item];
	}

	if( ! [self isLocalUser] ) {
		[items addObject:[NSMenuItem separatorItem]];

		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Ignore", "ignore user contextual menu") action:@selector( toggleIgnore: ) keyEquivalent:@""] autorelease];
		[item setTarget:self];
		[items addObject:item];
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

- (IBAction) sendFile:(id) sender {
	BOOL passive = [[NSUserDefaults standardUserDefaults] boolForKey:@"JVSendFilesPassively"];
	NSString *path = nil;
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setResolvesAliases:YES];
	[panel setCanChooseFiles:YES];
	[panel setCanChooseDirectories:NO];
	[panel setAllowsMultipleSelection:YES];

	NSView *view = [[[NSView alloc] initWithFrame:NSMakeRect( 0., 0., 200., 28. )] autorelease];
	[view setAutoresizingMask:( NSViewWidthSizable | NSViewMaxXMargin )];

	NSButton *passiveButton = [[[NSButton alloc] initWithFrame:NSMakeRect( 0., 6., 200., 18. )] autorelease];
	[[passiveButton cell] setButtonType:NSSwitchButton];
	[passiveButton setState:passive];
	[passiveButton setTitle:NSLocalizedString( @"Send File Passively", "send files passively file send open dialog button" )];
	[passiveButton sizeToFit];

	NSRect frame = [view frame];
	frame.size.width = NSWidth( [passiveButton frame] );

	[view setFrame:frame];
	[view addSubview:passiveButton];

	[panel setAccessoryView:view];

	if( [panel runModalForTypes:nil] == NSOKButton ) {
		NSEnumerator *enumerator = [[panel filenames] objectEnumerator];
		passive = [passiveButton state];
		while( ( path = [enumerator nextObject] ) )
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
	KAIgnoreRule *rule = [self tempIgnoreRule];
	if( rule ) [rules removeObjectIdenticalTo:rule];
	else [rules addObject:[KAIgnoreRule ruleForUser:[self nickname] message:nil inRooms:nil isPermanent:NO friendlyName:[NSString stringWithFormat:@"%@ %@", [self displayName], NSLocalizedString( @" (Temporary)", "temporary ignore title suffix" )]]];
}
@end
