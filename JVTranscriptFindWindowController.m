// Concept by Joar Wingfors.
// Created by Timothy Hatcher for Colloquy.
// Copyright Joar Wingfors and Timothy Hatcher. All rights reserved.

#import "JVChatTranscript.h"
#import "JVChatMessage.h"
#import "JVTranscriptFindWindowController.h"
#import "JVTranscriptCriterionController.h"
#import "MVApplicationController.h"
#import "JVViewCell.h"

static JVTranscriptFindWindowController *sharedInstance = nil;

@implementation JVTranscriptFindWindowController
+ (JVTranscriptFindWindowController *) sharedController {
	extern JVTranscriptFindWindowController *sharedInstance;
	if( ! sharedInstance && [MVApplicationController isTerminating] ) return nil;
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] initWithWindowNibName:nil] ) );
}

#pragma mark -

- (id) initWithWindowNibName:(NSString *) windowNibName {
	if( ( self = [super initWithWindowNibName:@"JVFind"] ) ) {
		_rules = nil;
		_lastFoundMessage = nil;
	}

	return self;
}

- (void) dealloc {
	extern JVTranscriptFindWindowController *sharedInstance;

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if( self == sharedInstance ) sharedInstance = nil;

	[_rules release];
	[_lastFoundMessage release];
	_rules = nil;
	_lastFoundMessage = nil;

	[super dealloc];
}

- (void) windowDidLoad {
	[resultProgress setUsesThreadedAnimation:YES];

	[subviewTableView setDataSource:self];
	[subviewTableView setDelegate:self];
	[subviewTableView setRefusesFirstResponder:YES];

	NSTableColumn *column = [subviewTableView tableColumnWithIdentifier:@"criteria"];
	[column setDataCell:[[JVViewCell new] autorelease]];

	[self addRow:nil];
}

#pragma mark -

- (void) reloadTableView {
	while( [[subviewTableView subviews] count] > 0 )
		[[[subviewTableView subviews] lastObject] removeFromSuperviewWithoutNeedingDisplay];
	[subviewTableView reloadData];
}

- (void) hideProgress {
	[resultProgress setHidden:YES];
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

- (JVChatTranscript *) focusedChatTranscript {
	NSWindow *window = [[NSApplication sharedApplication] mainWindow];
	if( [[window delegate] isKindOfClass:[JVChatWindowController class]] ) {
		if( [[[window delegate] activeChatViewController] isKindOfClass:[JVChatTranscript class]] ) {
			return (JVChatTranscript *)[[window delegate] activeChatViewController];
		}
	} return nil;
}

#pragma mark -

- (IBAction) addRow:(id) sender {
	JVTranscriptCriterionController *criterion = [JVTranscriptCriterionController controller];
	[self insertObject:criterion inCriterionControllersAtIndex:[[subviewTableView selectedRowIndexes] lastIndex]];

	if( sender ) {
		NSRect frame = [[self window] frame];
		frame.origin.y -= 30;
		frame.size.height += 30;
		[[self window] setFrame:frame display:YES animate:YES];

		frame.size.width = 520;
		[[self window] setMinSize:frame.size];

		frame.size.width = 800;
		[[self window] setMaxSize:frame.size];
	}

	[_lastFoundMessage release];
	_lastFoundMessage = nil;
}

- (IBAction) removeRow:(id) sender {
	[self removeObjectFromCriterionControllersAtIndex:[[subviewTableView selectedRowIndexes] lastIndex]];

	if( sender ) {
		NSRect frame = [[self window] frame];
		frame.origin.y += 30;
		frame.size.height -= 30;
		[[self window] setFrame:frame display:YES animate:YES];

		frame.size.width = 520;
		[[self window] setMinSize:frame.size];

		frame.size.width = 800;
		[[self window] setMaxSize:frame.size];
	}

	[_lastFoundMessage release];
	_lastFoundMessage = nil;
}

#pragma mark -

- (BOOL) rulesChangedSinceLastFind {
	NSEnumerator *rules = [[self criterionControllers] objectEnumerator];
	JVTranscriptCriterionController *rule = nil;
	while( ( rule = [rules nextObject] ) )
		if( [rule changedSinceLastMatch] ) return YES;
	return NO;
}

- (IBAction) findNext:(id) sender {
	JVChatTranscript *transcript = [self focusedChatTranscript];
	if( ! transcript ) return;

	[resultCount setObjectValue:@""];
	[resultProgress setHidden:NO];
	[resultProgress setIndeterminate:YES];
	[resultProgress startAnimation:nil];
	[resultProgress displayIfNeeded];
	if( [scrollbackOnly state] == NSOnState )
		[hiddenResults setHidden:YES];

	NSArray *allMessages = [transcript messages];
	NSRange range;

	if( ! [self rulesChangedSinceLastFind] && _lastFoundMessage && [[_lastFoundMessage transcript] isEqual:transcript] ) {
		unsigned int index = [allMessages indexOfObjectIdenticalTo:_lastFoundMessage];
		if( index != NSNotFound ) {
			range = NSMakeRange( index + 1, [allMessages count] - ( index + 1 ) );
		} else {
			[resultProgress stopAnimation:nil];
			return;
		}
	} else {
		range = NSMakeRange( 0, [allMessages count] );
		[_lastFoundMessage release];
		_lastFoundMessage = nil;
	}

	if( ! range.length ) {
		[resultProgress setHidden:YES];
		return;
	}

	NSArray *rangeMsgs = [transcript messagesInRange:range];
	NSEnumerator *messages = [rangeMsgs objectEnumerator];
	JVChatMessage *message = nil;

	[resultProgress stopAnimation:nil];
	[resultProgress setIndeterminate:NO];
	[resultProgress setDoubleValue:0.];
	[resultProgress displayIfNeeded];

	unsigned int hiddenMsgs = 0;
	unsigned int i = 0;
	unsigned int totalMsgs = [rangeMsgs count];
	BOOL andOperation = ( [operation selectedTag] == 2 );
	BOOL ignore = ( [ignoreCase state] == NSOnState );
	while( ( message = [messages nextObject] ) ) {
		BOOL scrollback = [transcript messageIsInScrollback:message];
		if( ! scrollback && [scrollbackOnly state] == NSOnState ) continue;

		BOOL match = ( andOperation ? YES : NO );
		NSEnumerator *rules = [[self criterionControllers] objectEnumerator];
		JVTranscriptCriterionController *rule = nil;
		while( ( rule = [rules nextObject] ) ) {
			BOOL localMatch = [rule matchMessage:message ignoreCase:ignore];
			match = ( andOperation ? ( match & localMatch ) : ( match | localMatch ) );
			if( ! localMatch && andOperation ) break; // fails, this wont match with all rules
			else if( localMatch && ! andOperation ) break; // passes one, this is enough to match under "any rules"
		}

		if( ! ( i++ % 25 ) ) {
			[resultProgress setDoubleValue:( ( (double) i / (double) totalMsgs ) * 100. )];
			[resultProgress displayIfNeeded];
		}

		if( match ) {
			if( scrollback ) {
				[_lastFoundMessage release];
				_lastFoundMessage = [message retain];
				[transcript jumpToMessage:_lastFoundMessage];
				break;
			} else if( ! range.location && ! scrollback ) {
				hiddenMsgs++;
			}
		}
	}

	NSLog( @"%@ %@", NSStringFromRange( range ), _lastFoundMessage );
	
	[resultProgress setDoubleValue:[resultProgress maxValue]];
	[resultProgress displayIfNeeded];
	[self performSelector:@selector( hideProgress ) withObject:nil afterDelay:0.75];

	if( ! range.location && hiddenMsgs ) {
		[hiddenResults setHidden:NO];
		[hiddenResultsCount setStringValue:[NSString stringWithFormat:NSLocalizedString( @"%u hidden", "number of hidden messages" ), hiddenMsgs]];
	} else if( ! range.location && ! hiddenMsgs ) {
		[hiddenResults setHidden:YES];
	}
}

- (IBAction) findPrevious:(id) sender {
	JVChatTranscript *transcript = [self focusedChatTranscript];
	if( ! transcript ) return;

	[resultCount setObjectValue:@""];
	[resultProgress setHidden:NO];
	[resultProgress setIndeterminate:YES];
	[resultProgress startAnimation:nil];
	[resultProgress displayIfNeeded];
	if( [scrollbackOnly state] == NSOnState )
		[hiddenResults setHidden:YES];

	NSArray *allMessages = [transcript messages];
	NSRange range;

	if( ! [self rulesChangedSinceLastFind] && _lastFoundMessage && [[_lastFoundMessage transcript] isEqual:transcript] ) {
		unsigned int index = [allMessages indexOfObjectIdenticalTo:_lastFoundMessage];
		if( index != NSNotFound && index > 1 ) {
			range = NSMakeRange( 0, index );
		} else {
			[resultProgress stopAnimation:nil];
			return;
		}
	} else {
		range = NSMakeRange( 0, [allMessages count] );
		[_lastFoundMessage release];
		_lastFoundMessage = nil;
	}	

	if( ! range.length ) {
		[resultProgress setHidden:YES];
		return;
	}

	NSArray *rangeMsgs = [transcript messagesInRange:range];
	NSEnumerator *messages = [rangeMsgs reverseObjectEnumerator];
	JVChatMessage *message = nil;

	[resultProgress stopAnimation:nil];
	[resultProgress setIndeterminate:NO];
	[resultProgress setDoubleValue:0.];
	[resultProgress displayIfNeeded];

	unsigned int hiddenMsgs = 0;
	unsigned int i = 0;
	unsigned int totalMsgs = [rangeMsgs count];
	BOOL andOperation = ( [operation selectedTag] == 2 );
	BOOL ignore = ( [ignoreCase state] == NSOnState );
	while( ( message = [messages nextObject] ) ) {
		BOOL scrollback = [transcript messageIsInScrollback:message];
		if( ! scrollback && [scrollbackOnly state] == NSOnState ) continue;

		BOOL match = ( andOperation ? YES : NO );
		NSEnumerator *rules = [[self criterionControllers] objectEnumerator];
		JVTranscriptCriterionController *rule = nil;
		while( ( rule = [rules nextObject] ) ) {
			BOOL localMatch = [rule matchMessage:message ignoreCase:ignore];
			match = ( andOperation ? ( match & localMatch ) : ( match | localMatch ) );
			if( ! localMatch && andOperation ) break; // fails, this wont match with all rules
			else if( localMatch && ! andOperation ) break; // passes one, this is enough to match under "any rules"
		}

		if( ! ( i++ % 25 ) ) {
			[resultProgress setDoubleValue:( ( (double) i / (double) totalMsgs ) * 100. )];
			[resultProgress displayIfNeeded];
		}

		if( match ) {
			if( scrollback ) {
				[_lastFoundMessage release];
				_lastFoundMessage = [message retain];
				[transcript jumpToMessage:_lastFoundMessage];
				break;
			} else if( ! range.location && ! scrollback ) {
				hiddenMsgs++;
			}
		}
	}
	
	NSLog( @"%@ %@", NSStringFromRange( range ), _lastFoundMessage );

	[resultProgress setDoubleValue:[resultProgress maxValue]];
	[resultProgress displayIfNeeded];
	[self performSelector:@selector( hideProgress ) withObject:nil afterDelay:0.75];

	if( ! range.location && hiddenMsgs ) {
		[hiddenResults setHidden:NO];
		[hiddenResultsCount setStringValue:[NSString stringWithFormat:NSLocalizedString( @"%u hidden", "number of hidden messages" ), hiddenMsgs]];
	} else if( ! range.location && ! hiddenMsgs ) {
		[hiddenResults setHidden:YES];
	}
}

- (IBAction) findAll:(id) sender {
	JVChatTranscript *transcript = [self focusedChatTranscript];
	if( ! transcript ) return;

	NSEnumerator *messages = [[transcript messages] objectEnumerator];
	JVChatMessage *message = nil;

	NSMutableArray *results = [NSMutableArray arrayWithCapacity:( [[transcript messages] count] / 4 )];
	BOOL andOperation = ( [operation selectedTag] == 2 );
	BOOL ignore = ( [ignoreCase state] == NSOnState );
	while( ( message = [messages nextObject] ) ) {
		BOOL match = ( andOperation ? YES : NO );
		NSEnumerator *rules = [[self criterionControllers] objectEnumerator];
		JVTranscriptCriterionController *rule = nil;
		while( ( rule = [rules nextObject] ) ) {
			BOOL localMatch = [rule matchMessage:message ignoreCase:ignore];
			match = ( andOperation ? ( match & localMatch ) : ( match | localMatch ) );
			if( ! localMatch && andOperation ) break; // fails, this wont match with all rules
			else if( localMatch && ! andOperation ) break; // passes one, this is enough to match under any rules
		} if( match ) [results addObject:message];
	}
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
@end