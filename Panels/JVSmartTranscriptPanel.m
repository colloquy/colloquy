#import "JVChatController.h"
#import "JVTranscriptCriterionController.h"
#import "JVTabbedChatWindowController.h"
#import "JVChatWindowController.h"
#import "JVSmartTranscriptPanel.h"
#import "JVDirectChatPanel.h"
#import "JVChatTranscript.h"
#import "JVChatMessage.h"
#import "JVStyleView.h"
#import "JVViewCell.h"

static NSString *JVToolbarRuleSettingsItemIdentifier = @"JVToolbarRuleSettingsItem";

@implementation JVSmartTranscriptPanel
- (id) init {
	if( ( self = [super init] ) ) {
		_operation = 1;
		_newMessages = 0;
		_origSheetHeight = 0;
		_isActive = NO;
		_ignoreCase = YES;
		_editingRules = nil;
		_rules = nil;
		_title = nil;
	}

	return self;
}

- (id) initWithSettings:(NSDictionary *) settings {
	if( ( self = [self init] ) ) {
		_settingsNibLoaded = [NSBundle loadNibNamed:@"JVSmartTranscriptFilterSheet" owner:self];

		_rules = [[settings objectForKey:@"rules"] mutableCopyWithZone:[self zone]];
		_title = [[settings objectForKey:@"title"] copyWithZone:[self zone]];
		_operation = [[settings objectForKey:@"operation"] intValue];
		_ignoreCase = [[settings objectForKey:@"ignoreCase"] boolValue];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _messageDisplayed: ) name:JVChatMessageWasProcessedNotification object:nil];
	}

	return self;
}

- (id) initWithCoder:(NSCoder *) coder {
	if( [coder allowsKeyedCoding] ) {
		NSMutableDictionary *settings = [NSMutableDictionary dictionary];
		[settings setObject:[coder decodeObjectForKey:@"rules"] forKey:@"rules"];
		[settings setObject:[coder decodeObjectForKey:@"title"] forKey:@"title"];
		[settings setObject:[NSNumber numberWithBool:[coder decodeBoolForKey:@"ignoreCase"]] forKey:@"ignoreCase"];
		[settings setObject:[NSNumber numberWithInt:[coder decodeIntForKey:@"operation"]] forKey:@"operation"];
		return ( self = [self initWithSettings:settings] );
	} else [NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
	return nil;
}

- (void) encodeWithCoder:(NSCoder *) coder {
	if( [coder allowsKeyedCoding] ) {
		[coder encodeObject:[self rules] forKey:@"rules"];
		[coder encodeObject:[self title] forKey:@"title"];
		[coder encodeInt:_operation forKey:@"operation"];
		[coder encodeBool:_ignoreCase forKey:@"ignoreCase"];
	} else [NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_title release];
	[_rules release];
	[_editingRules release];

	_rules = nil;
	_editingRules = nil;
	_title = nil;

	[super dealloc];
}

- (void) awakeFromNib {
	if( ! _settingsNibLoaded ) {
		_origSheetHeight = NSHeight( [[settingsSheet contentView] frame] ) - 30;
		[subviewTableView setDataSource:self];
		[subviewTableView setDelegate:self];
		[subviewTableView setRefusesFirstResponder:YES];

		NSTableColumn *column = [subviewTableView tableColumnWithIdentifier:@"criteria"];
		[column setDataCell:[[JVViewCell new] autorelease]];
	}

	if( ! _nibLoaded ) [super awakeFromNib];

	[display setBodyTemplate:@"smartTranscript"];
}

#pragma mark -

- (NSComparisonResult) compare:(JVSmartTranscriptPanel *) panel {
	return [[self title] compare:[panel title]];
}

#pragma mark -

- (NSString *) title {
	return ( [_title length] ? _title : @"Smart Transcript" );
}

- (NSString *) windowTitle {
	return [self title];
}

- (NSString *) identifier {
	return [NSString stringWithFormat:@"Smart Transcript %@", [self title]];
}

- (NSString *) information {
	return nil;
}

- (NSString *) toolTip {
	NSString *messageCount = @"";
	if( _newMessages == 0 ) messageCount = NSLocalizedString( @"no messages waiting", "no messages waiting room tooltip" );
	else if( _newMessages == 1 ) messageCount = NSLocalizedString( @"1 message waiting", "one message waiting room tooltip" );
	else messageCount = [NSString stringWithFormat:NSLocalizedString( @"%d messages waiting", "messages waiting room tooltip" ), _newMessages];
	return [NSString stringWithFormat:@"%@\n%@", [self title], messageCount];
}

- (NSMenu *) menu {
	NSMenu *menu = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	NSMenuItem *item = nil;

	if( [[[self windowController] allChatViewControllers] count] > 1 ) {
		item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Detach From Window", "detach from window contextual menu item title" ) action:@selector( detachView: ) keyEquivalent:@""] autorelease];
		[item setRepresentedObject:self];
		[item setTarget:[JVChatController defaultController]];
		[menu addItem:item];
	}

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Close", "close contextual menu item title" ) action:@selector( close: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	[menu addItem:[NSMenuItem separatorItem]];

	item = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString( @"Delete", "delete contextual menu item title" ) action:@selector( dispose: ) keyEquivalent:@""] autorelease];
	[item setTarget:self];
	[menu addItem:item];

	return [[menu retain] autorelease];
}

- (NSImage *) icon {
	BOOL smallIcons = [[[self windowController] preferenceForKey:@"small drawer icons"] boolValue];
	if( smallIcons || [_windowController isMemberOfClass:[JVTabbedChatWindowController class]] )
		return [NSImage imageNamed:@"smartTranscriptTab"];
	return [NSImage imageNamed:@"smartTranscript"];
}

- (NSImage *) statusImage {
	if( _isActive && [[[self view] window] isKeyWindow] ) {
		_newMessages = 0;
		return nil;
	}

	if( [_windowController isMemberOfClass:[JVTabbedChatWindowController class]] )
		return ( _newMessages ? [NSImage imageNamed:@"smartTranscriptTabActivity"] : nil );

	return ( _newMessages ? [NSImage imageNamed:@"newMessage"] : nil );
}

#pragma mark -

- (IBAction) dispose:(id) sender {
	[[JVChatController defaultController] disposeSmartTranscript:self];
}

#pragma mark -

- (void) didUnselect {
	_newMessages = 0;
	_isActive = NO;
	[super didUnselect];
}

- (void) didSelect {
	_newMessages = 0;
	_isActive = YES;
	[JVChatController refreshSmartTranscriptMenu];
	[super didSelect];
}

#pragma mark -

- (NSMutableArray *) rules {
	if( ! _rules ) _rules = [[NSMutableArray alloc] init];
	return _rules;
}

- (NSMutableArray *) editingRules {
	if( ! _editingRules ) _editingRules = [[NSMutableArray alloc] init];
	return _editingRules;
}

#pragma mark -

- (void) updateSettingsSheetSize {
	NSRect frame = [[settingsSheet contentView] frame];
	frame.size.height = _origSheetHeight + ( [[self editingRules] count] * 30 );
	[settingsSheet setContentSize:frame.size];

	frame.size.width = 514;
	[settingsSheet setContentMinSize:frame.size];

	frame.size.width = 800;
	[settingsSheet setContentMaxSize:frame.size];
}

- (void) reloadTableView {
	while( [[subviewTableView subviews] count] > 0 )
		[[[subviewTableView subviews] lastObject] removeFromSuperviewWithoutNeedingDisplay];
	[subviewTableView reloadData];
}

- (void) insertObject:(id) obj inCriterionControllersAtIndex:(unsigned int) index {
	if( index != NSNotFound ) [[self editingRules] insertObject:obj atIndex:( index + 1 )];
	else [[self editingRules] addObject:obj];
	[self reloadTableView];
}

- (void) removeObjectFromCriterionControllersAtIndex:(unsigned int) index {
	[[self editingRules] removeObjectAtIndex:index];
	[self reloadTableView];
}

#pragma mark -

- (IBAction) editSettings:(id) sender {
	[[self editingRules] removeAllObjects];

	id rule = nil;
	NSEnumerator *enumerator = [[self rules] objectEnumerator];
	while( ( rule = [enumerator nextObject] ) )
		[[self editingRules] addObject:[[rule copy] autorelease]];

	if( ! [[self editingRules] count] ) [self addRow:nil];

	[self updateSettingsSheetSize];
	[self reloadTableView];

	[titleField setStringValue:[self title]];
	[ignoreCase setState:( _ignoreCase ? NSOnState : NSOffState )];
	if( [operation indexOfItemWithTag:_operation] != -1 ) [operation selectItemAtIndex:[operation indexOfItemWithTag:_operation]];

	[[NSApplication sharedApplication] beginSheet:settingsSheet modalForWindow:[[self windowController] window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction) closeEditSettingsSheet:(id) sender {
	[settingsSheet orderOut:nil];
	[[NSApplication sharedApplication] endSheet:settingsSheet];

	[[self editingRules] removeAllObjects];
	[self reloadTableView];

	if( ! [[self rules] count] )
		[self dispose:nil];
}

- (IBAction) saveSettings:(id) sender {
	[[self rules] setArray:[self editingRules]];
	[self closeEditSettingsSheet:sender];

	[_title autorelease];
	_title = [[titleField stringValue] copy];

	_ignoreCase = ( [ignoreCase state] == NSOnState );
	_operation = [operation selectedTag];

	[_windowController reloadListItem:self andChildren:NO];

	[[JVChatController defaultController] saveSmartTranscripts];
}

#pragma mark -

- (IBAction) clearDisplay:(id) sender {
	[display clear];
}

#pragma mark -

- (unsigned int) newMessagesWaiting {
	return _newMessages;
}

- (void) matchMessage:(JVChatMessage *) message fromView:(id <JVChatViewController>) view {
	BOOL andOperation = ( _operation == 2 );
	BOOL ignore = _ignoreCase;
	BOOL match = ( andOperation ? YES : NO );

	NSEnumerator *rules = [[self rules] objectEnumerator];
	JVTranscriptCriterionController *rule = nil;
	while( ( rule = [rules nextObject] ) ) {
		BOOL localMatch = [rule matchMessage:message fromChatView:view ignoringCase:ignore];
		match = ( andOperation ? ( match & localMatch ) : ( match | localMatch ) );
		if( ! localMatch && andOperation ) break; // fails, this wont match with all rules
		else if( localMatch && ! andOperation ) break; // passes one, this is enough to match under "any rules"
	}

	if( ! match ) return;

	JVMutableChatMessage *localMessage = [[message mutableCopy] autorelease];
	[localMessage setSource:[(JVDirectChatPanel *)view url]];
	[localMessage setIgnoreStatus:JVNotIgnored];

	localMessage = (id) [[self transcript] appendMessage:localMessage];
	[display appendChatMessage:localMessage];

	[self quickSearchMatchMessage:localMessage];

	_newMessages++;
	[_windowController reloadListItem:self andChildren:NO];
	if( ! _isActive ) [JVChatController refreshSmartTranscriptMenu];
}

#pragma mark -

- (void) updateKeyViewLoop {
	NSEnumerator *rules = [[self editingRules] objectEnumerator];
	JVTranscriptCriterionController *previousRule = [rules nextObject];
	JVTranscriptCriterionController *rule = nil;

	[operation setNextKeyView:[previousRule firstKeyView]];

	while( ( rule = [rules nextObject] ) ) {
		[[previousRule lastKeyView] setNextKeyView:[rule firstKeyView]];
		previousRule = rule;
	}

	[[previousRule lastKeyView] setNextKeyView:ignoreCase];
}

- (IBAction) addRow:(id) sender {
	JVTranscriptCriterionController *criterion = [JVTranscriptCriterionController controller];
	[criterion setUsesSmartTranscriptCriterion:YES];

	[self insertObject:criterion inCriterionControllersAtIndex:[[subviewTableView selectedRowIndexes] lastIndex]];

	if( sender ) {
		NSRect frame = [settingsSheet frame];
		frame.origin.y -= 30;
		frame.size.height += 30;
		[settingsSheet setFrame:frame display:YES animate:YES];

		frame.size.width = 514;
		[settingsSheet setContentMinSize:frame.size];

		frame.size.width = 800;
		[settingsSheet setContentMaxSize:frame.size];
	}

	[self updateKeyViewLoop];
}

- (IBAction) removeRow:(id) sender {
	[self removeObjectFromCriterionControllersAtIndex:[[subviewTableView selectedRowIndexes] lastIndex]];

	if( sender ) {
		NSRect frame = [settingsSheet frame];
		frame.origin.y += 30;
		frame.size.height -= 30;
		[settingsSheet setFrame:frame display:YES animate:YES];

		frame.size.width = 514;
		[settingsSheet setContentMinSize:frame.size];

		frame.size.width = 800;
		[settingsSheet setContentMaxSize:frame.size];
	}

	[self updateKeyViewLoop];
}

#pragma mark -

- (int) numberOfRowsInTableView:(NSTableView *) tableView {
	return [[self editingRules] count];
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	[subviewTableView deselectAll:nil];
}

- (void) tableView:(NSTableView *) tableView willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) tableColumn row:(int) row {
	if( [[tableColumn identifier] isEqualToString:@"criteria"] ) {
		[(JVViewCell *)cell setView:[(JVTranscriptCriterionController *)[[self editingRules] objectAtIndex:row] view]];
	} else if( [[tableColumn identifier] isEqualToString:@"remove"] ) {
		[cell setEnabled:( [self numberOfRowsInTableView:tableView] > 1 )];
	}
}

#pragma mark -
#pragma mark Toolbar Support

- (NSToolbar *) toolbar {
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"Smart Transcript"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	return [toolbar autorelease];
}

- (NSToolbarItem *) toolbar:(NSToolbar *) toolbar itemForItemIdentifier:(NSString *) identifier willBeInsertedIntoToolbar:(BOOL) willBeInserted {
	NSToolbarItem *toolbarItem = nil;

	if( [identifier isEqual:JVToolbarRuleSettingsItemIdentifier] ) {
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];

		[toolbarItem setLabel:NSLocalizedString( @"Settings", "settings toolbar button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Settings", "settings toolbar customize palette name" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Smart Transcript Settings", "smart transcript settings tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"smartTranscriptSettings"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( editSettings: )];
	} else if( [identifier isEqual:JVToolbarClearScrollbackItemIdentifier] ) {
		toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];

		[toolbarItem setLabel:NSLocalizedString( @"Clear", "clear display toolbar button name" )];
		[toolbarItem setPaletteLabel:NSLocalizedString( @"Clear Display", "clear display toolbar customize palette name" )];

		[toolbarItem setToolTip:NSLocalizedString( @"Clear Display", "clear display tooltip" )];
		[toolbarItem setImage:[NSImage imageNamed:@"clear"]];

		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector( clearDisplay: )];
	} else return [super toolbar:toolbar itemForItemIdentifier:identifier willBeInsertedIntoToolbar:willBeInserted];
	return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *) toolbar {
	NSMutableArray *list = [NSMutableArray arrayWithArray:[super toolbarDefaultItemIdentifiers:toolbar]];
	[list addObject:NSToolbarFlexibleSpaceItemIdentifier];
	[list addObject:JVToolbarRuleSettingsItemIdentifier];
	return list;
}

- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *) toolbar {
	NSMutableArray *list = [NSMutableArray arrayWithArray:[super toolbarAllowedItemIdentifiers:toolbar]];
	[list addObject:JVToolbarRuleSettingsItemIdentifier];
	[list addObject:JVToolbarClearScrollbackItemIdentifier];
	return list;
}
@end

#pragma mark -

@implementation JVSmartTranscriptPanel (JVSmartTranscriptPanelPrivate)
- (void) _messageDisplayed:(NSNotification *) notification {
	JVChatMessage *origMessage = [[notification userInfo] objectForKey:@"message"];
	[self matchMessage:origMessage fromView:[notification object]];
}
@end