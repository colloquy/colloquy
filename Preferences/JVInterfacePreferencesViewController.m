#import "JVInterfacePreferencesViewController.h"

#import "JVChatController.h"
#import "JVChatRoomPanel.h"
#import "JVChatViewCriterionController.h"
#import "JVDetailCell.h"
#import "JVViewCell.h"


static NSString *JVInterfacePreferencesWindowDragPboardType = @"JVInterfacePreferencesWindowDragPboardType";


@interface JVInterfacePreferencesViewController() <NSTableViewDataSource, NSTableViewDelegate>

@property(nonatomic, strong) NSMutableArray *windowSets;
@property(nonatomic, strong) NSMutableArray *editingRuleCriterion;
@property(nonatomic, assign) NSUInteger selectedWindowSet;
@property(nonatomic, assign) NSUInteger selectedRuleSet;
@property(nonatomic, assign) NSUInteger origRuleEditHeight;
@property(nonatomic, assign) BOOL makingNewWindowSet;
@property(nonatomic, assign) BOOL makingNewRuleSet;


@property(nonatomic, strong) IBOutlet NSTableView *windowSetsTable;
@property(nonatomic, strong) IBOutlet NSTableView *rulesTable;
@property(nonatomic, strong) IBOutlet NSButton *deleteWindowButton;
@property(nonatomic, strong) IBOutlet NSButton *editWindowButton;
@property(nonatomic, strong) IBOutlet NSButton *deleteRuleButton;
@property(nonatomic, strong) IBOutlet NSButton *editRuleButton;
@property(nonatomic, strong) IBOutlet NSPopUpButton *drawerSide;
@property(nonatomic, strong) IBOutlet NSPopUpButton *interfaceStyle;

@property(nonatomic, strong) IBOutlet NSPanel *windowEditPanel;
@property(nonatomic, strong) IBOutlet NSTextField *windowTitle;
@property(nonatomic, strong) IBOutlet NSButton *rememberPanels;
@property(nonatomic, strong) IBOutlet NSButton *windowEditSaveButton;

@property(nonatomic, strong) IBOutlet NSWindow *ruleEditPanel;
@property(nonatomic, strong) IBOutlet NSTableView *ruleEditTable;
@property(nonatomic, strong) IBOutlet NSPopUpButton *ruleOperation;
@property(nonatomic, strong) IBOutlet NSButton *ignoreCase;

- (void) initializeFromDefaults;

- (NSMutableArray *) selectedRules;
- (NSMutableArray *) editingCriterion;

- (IBAction) addWindowSet:(id) sender;
- (IBAction) editWindowSet:(id) sender;
- (IBAction) saveWindowSet:(id) sender;
- (IBAction) cancelWindowSet:(id) sender;

- (IBAction) addRuleCriterionRow:(id) sender;
- (IBAction) removeRuleCriterionRow:(id) sender;

- (IBAction) addRuleSet:(id) sender;
- (IBAction) editRuleSet:(id) sender;
- (IBAction) saveRuleSet:(id) sender;
- (IBAction) cancelRuleSet:(id) sender;

- (IBAction) changeSortByStatus:(id) sender;
- (IBAction) changeShowFullRoomName:(id) sender;

- (IBAction) clear:(id) sender;

@end


@implementation JVInterfacePreferencesViewController

- (void) awakeFromNib {
	NSTableColumn *column = [self.windowSetsTable tableColumnWithIdentifier:@"window"];
	JVDetailCell *prototypeCell = [JVDetailCell new];
	[prototypeCell setFont:[NSFont toolTipsFontOfSize:11.]];
	[column setDataCell:prototypeCell];
	
	column = [self.rulesTable tableColumnWithIdentifier:@"rule"];
	prototypeCell = [JVDetailCell new];
	[prototypeCell setFont:[NSFont toolTipsFontOfSize:11.]];
	[column setDataCell:prototypeCell];
	
	[self.rulesTable setIntercellSpacing:NSMakeSize( 6., 2. )];
	
	[self.windowSetsTable setTarget:self];
	[self.windowSetsTable setDoubleAction:@selector( editWindowSet: )];
	[self.windowSetsTable registerForDraggedTypes:@[JVInterfacePreferencesWindowDragPboardType]];
	
	[self.rulesTable setTarget:self];
	[self.rulesTable setDoubleAction:@selector( editRuleSet: )];
	
	self.origRuleEditHeight = NSHeight( [[self.ruleEditPanel contentView] frame] ) - 30;
	[self.ruleEditTable setDataSource:self];
	[self.ruleEditTable setDelegate:self];
	[self.ruleEditTable setRefusesFirstResponder:YES];
	
	column = [self.ruleEditTable tableColumnWithIdentifier:@"criteria"];
	[column setDataCell:[JVViewCell new]];
	
	[self initializeFromDefaults];
}


#pragma mark - MASPreferencesViewController

- (NSString *) identifier {
	return @"JVInterfacePreferencesViewController";
}

- (NSImage *) toolbarItemImage {
	return [NSImage imageNamed:@"InterfacePreferences"];
}

- (NSString *) toolbarItemLabel {
	return NSLocalizedString( @"Interface", "interface preference pane name" );
}

- (BOOL)hasResizableWidth {
	return NO;
}

- (BOOL)hasResizableHeight {
	return NO;
}


#pragma mark - Private

- (void) initializeFromDefaults {
	NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:@"JVChatWindowRuleSets"];

	self.windowSets = ( [data length] ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : [NSMutableArray array] );

	NSMutableDictionary *info = nil;
	BOOL haveCurrentWindow = NO;
	BOOL haveNewWindow = NO;
	BOOL haveServerWindow = NO;

	for( info in self.windowSets ) {
		NSString *value = [info objectForKey:@"special"];
		if( [[info objectForKey:@"currentWindow"] boolValue] ) { // old method
			[info setObject:@"currentWindow" forKey:@"special"]; // add new method of identifying
			[info removeObjectForKey:@"currentWindow"]; // remove the old method of identifying
			haveCurrentWindow = YES;
		} else if( [value isEqualToString:@"currentWindow"] ) haveCurrentWindow = YES;
		else if( [value isEqualToString:@"newWindow"] ) haveNewWindow = YES;
		else if( [value isEqualToString:@"serverWindow"] ) haveServerWindow = YES;
	}

	if( ! haveCurrentWindow ) {
		info = [NSMutableDictionary dictionary];
		[self.windowSets addObject:info];

		[info setObject:@"currentWindow" forKey:@"special"];
		[info setObject:[NSString locallyUniqueString] forKey:@"identifier"];
		[info setObject:[NSMutableArray array] forKey:@"rules"];
	}

	if( ! haveNewWindow ) {
		info = [NSMutableDictionary dictionary];
		[self.windowSets addObject:info];

		[info setObject:@"newWindow" forKey:@"special"];
		[info setObject:[NSString locallyUniqueString] forKey:@"identifier"];
		[info setObject:[NSMutableArray array] forKey:@"rules"];
	}

	if( ! haveServerWindow ) {
		info = [NSMutableDictionary dictionary];
		[self.windowSets addObject:info];

		[info setObject:@"serverWindow" forKey:@"special"];
		[info setObject:[NSString locallyUniqueString] forKey:@"identifier"];
		[info setObject:[NSMutableArray array] forKey:@"rules"];
	}

	[self.windowSetsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	[self.windowSetsTable reloadData];
}


- (void) saveWindowRules {
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.windowSets];
	[[NSUserDefaults standardUserDefaults] setObject:data forKey:@"JVChatWindowRuleSets"];
}

#pragma mark -

- (NSString *) titleForRules:(NSArray *) rules booleanAndOperation:(BOOL) operation {
	NSMutableString *title = [NSMutableString string];
	BOOL first = YES;

	for( id rule in rules ) {
		if( ! first && operation ) [title appendString:NSLocalizedString( @" and ", "operation label, interface preferences" )];
		else if( ! first && ! operation ) [title appendString:NSLocalizedString( @" or ", "operation label, interface preferences" )];
		[title appendString:[rule description]];
		first = NO;
	}

	return title;
}

- (NSImage *) iconForRules:(NSArray *) rules {
	NSImage *icon = [NSImage imageNamed:NSImageNameActionTemplate];
	icon.size = NSMakeSize(16., 16.);
	BOOL multipleType = NO;

	for( JVChatViewCriterionController *rule in rules ) {
		if( ! multipleType && [rule kind] == JVChatViewTypeCriterionKind && [rule operation] == JVChatViewIsEqualCriterionOperation ) {
			if( [[rule query] intValue] == 1 ) icon = [NSImage imageNamed:@"room"];
			else if( [[rule query] intValue] == 2 ) icon = [NSImage imageNamed:@"privateChatTabNewMessage"];
			else if( [[rule query] intValue] == 12 ) {
				icon = [NSImage imageNamed:@"smartTranscript"];
				icon.size = NSMakeSize(16, 16);
			}
			multipleType = YES;
		} else if( multipleType && [rule kind] == JVChatViewTypeCriterionKind ) {
			icon = [NSImage imageNamed:@"gearSmall"];
			break;
		}
	}

	return icon;
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *) view {
	if( view == self.windowSetsTable ) return [self.windowSets count];
	else if( view == self.rulesTable ) {
		if( [self.windowSets count] < self.selectedWindowSet ) return 0;
		NSDictionary *info = [self.windowSets objectAtIndex:self.selectedWindowSet];
		return [(NSArray *)[info objectForKey:@"rules"] count];
	} else if( view == self.ruleEditTable ) {
		return [[self editingCriterion] count];
	}

	return 0;
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( view == self.windowSetsTable ) {
		NSDictionary *info = [self.windowSets objectAtIndex:row];
		if( [[info objectForKey:@"special"] isEqualToString:@"currentWindow"] ) return [NSImage imageNamed:@"targetWindow"];
		else if( [[info objectForKey:@"special"] isEqualToString:@"newWindow"] ) return [NSImage imageNamed:@"newWindow"];
		else if( [[info objectForKey:@"special"] isEqualToString:@"serverWindow"] ) return [NSImage imageNamed:@"serverWindow"];
		else return [NSImage imageNamed:@"window"];
	} else if( view == self.rulesTable ) {
		NSArray *ruleSets = [self selectedRules];
		NSDictionary *info = [ruleSets objectAtIndex:row];
		return [self iconForRules:[info objectForKey:@"criterion"]];
	} else return nil;
}

- (void) tableView:(NSTableView *) view willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( view == self.windowSetsTable ) {
		NSDictionary *info = [self.windowSets objectAtIndex:row];
		if( [[info objectForKey:@"special"] isEqualToString:@"currentWindow"] )
			[(JVDetailCell *) cell setMainText:NSLocalizedString( @"Focused Window", "focused window label, interface preferences" )];
		else if( [[info objectForKey:@"special"] isEqualToString:@"newWindow"] )
			[(JVDetailCell *) cell setMainText:NSLocalizedString( @"New Window", "new window label, interface preferences" )];
		else if( [[info objectForKey:@"special"] isEqualToString:@"serverWindow"] )
			[(JVDetailCell *) cell setMainText:NSLocalizedString( @"Server Window", "server window label, interface preferences" )];
		else [(JVDetailCell *) cell setMainText:[info objectForKey:@"title"]];

		NSUInteger c = [(NSArray *)[info objectForKey:@"rules"] count];
		if( c == 0 ) [(JVDetailCell *) cell setInformationText:NSLocalizedString( @"No rules", "no rules info label" )];
		else if( c == 1 ) [(JVDetailCell *) cell setInformationText:NSLocalizedString( @"1 rule", "one rule info label" )];
		else [(JVDetailCell *) cell setInformationText:[NSString stringWithFormat:NSLocalizedString( @"%d rules", "number of rules info label" ), c]];
	} else if( view == self.rulesTable ) {
		NSArray *ruleSets = [self selectedRules];
		NSDictionary *info = [ruleSets objectAtIndex:row];
		[(JVDetailCell *) cell setMainText:[self titleForRules:[info objectForKey:@"criterion"] booleanAndOperation:( [[info objectForKey:@"operation"] intValue] == 2 )]];
	} else if( view == self.ruleEditTable ) {
		if( [[column identifier] isEqualToString:@"criteria"] ) {
			[(JVViewCell *)cell setView:[(JVChatViewCriterionController *)[[self editingCriterion] objectAtIndex:row] view]];
		} else if( [[column identifier] isEqualToString:@"remove"] ) {
			[cell setEnabled:( [self numberOfRowsInTableView:view] > 1 )];
		}
	}
}

- (NSString *) tableView:(NSTableView *) view toolTipForTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( view == self.rulesTable ) {
		NSArray *ruleSets = [self selectedRules];
		NSDictionary *info = [ruleSets objectAtIndex:row];
		return [self titleForRules:[info objectForKey:@"criterion"] booleanAndOperation:( [[info objectForKey:@"operation"] intValue] == 2 )];
	}

	return nil;
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	id view = [notification object];
	if( view == self.windowSetsTable ) {
		self.selectedWindowSet = [[self.windowSetsTable selectedRowIndexes] firstIndex];
		NSDictionary *info = [self.windowSets objectAtIndex:self.selectedWindowSet];
		[self.editWindowButton setEnabled:( ! [info objectForKey:@"special"] )];
		[self.deleteWindowButton setEnabled:( ! [info objectForKey:@"special"] )];
		[self.rulesTable reloadData];
	} else if( view == self.rulesTable ) {
		self.selectedRuleSet = [[self.rulesTable selectedRowIndexes] firstIndex];
		[self.editRuleButton setEnabled:( self.selectedRuleSet != NSNotFound )];
		[self.deleteRuleButton setEnabled:( self.selectedRuleSet != NSNotFound )];
	} else if( view == self.ruleEditTable ) {
		[self.ruleEditTable deselectAll:nil];
	}
}

- (BOOL) tableView:(NSTableView *) tableView writeRowsWithIndexes:(NSIndexSet *) rowIndexes toPasteboard:(NSPasteboard *) pboard {
	if( tableView == self.windowSetsTable ) {
		NSInteger row = rowIndexes.lastIndex;
		if( row == -1 ) return NO;

		NSData *data = [NSData dataWithBytes:&row length:sizeof( &row )];

		[pboard declareTypes:@[JVInterfacePreferencesWindowDragPboardType] owner:self];
		[pboard setData:data forType:JVInterfacePreferencesWindowDragPboardType];
		return YES;
	}

	return NO;
}

- (NSDragOperation) tableView:(NSTableView *) view validateDrop:(id <NSDraggingInfo>) info proposedRow:(NSInteger) row proposedDropOperation:(NSTableViewDropOperation) operation {
	if( view == self.windowSetsTable && [[info draggingPasteboard] availableTypeFromArray:@[JVInterfacePreferencesWindowDragPboardType]] ) {
		if( operation == NSTableViewDropOn && row != -1 ) return NSDragOperationNone;

		NSInteger index = -1;
		[[[info draggingPasteboard] dataForType:JVInterfacePreferencesWindowDragPboardType] getBytes:&index];

		if( row >= 0 && row != index && ( row - 1 ) != index ) return NSDragOperationEvery;
		else if( row == -1 ) return NSDragOperationNone;

		return NSDragOperationEvery;
	}

	return NSDragOperationNone;
}

- (BOOL) tableView:(NSTableView *) view acceptDrop:(id <NSDraggingInfo>) info row:(NSInteger) row dropOperation:(NSTableViewDropOperation) operation {
	if( view == self.windowSetsTable && [[info draggingPasteboard] availableTypeFromArray:@[JVInterfacePreferencesWindowDragPboardType]] ) {
		NSInteger index = -1;
		[[[info draggingPasteboard] dataForType:JVInterfacePreferencesWindowDragPboardType] getBytes:&index];
		if( row > index ) row--;

		id item = [self.windowSets objectAtIndex:index];
		[self.windowSets removeObjectAtIndex:index];
		[self.windowSets insertObject:item atIndex:row];

		[self.windowSetsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		[view reloadData];

		[self saveWindowRules];
		return YES;
	}

	return NO;
}

- (IBAction) clear:(id) sender {
	if( sender == self.windowSetsTable || sender == self.deleteWindowButton ) {
		NSDictionary *info = [self.windowSets objectAtIndex:self.selectedWindowSet];
		if( [info objectForKey:@"special"] ) {
			NSBeep();
			return;
		}

		[self.windowSets removeObjectAtIndex:self.selectedWindowSet];
		[self.windowSetsTable reloadData];

		self.selectedWindowSet = [[self.windowSetsTable selectedRowIndexes] firstIndex];
		[self.rulesTable reloadData];

		info = [self.windowSets objectAtIndex:self.selectedWindowSet];
		[self.editWindowButton setEnabled:( ! [info objectForKey:@"special"] )];
		[self.deleteWindowButton setEnabled:( ! [info objectForKey:@"special"] )];

		[self saveWindowRules];
	} else if( sender == self.rulesTable || sender == self.deleteRuleButton ) {
		[[self selectedRules] removeObjectAtIndex:self.selectedRuleSet];

		[self.rulesTable reloadData];
		[self.windowSetsTable reloadData];

		self.selectedRuleSet = [[self.rulesTable selectedRowIndexes] firstIndex];
		[self.editRuleButton setEnabled:( self.selectedRuleSet != NSNotFound )];
		[self.deleteRuleButton setEnabled:( self.selectedRuleSet != NSNotFound )];

		[self saveWindowRules];
	}
}

#pragma mark -

- (IBAction) addWindowSet:(id) sender {
	NSString *title = [NSString stringWithFormat:NSLocalizedString( @"Window %d", "starting window title, window and a number" ), [self.windowSets count]];
	[self.windowTitle setStringValue:title];
	[self.rememberPanels setState:NSOnState];
	[self.windowEditSaveButton setEnabled:YES];

	self.makingNewWindowSet = YES;

	[[NSApplication sharedApplication] beginSheet:self.windowEditPanel modalForWindow:[self.windowSetsTable window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction) editWindowSet:(id) sender {
	NSDictionary *info = [self.windowSets objectAtIndex:[[self.windowSetsTable selectedRowIndexes] firstIndex]];
	if( [info objectForKey:@"special"] ) return;

	[self.windowTitle setStringValue:[info objectForKey:@"title"]];
	[self.rememberPanels setState:[[info objectForKey:@"rememberPanels"] boolValue]];
	[self.windowEditSaveButton setEnabled:YES];

	self.makingNewWindowSet = NO;

	[[NSApplication sharedApplication] beginSheet:self.windowEditPanel modalForWindow:[self.windowSetsTable window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction) saveWindowSet:(id) sender {
	NSMutableDictionary *info = nil;

	if( self.makingNewWindowSet ) {
		info = [NSMutableDictionary dictionary];
		[self.windowSets addObject:info];

		[info setObject:[NSString locallyUniqueString] forKey:@"identifier"];
		[info setObject:[NSMutableArray array] forKey:@"rules"];
	} else info = [self.windowSets objectAtIndex:self.selectedWindowSet];

	[info setObject:[self.windowTitle stringValue] forKey:@"title"];
	[info setObject:[NSNumber numberWithBool:[self.rememberPanels state]] forKey:@"rememberPanels"];

	[self.windowEditPanel orderOut:nil];
	[[NSApplication sharedApplication] endSheet:self.windowEditPanel];

	[self.windowSetsTable reloadData];

	if( self.makingNewWindowSet ) {
		[self.windowSetsTable scrollRowToVisible:( [self.windowSets count] - 1 )];
		[self.windowSetsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:( [self.windowSets count] - 1 )] byExtendingSelection:NO];
		self.makingNewWindowSet = NO;
	}

	[self saveWindowRules];
}

- (IBAction) cancelWindowSet:(id) sender {
	[self.windowEditPanel orderOut:nil];
	[[NSApplication sharedApplication] endSheet:self.windowEditPanel];
}

#pragma mark -

- (NSMutableArray *) selectedRules {
	if( [self.windowSets count] < self.selectedWindowSet ) return [NSMutableArray array];
	NSDictionary *info = [self.windowSets objectAtIndex:self.selectedWindowSet];
	return [info objectForKey:@"rules"];
}

- (NSMutableArray *) editingCriterion {
	return self.editingRuleCriterion;
}

- (void) updateRuleEditPanelSize {
	NSRect frame = [[self.ruleEditPanel contentView] frame];
	frame.size.height = self.origRuleEditHeight + ( [[self editingCriterion] count] * 30 );
	[self.ruleEditPanel setContentSize:frame.size];

	frame.size.width = 514;
	[self.ruleEditPanel setContentMinSize:frame.size];

	frame.size.width = 800;
	[self.ruleEditPanel setContentMaxSize:frame.size];
}

- (void) reloadRuleEditTableView {
	while( [[self.ruleEditTable subviews] count] > 0 )
		[[[self.ruleEditTable subviews] lastObject] removeFromSuperviewWithoutNeedingDisplay];
	[self.ruleEditTable reloadData];
}

- (void) updateRuleEditKeyViewLoop {
	NSEnumerator *rules = [[self editingCriterion] objectEnumerator];
	JVChatViewCriterionController *previousRule = [rules nextObject];
	JVChatViewCriterionController *rule = nil;

	[self.ruleOperation setNextKeyView:[previousRule firstKeyView]];

	while( ( rule = [rules nextObject] ) ) {
		[[previousRule lastKeyView] setNextKeyView:[rule firstKeyView]];
		previousRule = rule;
	}

	[[previousRule lastKeyView] setNextKeyView:self.ignoreCase];
}

- (void) insertObject:(id) obj inRuleCriterionAtIndex:(NSUInteger) index {
	if( index != NSNotFound ) [[self editingCriterion] insertObject:obj atIndex:( index + 1 )];
	else [[self editingCriterion] addObject:obj];
	[self reloadRuleEditTableView];
}

- (void) removeObjectFromRuleCriterionAtIndex:(NSUInteger) index {
	[[self editingCriterion] removeObjectAtIndex:index];
	[self reloadRuleEditTableView];
}

#pragma mark -

- (IBAction) addRuleCriterionRow:(id) sender {
	JVChatViewCriterionController *criterion = [JVChatViewCriterionController controller];

	[self insertObject:criterion inRuleCriterionAtIndex:[[self.ruleEditTable selectedRowIndexes] lastIndex]];

	if( sender ) {
		NSRect frame = [self.ruleEditPanel frame];
		frame.origin.y -= 30;
		frame.size.height += 30;
		[self.ruleEditPanel setFrame:frame display:YES animate:YES];

		frame.size.width = 514;
		[self.ruleEditPanel setContentMinSize:frame.size];

		frame.size.width = 800;
		[self.ruleEditPanel setContentMaxSize:frame.size];
	}

	[self updateRuleEditKeyViewLoop];
}

- (IBAction) removeRuleCriterionRow:(id) sender {
	[self removeObjectFromRuleCriterionAtIndex:[[self.ruleEditTable selectedRowIndexes] lastIndex]];

	if( sender ) {
		NSRect frame = [self.ruleEditPanel frame];
		frame.origin.y += 30;
		frame.size.height -= 30;
		[self.ruleEditPanel setFrame:frame display:YES animate:YES];

		frame.size.width = 514;
		[self.ruleEditPanel setContentMinSize:frame.size];

		frame.size.width = 800;
		[self.ruleEditPanel setContentMaxSize:frame.size];
	}

	[self updateRuleEditKeyViewLoop];
}

#pragma mark -

- (IBAction) addRuleSet:(id) sender {
	self.makingNewRuleSet = YES;

	self.editingRuleCriterion = [NSMutableArray array];

	[self addRuleCriterionRow:nil];
	[self updateRuleEditPanelSize];
	[[NSApplication sharedApplication] beginSheet:self.ruleEditPanel modalForWindow:[self.rulesTable window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction) editRuleSet:(id) sender {
	if( self.selectedRuleSet == NSNotFound ) return;

	self.makingNewRuleSet = NO;

	NSMutableDictionary *info = [[self selectedRules] objectAtIndex:self.selectedRuleSet];

	self.editingRuleCriterion = [info objectForKey:@"criterion"];

	[self.ignoreCase setState:[[info objectForKey:@"ignoreCase"] boolValue]];

	NSInteger operation = [[info objectForKey:@"operation"] intValue];
	if( [self.ruleOperation indexOfItemWithTag:operation] != -1 )
		[self.ruleOperation selectItemAtIndex:[self.ruleOperation indexOfItemWithTag:operation]];

	[self updateRuleEditPanelSize];
	[self reloadRuleEditTableView];
	[[NSApplication sharedApplication] beginSheet:self.ruleEditPanel modalForWindow:[self.rulesTable window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction) saveRuleSet:(id) sender {
	NSMutableDictionary *info = nil;

	if( self.makingNewRuleSet ) {
		info = [NSMutableDictionary dictionary];
		[[self selectedRules] addObject:info];
	} else info = [[self selectedRules] objectAtIndex:self.selectedRuleSet];

	[info setObject:[self editingCriterion] forKey:@"criterion"];
	[info setObject:[NSNumber numberWithLong:[self.ruleOperation selectedTag]] forKey:@"operation"];
	[info setObject:[NSNumber numberWithBool:[self.ignoreCase state]] forKey:@"ignoreCase"];

	[self.ruleEditPanel orderOut:nil];
	[[NSApplication sharedApplication] endSheet:self.ruleEditPanel];

	[self.rulesTable reloadData];
	[self.windowSetsTable reloadData];

	self.editingRuleCriterion = nil;

	if( self.makingNewRuleSet ) {
		[self.rulesTable scrollRowToVisible:( [[self selectedRules] count] - 1 )];
		[self.rulesTable selectRowIndexes:[NSIndexSet indexSetWithIndex:( [[self selectedRules] count] - 1 )] byExtendingSelection:NO];
		self.makingNewRuleSet = NO;
	}

	[self saveWindowRules];
}

- (IBAction) cancelRuleSet:(id) sender {
	self.makingNewRuleSet = NO;

	self.editingRuleCriterion = nil;

	[self.ruleEditPanel orderOut:nil];
	[[NSApplication sharedApplication] endSheet:self.ruleEditPanel];
}

#pragma mark -

- (IBAction) changeSortByStatus:(id) sender {
	for( JVChatRoomPanel *room in [[JVChatController defaultController] chatViewControllersOfClass:[JVChatRoomPanel class]] )
		[room resortMembers];
}

- (IBAction) changeShowFullRoomName:(id) sender {
	for( JVChatRoomPanel *room in [[JVChatController defaultController] chatViewControllersOfClass:[JVChatRoomPanel class]] )
		[[room windowController] reloadListItem:room andChildren:NO];
}
@end
