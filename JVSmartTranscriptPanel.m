#import "JVTranscriptCriterionController.h"
#import "JVTabbedChatWindowController.h"
#import "JVChatWindowController.h"
#import "JVSmartTranscriptPanel.h"
#import "JVDirectChatPanel.h"
#import "JVChatTranscript.h"
#import "JVChatMessage.h"
#import "JVStyleView.h"
#import "JVViewCell.h"

@implementation JVSmartTranscriptPanel
- (id) initWithSettings:(NSDictionary *) settings {
	_settingsNibLoaded = [NSBundle loadNibNamed:@"JVSmartTranscriptFilterSheet" owner:self];

	if( ( self = [self init] ) ) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _messageDisplayed: ) name:JVChatMessageWasProcessedNotification object:nil];		
	}

	return self;
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

	[super awakeFromNib];
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
//	if( [_windowController isMemberOfClass:[JVTabbedChatWindowController class]] )
//		return ( [_waitingAlerts count] ? [NSImage imageNamed:@"AlertCautionIcon"] : ( _newMessageCount ? ( _newHighlightMessageCount ? [NSImage imageNamed:@"privateChatTabNewMessage"] : [NSImage imageNamed:@"privateChatTabNewMessage"] ) : nil ) );

//	return ( [_waitingAlerts count] ? [NSImage imageNamed:@"viewAlert"] : ( _newMessageCount ? ( _newHighlightMessageCount ? [NSImage imageNamed:@"newHighlightMessage"] : [NSImage imageNamed:@"newMessage"] ) : nil ) );
	return nil;
}

#pragma mark -

- (NSMutableArray *) criterionControllers {
	if( ! _rules ) _rules = [[NSMutableArray alloc] init];
	return _rules;
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

	JVChatMessage *newMessage = [[self transcript] appendMessage:message];
	[display appendChatMessage:newMessage];	
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

- (void) reloadTableView {
	while( [[subviewTableView subviews] count] > 0 )
		[[[subviewTableView subviews] lastObject] removeFromSuperviewWithoutNeedingDisplay];
	[subviewTableView reloadData];
}

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
@end

#pragma mark -

@implementation JVSmartTranscriptPanel (JVSmartTranscriptPanelPrivate)
- (void) _messageDisplayed:(NSNotification *) notification {
	JVChatMessage *origMessage = [[notification userInfo] objectForKey:@"message"];
	[self matchMessage:origMessage fromView:[notification object]];
}
@end