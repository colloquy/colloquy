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
static NSString *JVToolbarClearItemIdentifier = @"JVToolbarClearItem";

@implementation JVSmartTranscriptPanel
- (id) init {
	if( ( self = [super init] ) ) {
		_newMessages = 0;
		_isActive = NO;
		_rules = nil;
		_title = nil;
		_settings = nil;
	}

	return self;
}

- (id) initWithSettings:(NSDictionary *) settings {
	if( ( self = [self init] ) ) {
		_settingsNibLoaded = [NSBundle loadNibNamed:@"JVSmartTranscriptFilterSheet" owner:self];
		_settings = [settings mutableCopy];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _messageDisplayed: ) name:JVChatMessageWasProcessedNotification object:nil];		
	}

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_settings release];
	[_title release];
	[_rules release];

	_rules = nil;
	_title = nil;
	_settings = nil;

	[super dealloc];
}

- (void) awakeFromNib {
	if( ! _settingsNibLoaded ) {
		[subviewTableView setDataSource:self];
		[subviewTableView setDelegate:self];
		[subviewTableView setRefusesFirstResponder:YES];

		NSTableColumn *column = [subviewTableView tableColumnWithIdentifier:@"criteria"];
		[column setDataCell:[[JVViewCell new] autorelease]];

		[self addRow:nil];
	}

	if( ! _nibLoaded ) [super awakeFromNib];
}

#pragma mark -

- (NSString *) title {
	return @"Smart Transcript";
}

- (NSString *) windowTitle {
	return @"Smart Transcript";
}

- (NSString *) identifier {
	return [NSString stringWithFormat:@"Smart Transcript %@", [self title]];
}

- (NSString *) information {
	return nil;
}

- (NSImage *) icon {
	if( [_windowController isMemberOfClass:[JVTabbedChatWindowController class]] )
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

- (void) didUnselect {
	_newMessages = 0;
	_isActive = NO;
	[super didUnselect];
}

- (void) didSelect {
	_newMessages = 0;
	_isActive = YES;
	[super didSelect];
}

#pragma mark -

- (NSMutableArray *) criterionControllers {
	if( ! _rules ) _rules = [[NSMutableArray alloc] init];
	return _rules;
}

- (void) reloadTableView {
	while( [[subviewTableView subviews] count] > 0 )
		[[[subviewTableView subviews] lastObject] removeFromSuperviewWithoutNeedingDisplay];
	[subviewTableView reloadData];
}

- (void) insertObject:(id) obj inCriterionControllersAtIndex:(unsigned int) index {
	if( index != NSNotFound ) [[self criterionControllers] insertObject:obj atIndex:( index + 1 )];
	else [[self criterionControllers] addObject:obj];
	[self reloadTableView];
}

- (void) removeObjectFromCriterionControllersAtIndex:(unsigned int) index {
	[[self criterionControllers] removeObjectAtIndex:index];
	[self reloadTableView];
}

#pragma mark -

- (IBAction) editSettings:(id) sender {
	[[NSApplication sharedApplication] beginSheet:settingsSheet modalForWindow:[[self windowController] window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction) closeEditSettingsSheet:(id) sender {
	[settingsSheet orderOut:nil];
	[[NSApplication sharedApplication] endSheet:settingsSheet];
}

- (IBAction) saveSettings:(id) sender {
	[self closeEditSettingsSheet:sender];
}

#pragma mark -

- (IBAction) clearDisplay:(id) sender {
	[display clear];
}

#pragma mark -

- (void) matchMessage:(JVChatMessage *) message fromView:(id <JVChatViewController>) view {
	BOOL andOperation = ( [operation selectedTag] == 2 );
	BOOL ignore = ( [ignoreCase state] == NSOnState );
	BOOL match = ( andOperation ? YES : NO );

	NSEnumerator *rules = [[self criterionControllers] objectEnumerator];
	JVTranscriptCriterionController *rule = nil;
	while( ( rule = [rules nextObject] ) ) {
		BOOL localMatch = [rule matchMessage:message ignoreCase:ignore];
		match = ( andOperation ? ( match & localMatch ) : ( match | localMatch ) );
		if( ! localMatch && andOperation ) break; // fails, this wont match with all rules
		else if( localMatch && ! andOperation ) break; // passes one, this is enough to match under "any rules"
	}

	if( ! match ) return;

	JVMutableChatMessage *localMessage = [[message mutableCopy] autorelease];
	[localMessage setSource:[(JVDirectChatPanel *)view url]];

	localMessage = (id) [[self transcript] appendMessage:localMessage];
	[display appendChatMessage:localMessage];	

	_newMessages++;
	[_windowController reloadListItem:self andChildren:NO];
}

#pragma mark -

- (void) updateKeyViewLoop {
	NSEnumerator *rules = [[self criterionControllers] objectEnumerator];
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
	[self insertObject:criterion inCriterionControllersAtIndex:[[subviewTableView selectedRowIndexes] lastIndex]];

	if( sender ) {
		NSRect frame = [settingsSheet frame];
		frame.origin.y -= 30;
		frame.size.height += 30;
		[settingsSheet setFrame:frame display:YES animate:YES];

		frame.size.width = 514;
		[settingsSheet setMinSize:frame.size];

		frame.size.width = 800;
		[settingsSheet setMaxSize:frame.size];
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
		[settingsSheet setMinSize:frame.size];

		frame.size.width = 800;
		[settingsSheet setMaxSize:frame.size];
	}

	[self updateKeyViewLoop];
}

#pragma mark -

- (int) numberOfRowsInTableView:(NSTableView *) tableView {
	return [[self criterionControllers] count];
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	[subviewTableView deselectAll:nil];
}

- (void) tableView:(NSTableView *) tableView willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) tableColumn row:(int) row {
	if( [[tableColumn identifier] isEqualToString:@"criteria"] ) {
		[(JVViewCell *)cell setView:[(JVTranscriptCriterionController *)[[self criterionControllers] objectAtIndex:row] view]];
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
	} else if( [identifier isEqual:JVToolbarClearItemIdentifier] ) {
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
	[list addObject:JVToolbarClearItemIdentifier];
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