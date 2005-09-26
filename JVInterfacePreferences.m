#import "JVInterfacePreferences.h"
#import "JVChatViewCriterionController.h"
#import "JVChatController.h"
#import "JVChatRoomPanel.h"
#import "JVDetailCell.h"
#import "JVViewCell.h"

static NSString *JVInterfacePreferencesWindowDragPboardType = @"JVInterfacePreferencesWindowDragPboardType";

@implementation JVInterfacePreferences
- (NSString *) preferencesNibName {
	return @"JVInterfacePreferences";
}

- (BOOL) hasChangesPending {
	return NO;
}

- (NSImage *) imageForPreferenceNamed:(NSString *) name {
	return [[[NSImage imageNamed:@"InterfacePreferences"] retain] autorelease];
}

- (BOOL) isResizable {
	return NO;
}

- (void) awakeFromNib {
	NSTableColumn *column = [windowSetsTable tableColumnWithIdentifier:@"window"];
	JVDetailCell *prototypeCell = [[JVDetailCell new] autorelease];
	[prototypeCell setFont:[NSFont toolTipsFontOfSize:11.]];
	[column setDataCell:prototypeCell];

	column = [rulesTable tableColumnWithIdentifier:@"rule"];
	prototypeCell = [[JVDetailCell new] autorelease];
	[prototypeCell setFont:[NSFont toolTipsFontOfSize:11.]];
	[column setDataCell:prototypeCell];

	[rulesTable setIntercellSpacing:NSMakeSize( 6., 2. )];

	[windowSetsTable setTarget:self];
	[windowSetsTable setDoubleAction:@selector( editWindowSet: )];
	[windowSetsTable registerForDraggedTypes:[NSArray arrayWithObject:JVInterfacePreferencesWindowDragPboardType]];

	[rulesTable setTarget:self];
	[rulesTable setDoubleAction:@selector( editRuleSet: )];

	_origRuleEditHeight = NSHeight( [[ruleEditPanel contentView] frame] ) - 30;
	[ruleEditTable setDataSource:self];
	[ruleEditTable setDelegate:self];
	[ruleEditTable setRefusesFirstResponder:YES];

	column = [ruleEditTable tableColumnWithIdentifier:@"criteria"];
	[column setDataCell:[[JVViewCell new] autorelease]];
}

- (void) initializeFromDefaults {
	NSData *data = [[NSUserDefaults standardUserDefaults] dataForKey:@"JVChatWindowRuleSets"];

	[_windowSets autorelease];
	_windowSets = ( [data length] ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : [NSMutableArray array] );
	[_windowSets retain];

	NSEnumerator *enumerator = [_windowSets objectEnumerator];
	NSMutableDictionary *info = nil;
	BOOL haveCurrentWindow = NO;
	BOOL haveNewWindow = NO;

	while( ( info = [enumerator nextObject] ) ) {
		NSString *value = [info objectForKey:@"special"];
		if( [[info objectForKey:@"currentWindow"] boolValue] ) { // old method
			[info setObject:@"currentWindow" forKey:@"special"]; // add new method of identifying
			[info removeObjectForKey:@"currentWindow"]; // remove the old method of identifying
			haveCurrentWindow = YES;
		} else if( [value isEqualToString:@"currentWindow"] ) haveCurrentWindow = YES;
		else if( [value isEqualToString:@"newWindow"] ) haveNewWindow = YES;
	}

	if( ! haveCurrentWindow ) {
		info = [NSMutableDictionary dictionary];
		[_windowSets addObject:info];

		[info setObject:@"currentWindow" forKey:@"special"];
		[info setObject:[NSString locallyUniqueString] forKey:@"identifier"];
		[info setObject:[NSMutableArray array] forKey:@"rules"];
	}

	if( ! haveNewWindow ) {
		info = [NSMutableDictionary dictionary];
		[_windowSets addObject:info];

		[info setObject:@"newWindow" forKey:@"special"];
		[info setObject:[NSString locallyUniqueString] forKey:@"identifier"];
		[info setObject:[NSMutableArray array] forKey:@"rules"];
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
	NSEnumerator *enumerator = [rules objectEnumerator];
	id rule = nil;
	BOOL first = YES;

	while( ( rule = [enumerator nextObject] ) ) {
		if( ! first && operation ) [title appendString:@" and "];
		else if( ! first && ! operation ) [title appendString:@" or "];
		[title appendString:[rule description]];
		first = NO;
	}

	return title;
}

- (NSImage *) iconForRules:(NSArray *) rules {
	NSImage *icon = [NSImage imageNamed:@"gearSmall"];
	NSEnumerator *enumerator = [rules objectEnumerator];
	JVChatViewCriterionController *rule = nil;
	BOOL multipleType = NO;

	while( ( rule = [enumerator nextObject] ) ) {
		if( ! multipleType && [rule kind] == JVChatViewTypeCriterionKind && [rule operation] == JVChatViewIsEqualCriterionOperation ) {
			if( [[rule query] intValue] == 1 ) icon = [NSImage imageNamed:@"roomTab"];
			else if( [[rule query] intValue] == 2 ) icon = [NSImage imageNamed:@"privateChatTabNewMessage"];
			else if( [[rule query] intValue] == 12 ) icon = [NSImage imageNamed:@"smartTranscriptTab"];
			multipleType = YES;
		} else if( multipleType && [rule kind] == JVChatViewTypeCriterionKind ) {
			icon = [NSImage imageNamed:@"gearSmall"];
			break;
		}
	}

	return icon;
}

#pragma mark -

- (int) numberOfRowsInTableView:(NSTableView *) view {
	if( view == windowSetsTable ) return [_windowSets count];
	else if( view == rulesTable ) {
		if( [_windowSets count] < _selectedWindowSet ) return 0;
		NSDictionary *info = [_windowSets objectAtIndex:_selectedWindowSet];
		return [[info objectForKey:@"rules"] count];
	} else if( view == ruleEditTable ) {
		return [[self editingCriterion] count];
	}

	return 0;
}

- (id) tableView:(NSTableView *) view objectValueForTableColumn:(NSTableColumn *) column row:(int) row {
	if( view == windowSetsTable ) {
		NSDictionary *info = [_windowSets objectAtIndex:row];
		if( [[info objectForKey:@"special"] isEqualToString:@"currentWindow"] ) return [NSImage imageNamed:@"targetWindow"];
		else if( [[info objectForKey:@"special"] isEqualToString:@"newWindow"] ) return [NSImage imageNamed:@"newWindow"];
		else return [NSImage imageNamed:@"window"];
	} else if( view == rulesTable ) {
		NSArray *ruleSets = [self selectedRules];
		NSDictionary *info = [ruleSets objectAtIndex:row];
		return [self iconForRules:[info objectForKey:@"criterion"]];
	} else return nil;
}

- (void) tableView:(NSTableView *) view willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) column row:(int) row {
	if( view == windowSetsTable ) {
		NSDictionary *info = [_windowSets objectAtIndex:row];
		if( [[info objectForKey:@"special"] isEqualToString:@"currentWindow"] )
			[(JVDetailCell *) cell setMainText:NSLocalizedString( @"Focused Window", "focused window label, interface preferences" )];
		else if( [[info objectForKey:@"special"] isEqualToString:@"newWindow"] )
			[(JVDetailCell *) cell setMainText:NSLocalizedString( @"New Window", "new window label, interface preferences" )];
		else [(JVDetailCell *) cell setMainText:[info objectForKey:@"title"]];

		unsigned int c = [[info objectForKey:@"rules"] count];
		if( c == 0 ) [(JVDetailCell *) cell setInformationText:NSLocalizedString( @"No rules", "no rules info label" )];
		else if( c == 1 ) [(JVDetailCell *) cell setInformationText:NSLocalizedString( @"1 rule", "one rule info label" )];
		else [(JVDetailCell *) cell setInformationText:[NSString stringWithFormat:NSLocalizedString( @"%d rules", "number of rules info label" ), c]];
	} else if( view == rulesTable ) {
		NSArray *ruleSets = [self selectedRules];
		NSDictionary *info = [ruleSets objectAtIndex:row];
		[(JVDetailCell *) cell setMainText:[self titleForRules:[info objectForKey:@"criterion"] booleanAndOperation:( [[info objectForKey:@"operation"] intValue] == 2 )]];
	} else if( view == ruleEditTable ) {
		if( [[column identifier] isEqualToString:@"criteria"] ) {
			[(JVViewCell *)cell setView:[(JVChatViewCriterionController *)[[self editingCriterion] objectAtIndex:row] view]];
		} else if( [[column identifier] isEqualToString:@"remove"] ) {
			[cell setEnabled:( [self numberOfRowsInTableView:view] > 1 )];
		}
	}
}

- (NSString *) tableView:(NSTableView *) view toolTipForTableColumn:(NSTableColumn *) column row:(int) row {
	if( view == rulesTable ) {
		NSArray *ruleSets = [self selectedRules];
		NSDictionary *info = [ruleSets objectAtIndex:row];
		return [self titleForRules:[info objectForKey:@"criterion"] booleanAndOperation:( [[info objectForKey:@"operation"] intValue] == 2 )];
	}

	return nil;
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	id view = [notification object];
	if( view == windowSetsTable ) {
		_selectedWindowSet = [[windowSetsTable selectedRowIndexes] firstIndex];
		NSDictionary *info = [_windowSets objectAtIndex:_selectedWindowSet];
		[editWindowButton setEnabled:( ! [info objectForKey:@"special"] )];
		[deleteWindowButton setEnabled:( ! [info objectForKey:@"special"] )];
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
		int row = [[rows lastObject] intValue];
		if( row == -1 ) return NO;

		NSData *data = [NSData dataWithBytes:&row length:sizeof( &row )];

		[board declareTypes:[NSArray arrayWithObject:JVInterfacePreferencesWindowDragPboardType] owner:self];
		[board setData:data forType:JVInterfacePreferencesWindowDragPboardType];
		return YES;
	}

	return NO;
}

- (NSDragOperation) tableView:(NSTableView *) view validateDrop:(id <NSDraggingInfo>) info proposedRow:(int) row proposedDropOperation:(NSTableViewDropOperation) operation {
	if( view == windowSetsTable && [[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:JVInterfacePreferencesWindowDragPboardType]] ) {
		if( operation == NSTableViewDropOn && row != -1 ) return NSDragOperationNone;

		int index = -1;
		[[[info draggingPasteboard] dataForType:JVInterfacePreferencesWindowDragPboardType] getBytes:&index];

		if( row >= 0 && row != index && ( row - 1 ) != index ) return NSDragOperationEvery;
		else if( row == -1 ) return NSDragOperationNone;

		return NSDragOperationEvery;
	}

	return NSDragOperationNone;
}

- (BOOL) tableView:(NSTableView *) view acceptDrop:(id <NSDraggingInfo>) info row:(int) row dropOperation:(NSTableViewDropOperation) operation {
	if( view == windowSetsTable && [[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:JVInterfacePreferencesWindowDragPboardType]] ) {
		int index = -1;
		[[[info draggingPasteboard] dataForType:JVInterfacePreferencesWindowDragPboardType] getBytes:&index];
		if( row > index ) row--;

		id item = [[[_windowSets objectAtIndex:index] retain] autorelease];
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
		NSDictionary *info = [_windowSets objectAtIndex:_selectedWindowSet];
		if( [info objectForKey:@"special"] ) {
			NSBeep();
			return;
		}

		[_windowSets removeObjectAtIndex:_selectedWindowSet];
		[windowSetsTable reloadData];

		_selectedWindowSet = [[windowSetsTable selectedRowIndexes] firstIndex];
		[rulesTable reloadData];

		info = [_windowSets objectAtIndex:_selectedWindowSet];
		[editWindowButton setEnabled:( ! [info objectForKey:@"special"] )];
		[deleteWindowButton setEnabled:( ! [info objectForKey:@"special"] )];

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
	NSDictionary *info = [_windowSets objectAtIndex:[[windowSetsTable selectedRowIndexes] firstIndex]];
	if( [info objectForKey:@"special"] ) return;

	[windowTitle setStringValue:[info objectForKey:@"title"]];
	[rememberPanels setState:[[info objectForKey:@"rememberPanels"] boolValue]];
	[windowEditSaveButton setEnabled:YES];

	_makingNewWindowSet = NO;

	[[NSApplication sharedApplication] beginSheet:windowEditPanel modalForWindow:[windowSetsTable window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction) saveWindowSet:(id) sender {
	NSMutableDictionary *info = nil;

	if( _makingNewWindowSet ) {
		info = [NSMutableDictionary dictionary];
		[_windowSets addObject:info];

		[info setObject:[NSString locallyUniqueString] forKey:@"identifier"];
		[info setObject:[NSMutableArray array] forKey:@"rules"];
	} else info = [_windowSets objectAtIndex:_selectedWindowSet];

	[info setObject:[windowTitle stringValue] forKey:@"title"];
	[info setObject:[NSNumber numberWithBool:[rememberPanels state]] forKey:@"rememberPanels"];

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
	NSDictionary *info = [_windowSets objectAtIndex:_selectedWindowSet];
	return [info objectForKey:@"rules"];
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

- (void) insertObject:(id) obj inRuleCriterionAtIndex:(unsigned int) index {
	if( index != NSNotFound ) [[self editingCriterion] insertObject:obj atIndex:( index + 1 )];
	else [[self editingCriterion] addObject:obj];
	[self reloadRuleEditTableView];
}

- (void) removeObjectFromRuleCriterionAtIndex:(unsigned int) index {
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

	[_editingRuleCriterion autorelease];
	_editingRuleCriterion = [[NSMutableArray array] retain];

	[self addRuleCriterionRow:nil];
	[self updateRuleEditPanelSize];
	[[NSApplication sharedApplication] beginSheet:ruleEditPanel modalForWindow:[rulesTable window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction) editRuleSet:(id) sender {
	if( _selectedRuleSet == NSNotFound ) return;

	_makingNewRuleSet = NO;

	NSMutableDictionary *info = [[self selectedRules] objectAtIndex:_selectedRuleSet];

	[_editingRuleCriterion autorelease];
	_editingRuleCriterion = [[info objectForKey:@"criterion"] retain];

	[ignoreCase setState:[[info objectForKey:@"ignoreCase"] boolValue]];

	int operation = [[info objectForKey:@"operation"] intValue];
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
	} else info = [[self selectedRules] objectAtIndex:_selectedRuleSet];

	[info setObject:[self editingCriterion] forKey:@"criterion"];
	[info setObject:[NSNumber numberWithInt:[ruleOperation selectedTag]] forKey:@"operation"];
	[info setObject:[NSNumber numberWithBool:[ignoreCase state]] forKey:@"ignoreCase"];

	[ruleEditPanel orderOut:nil];
	[[NSApplication sharedApplication] endSheet:ruleEditPanel];	

	[rulesTable reloadData];
	[windowSetsTable reloadData];

	[_editingRuleCriterion autorelease];
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

	[_editingRuleCriterion autorelease];
	_editingRuleCriterion = nil;

	[ruleEditPanel orderOut:nil];
	[[NSApplication sharedApplication] endSheet:ruleEditPanel];	
}

#pragma mark -

- (IBAction) changeSortByStatus:(id) sender {
	NSEnumerator *enumerator = [[[JVChatController defaultController] chatViewControllersOfClass:[JVChatRoomPanel class]] objectEnumerator];
	JVChatRoomPanel *room = nil;
	while( ( room = [enumerator nextObject] ) )
		[room resortMembers];
}

- (IBAction) changeShowFullRoomName:(id) sender {
	NSEnumerator *enumerator = [[[JVChatController defaultController] chatViewControllersOfClass:[JVChatRoomPanel class]] objectEnumerator];
	JVChatRoomPanel *room = nil;
	while( ( room = [enumerator nextObject] ) )
		[[room windowController] reloadListItem:room andChildren:NO];
}
@end