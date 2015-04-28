#import "JVInterfacePreferences.h"
#import "JVChatViewCriterionController.h"
#import "JVChatController.h"
#import "JVChatRoomPanel.h"
#import "JVDetailCell.h"
#import "JVViewCell.h"

static NSString *JVInterfacePreferencesWindowDragPboardType = @"JVInterfacePreferencesWindowDragPboardType";

@implementation JVInterfacePreferences
- (void) dealloc {
	[windowSetsTable setDataSource:nil];
	[windowSetsTable setDelegate:nil];

	[rulesTable setDataSource:nil];
	[rulesTable setDelegate:nil];

	[ruleEditTable setDataSource:nil];
	[ruleEditTable setDelegate:nil];
}

#pragma mark -

- (NSString *) preferencesNibName {
	return @"JVInterfacePreferences";
}

- (BOOL) hasChangesPending {
	return NO;
}

- (NSImage *) imageForPreferenceNamed:(NSString *) name {
	return [NSImage imageNamed:@"InterfacePreferences"];
}

- (BOOL) isResizable {
	return NO;
}

- (void) awakeFromNib {
	NSTableColumn *column = [windowSetsTable tableColumnWithIdentifier:@"window"];
	JVDetailCell *prototypeCell = [JVDetailCell new];
	[prototypeCell setFont:[NSFont toolTipsFontOfSize:11.]];
	[column setDataCell:prototypeCell];

	column = [rulesTable tableColumnWithIdentifier:@"rule"];
	prototypeCell = [JVDetailCell new];
	[prototypeCell setFont:[NSFont toolTipsFontOfSize:11.]];
	[column setDataCell:prototypeCell];

	[rulesTable setIntercellSpacing:NSMakeSize( 6., 2. )];

	[windowSetsTable setTarget:self];
	[windowSetsTable setDoubleAction:@selector( editWindowSet: )];
	[windowSetsTable registerForDraggedTypes:@[JVInterfacePreferencesWindowDragPboardType]];

	[rulesTable setTarget:self];
	[rulesTable setDoubleAction:@selector( editRuleSet: )];

	_origRuleEditHeight = NSHeight( [[ruleEditPanel contentView] frame] ) - 30;
	[ruleEditTable setDataSource:self];
	[ruleEditTable setDelegate:self];
	[ruleEditTable setRefusesFirstResponder:YES];

	column = [ruleEditTable tableColumnWithIdentifier:@"criteria"];
	[column setDataCell:[JVViewCell new]];
}

- (void) initializeFromDefaults {
	NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:@"JVChatWindowRuleSets"];

	_windowSets = ( [data length] ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : [NSMutableArray array] );

	NSMutableDictionary *info = nil;
	BOOL haveCurrentWindow = NO;
	BOOL haveNewWindow = NO;
	BOOL haveServerWindow = NO;

	for( info in _windowSets ) {
		NSString *value = info[@"special"];
		if( [info[@"currentWindow"] boolValue] ) { // old method
			info[@"special"] = @"currentWindow"; // add new method of identifying
			[info removeObjectForKey:@"currentWindow"]; // remove the old method of identifying
			haveCurrentWindow = YES;
		} else if( [value isEqualToString:@"currentWindow"] ) haveCurrentWindow = YES;
		else if( [value isEqualToString:@"newWindow"] ) haveNewWindow = YES;
		else if( [value isEqualToString:@"serverWindow"] ) haveServerWindow = YES;
	}

	if( ! haveCurrentWindow ) {
		info = [NSMutableDictionary dictionary];
		[_windowSets addObject:info];

		info[@"special"] = @"currentWindow";
		info[@"identifier"] = [NSString locallyUniqueString];
		info[@"rules"] = [NSMutableArray array];
	}

	if( ! haveNewWindow ) {
		info = [NSMutableDictionary dictionary];
		[_windowSets addObject:info];

		info[@"special"] = @"newWindow";
		info[@"identifier"] = [NSString locallyUniqueString];
		info[@"rules"] = [NSMutableArray array];
	}

	if( ! haveServerWindow ) {
		info = [NSMutableDictionary dictionary];
		[_windowSets addObject:info];

		info[@"special"] = @"serverWindow";
		info[@"identifier"] = [NSString locallyUniqueString];
		info[@"rules"] = [NSMutableArray array];
	}

	[windowSetsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	[windowSetsTable reloadData];
}

#pragma mark -

- (void) saveWindowRules {
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_windowSets];
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
	BOOL multipleType = NO;

	for( JVChatViewCriterionController *rule in rules ) {
		if( ! multipleType && [rule kind] == JVChatViewTypeCriterionKind && [rule operation] == JVChatViewIsEqualCriterionOperation ) {
			if( [[rule query] intValue] == 1 ) icon = [NSImage imageNamed:@"roomIcon"];
			else if( [[rule query] intValue] == 2 ) icon = [NSImage imageNamed:@"privateChatTabNewMessage"];
			else if( [[rule query] intValue] == 12 ) icon = [NSImage imageNamed:@"smartTranscriptTab"];
			multipleType = YES;
		} else if( multipleType && [rule kind] == JVChatViewTypeCriterionKind ) {
			icon = [NSImage imageNamed:NSImageNameActionTemplate];
			break;
		}
	}

	return icon;
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *) view {
	if( view == windowSetsTable ) return [_windowSets count];
	else if( view == rulesTable ) {
		if( [_windowSets count] < _selectedWindowSet ) return 0;
		NSDictionary *info = _windowSets[_selectedWindowSet];
		return [(NSArray *)info[@"rules"] count];
	} else if( view == ruleEditTable ) {
		return [[self editingCriterion] count];
	}

	return 0;
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( view == windowSetsTable ) {
		NSDictionary *info = _windowSets[row];
		if( [info[@"special"] isEqualToString:@"currentWindow"] ) return [NSImage imageNamed:@"targetWindow"];
		else if( [info[@"special"] isEqualToString:@"newWindow"] ) return [NSImage imageNamed:@"newWindow"];
		else if( [info[@"special"] isEqualToString:@"serverWindow"] ) return [NSImage imageNamed:@"serverWindow"];
		else return [NSImage imageNamed:@"window"];
	} else if( view == rulesTable ) {
		NSArray *ruleSets = [self selectedRules];
		NSDictionary *info = ruleSets[row];
		return [self iconForRules:info[@"criterion"]];
	} else return nil;
}

- (void) tableView:(NSTableView *) view willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( view == windowSetsTable ) {
		NSDictionary *info = _windowSets[row];
		if( [info[@"special"] isEqualToString:@"currentWindow"] )
			[(JVDetailCell *) cell setMainText:NSLocalizedString( @"Focused Window", "focused window label, interface preferences" )];
		else if( [info[@"special"] isEqualToString:@"newWindow"] )
			[(JVDetailCell *) cell setMainText:NSLocalizedString( @"New Window", "new window label, interface preferences" )];
		else if( [info[@"special"] isEqualToString:@"serverWindow"] )
			[(JVDetailCell *) cell setMainText:NSLocalizedString( @"Server Window", "server window label, interface preferences" )];
		else [(JVDetailCell *) cell setMainText:info[@"title"]];

		NSUInteger c = [(NSArray *)info[@"rules"] count];
		if( c == 0 ) [(JVDetailCell *) cell setInformationText:NSLocalizedString( @"No rules", "no rules info label" )];
		else if( c == 1 ) [(JVDetailCell *) cell setInformationText:NSLocalizedString( @"1 rule", "one rule info label" )];
		else [(JVDetailCell *) cell setInformationText:[NSString stringWithFormat:NSLocalizedString( @"%d rules", "number of rules info label" ), c]];
	} else if( view == rulesTable ) {
		NSArray *ruleSets = [self selectedRules];
		NSDictionary *info = ruleSets[row];
		[(JVDetailCell *) cell setMainText:[self titleForRules:info[@"criterion"] booleanAndOperation:( [info[@"operation"] intValue] == 2 )]];
	} else if( view == ruleEditTable ) {
		if( [[column identifier] isEqualToString:@"criteria"] ) {
			[(JVViewCell *)cell setView:[(JVChatViewCriterionController *)[self editingCriterion][row] view]];
		} else if( [[column identifier] isEqualToString:@"remove"] ) {
			[cell setEnabled:( [self numberOfRowsInTableView:view] > 1 )];
		}
	}
}

- (NSString *) tableView:(NSTableView *) view toolTipForTableColumn:(NSTableColumn *) column row:(NSInteger) row {
	if( view == rulesTable ) {
		NSArray *ruleSets = [self selectedRules];
		NSDictionary *info = ruleSets[row];
		return [self titleForRules:info[@"criterion"] booleanAndOperation:( [info[@"operation"] intValue] == 2 )];
	}

	return nil;
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	id view = [notification object];
	if( view == windowSetsTable ) {
		_selectedWindowSet = [[windowSetsTable selectedRowIndexes] firstIndex];
		NSDictionary *info = _windowSets[_selectedWindowSet];
		[editWindowButton setEnabled:( ! info[@"special"] )];
		[deleteWindowButton setEnabled:( ! info[@"special"] )];
		[rulesTable reloadData];
	} else if( view == rulesTable ) {
		_selectedRuleSet = [[rulesTable selectedRowIndexes] firstIndex];
		[editRuleButton setEnabled:( _selectedRuleSet != NSNotFound )];
		[deleteRuleButton setEnabled:( _selectedRuleSet != NSNotFound )];
	} else if( view == ruleEditTable ) {
		[ruleEditTable deselectAll:nil];
	}
}

- (BOOL) tableView:(NSTableView *) view writeRows:(NSArray *) rows toPasteboard:(NSPasteboard *) board {
	if( view == windowSetsTable ) {
		NSInteger row = [[rows lastObject] intValue];
		if( row == -1 ) return NO;

		NSData *data = [NSData dataWithBytes:&row length:sizeof( &row )];

		[board declareTypes:@[JVInterfacePreferencesWindowDragPboardType] owner:self];
		[board setData:data forType:JVInterfacePreferencesWindowDragPboardType];
		return YES;
	}

	return NO;
}

- (NSDragOperation) tableView:(NSTableView *) view validateDrop:(id <NSDraggingInfo>) info proposedRow:(NSInteger) row proposedDropOperation:(NSTableViewDropOperation) operation {
	if( view == windowSetsTable && [[info draggingPasteboard] availableTypeFromArray:@[JVInterfacePreferencesWindowDragPboardType]] ) {
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
	if( view == windowSetsTable && [[info draggingPasteboard] availableTypeFromArray:@[JVInterfacePreferencesWindowDragPboardType]] ) {
		NSInteger index = -1;
		[[[info draggingPasteboard] dataForType:JVInterfacePreferencesWindowDragPboardType] getBytes:&index];
		if( row > index ) row--;

		id item = _windowSets[index];
		[_windowSets removeObjectAtIndex:index];
		[_windowSets insertObject:item atIndex:row];

		[windowSetsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		[view reloadData];

		[self saveWindowRules];
		return YES;
	}

	return NO;
}

- (void) clear:(id) sender {
	if( sender == windowSetsTable || sender == deleteWindowButton ) {
		NSDictionary *info = _windowSets[_selectedWindowSet];
		if( info[@"special"] ) {
			NSBeep();
			return;
		}

		[_windowSets removeObjectAtIndex:_selectedWindowSet];
		[windowSetsTable reloadData];

		_selectedWindowSet = [[windowSetsTable selectedRowIndexes] firstIndex];
		[rulesTable reloadData];

		info = _windowSets[_selectedWindowSet];
		[editWindowButton setEnabled:( ! info[@"special"] )];
		[deleteWindowButton setEnabled:( ! info[@"special"] )];

		[self saveWindowRules];
	} else if( sender == rulesTable || sender == deleteRuleButton ) {
		[[self selectedRules] removeObjectAtIndex:_selectedRuleSet];

		[rulesTable reloadData];
		[windowSetsTable reloadData];

		_selectedRuleSet = [[rulesTable selectedRowIndexes] firstIndex];
		[editRuleButton setEnabled:( _selectedRuleSet != NSNotFound )];
		[deleteRuleButton setEnabled:( _selectedRuleSet != NSNotFound )];

		[self saveWindowRules];
	}
}

#pragma mark -

- (IBAction) addWindowSet:(id) sender {
	NSString *title = [NSString stringWithFormat:NSLocalizedString( @"Window %d", "starting window title, window and a number" ), [_windowSets count]];
	[windowTitle setStringValue:title];
	[rememberPanels setState:NSOnState];
	[windowEditSaveButton setEnabled:YES];

	_makingNewWindowSet = YES;

	[[NSApplication sharedApplication] beginSheet:windowEditPanel modalForWindow:[windowSetsTable window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction) editWindowSet:(id) sender {
	NSDictionary *info = _windowSets[[[windowSetsTable selectedRowIndexes] firstIndex]];
	if( info[@"special"] ) return;

	[windowTitle setStringValue:info[@"title"]];
	[rememberPanels setState:[info[@"rememberPanels"] boolValue]];
	[windowEditSaveButton setEnabled:YES];

	_makingNewWindowSet = NO;

	[[NSApplication sharedApplication] beginSheet:windowEditPanel modalForWindow:[windowSetsTable window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction) saveWindowSet:(id) sender {
	NSMutableDictionary *info = nil;

	if( _makingNewWindowSet ) {
		info = [NSMutableDictionary dictionary];
		[_windowSets addObject:info];

		info[@"identifier"] = [NSString locallyUniqueString];
		info[@"rules"] = [NSMutableArray array];
	} else info = _windowSets[_selectedWindowSet];

	info[@"title"] = [windowTitle stringValue];
	info[@"rememberPanels"] = [NSNumber numberWithBool:[rememberPanels state]];

	[windowEditPanel orderOut:nil];
	[[NSApplication sharedApplication] endSheet:windowEditPanel];

	[windowSetsTable reloadData];

	if( _makingNewWindowSet ) {
		[windowSetsTable scrollRowToVisible:( [_windowSets count] - 1 )];
		[windowSetsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:( [_windowSets count] - 1 )] byExtendingSelection:NO];
		_makingNewWindowSet = NO;
	}

	[self saveWindowRules];
}

- (IBAction) cancelWindowSet:(id) sender {
	[windowEditPanel orderOut:nil];
	[[NSApplication sharedApplication] endSheet:windowEditPanel];
}

#pragma mark -

- (NSMutableArray *) selectedRules {
	if( [_windowSets count] < _selectedWindowSet ) return [NSMutableArray array];
	NSDictionary *info = _windowSets[_selectedWindowSet];
	return info[@"rules"];
}

- (NSMutableArray *) editingCriterion {
	return _editingRuleCriterion;
}

- (void) updateRuleEditPanelSize {
	NSRect frame = [[ruleEditPanel contentView] frame];
	frame.size.height = _origRuleEditHeight + ( [[self editingCriterion] count] * 30 );
	[ruleEditPanel setContentSize:frame.size];

	frame.size.width = 514;
	[ruleEditPanel setContentMinSize:frame.size];

	frame.size.width = 800;
	[ruleEditPanel setContentMaxSize:frame.size];
}

- (void) reloadRuleEditTableView {
	while( [[ruleEditTable subviews] count] > 0 )
		[[[ruleEditTable subviews] lastObject] removeFromSuperviewWithoutNeedingDisplay];
	[ruleEditTable reloadData];
}

- (void) updateRuleEditKeyViewLoop {
	NSEnumerator *rules = [[self editingCriterion] objectEnumerator];
	JVChatViewCriterionController *previousRule = [rules nextObject];
	JVChatViewCriterionController *rule = nil;

	[ruleOperation setNextKeyView:[previousRule firstKeyView]];

	while( ( rule = [rules nextObject] ) ) {
		[[previousRule lastKeyView] setNextKeyView:[rule firstKeyView]];
		previousRule = rule;
	}

	[[previousRule lastKeyView] setNextKeyView:ignoreCase];
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

	[self insertObject:criterion inRuleCriterionAtIndex:[[ruleEditTable selectedRowIndexes] lastIndex]];

	if( sender ) {
		NSRect frame = [ruleEditPanel frame];
		frame.origin.y -= 30;
		frame.size.height += 30;
		[ruleEditPanel setFrame:frame display:YES animate:YES];

		frame.size.width = 514;
		[ruleEditPanel setContentMinSize:frame.size];

		frame.size.width = 800;
		[ruleEditPanel setContentMaxSize:frame.size];
	}

	[self updateRuleEditKeyViewLoop];
}

- (IBAction) removeRuleCriterionRow:(id) sender {
	[self removeObjectFromRuleCriterionAtIndex:[[ruleEditTable selectedRowIndexes] lastIndex]];

	if( sender ) {
		NSRect frame = [ruleEditPanel frame];
		frame.origin.y += 30;
		frame.size.height -= 30;
		[ruleEditPanel setFrame:frame display:YES animate:YES];

		frame.size.width = 514;
		[ruleEditPanel setContentMinSize:frame.size];

		frame.size.width = 800;
		[ruleEditPanel setContentMaxSize:frame.size];
	}

	[self updateRuleEditKeyViewLoop];
}

#pragma mark -

- (IBAction) addRuleSet:(id) sender {
	_makingNewRuleSet = YES;

	_editingRuleCriterion = [NSMutableArray array];

	[self addRuleCriterionRow:nil];
	[self updateRuleEditPanelSize];
	[[NSApplication sharedApplication] beginSheet:ruleEditPanel modalForWindow:[rulesTable window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction) editRuleSet:(id) sender {
	if( _selectedRuleSet == NSNotFound ) return;

	_makingNewRuleSet = NO;

	NSMutableDictionary *info = [self selectedRules][_selectedRuleSet];

	_editingRuleCriterion = info[@"criterion"];

	[ignoreCase setState:[info[@"ignoreCase"] boolValue]];

	NSInteger operation = [info[@"operation"] intValue];
	if( [ruleOperation indexOfItemWithTag:operation] != -1 )
		[ruleOperation selectItemAtIndex:[ruleOperation indexOfItemWithTag:operation]];

	[self updateRuleEditPanelSize];
	[self reloadRuleEditTableView];
	[[NSApplication sharedApplication] beginSheet:ruleEditPanel modalForWindow:[rulesTable window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction) saveRuleSet:(id) sender {
	NSMutableDictionary *info = nil;

	if( _makingNewRuleSet ) {
		info = [NSMutableDictionary dictionary];
		[[self selectedRules] addObject:info];
	} else info = [self selectedRules][_selectedRuleSet];

	info[@"criterion"] = [self editingCriterion];
	info[@"operation"] = @([ruleOperation selectedTag]);
	info[@"ignoreCase"] = [NSNumber numberWithBool:[ignoreCase state]];

	[ruleEditPanel orderOut:nil];
	[[NSApplication sharedApplication] endSheet:ruleEditPanel];

	[rulesTable reloadData];
	[windowSetsTable reloadData];

	_editingRuleCriterion = nil;

	if( _makingNewRuleSet ) {
		[rulesTable scrollRowToVisible:( [[self selectedRules] count] - 1 )];
		[rulesTable selectRowIndexes:[NSIndexSet indexSetWithIndex:( [[self selectedRules] count] - 1 )] byExtendingSelection:NO];
		_makingNewRuleSet = NO;
	}

	[self saveWindowRules];
}

- (IBAction) cancelRuleSet:(id) sender {
	_makingNewRuleSet = NO;

	_editingRuleCriterion = nil;

	[ruleEditPanel orderOut:nil];
	[[NSApplication sharedApplication] endSheet:ruleEditPanel];
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
