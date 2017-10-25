// Rule Table View Concept by Joar Wingfors.
// Created by Timothy Hatcher for Colloquy.
// Copyright Joar Wingfors and Timothy Hatcher. All rights reserved.

#import "JVChatTranscriptPanel.h"
#import "JVChatTranscript.h"
#import "JVChatMessage.h"
#import "JVTranscriptFindWindowController.h"
#import "JVTranscriptCriterionController.h"
#import "JVViewCell.h"
#import "JVStyleView.h"

static JVTranscriptFindWindowController *sharedInstance = nil;

@interface JVTranscriptFindWindowController (Private)
- (void) endFindWithFoundMessage:(JVChatMessage *) foundMessage;
@end

@implementation JVTranscriptFindWindowController
+ (JVTranscriptFindWindowController *) sharedController {
	return ( sharedInstance ? sharedInstance : ( sharedInstance = [[self alloc] initWithWindowNibName:@"JVFind"] ) );
}

#pragma mark -

- (id) initWithWindowNibName:(NSString *) windowNibName {
	if( ( self = [super initWithWindowNibName:windowNibName] ) ) {
		_rules = nil;
		_results = nil;
		_lastMessageIndex = 0;
		_findPasteboardNeedsUpdated = NO;

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( applicationDidActivate: ) name:NSApplicationDidBecomeActiveNotification object:[NSApplication sharedApplication]];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( applicationWillDeactivate: ) name:NSApplicationWillResignActiveNotification object:[NSApplication sharedApplication]];
	}

	return self;
}

- (void) dealloc {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if( self == sharedInstance ) sharedInstance = nil;

	[subviewTableView setDataSource:nil];
	[subviewTableView setDelegate:nil];

	_rules = nil;
	_results = nil;
}

- (void) windowDidLoad {
	[resultProgress setUsesThreadedAnimation:YES];

	[subviewTableView setDataSource:self];
	[subviewTableView setDelegate:self];
	[subviewTableView setRefusesFirstResponder:YES];

	NSTableColumn *column = [subviewTableView tableColumnWithIdentifier:@"criteria"];
	[column setDataCell:[JVViewCell new]];

	[self addRow:nil];
	[self performSelector:@selector( loadFindStringFromPasteboard )];
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

- (NSMutableArray *) results {
	if( ! _results ) _results = [[NSMutableArray alloc] init];
	return _results;
}

#pragma mark -

- (NSMutableArray *) criterionControllers {
	if( ! _rules ) _rules = [[NSMutableArray alloc] init];
	return _rules;
}

- (void) insertObject:(id) obj inCriterionControllersAtIndex:(NSUInteger) index {
	if( index != NSNotFound ) [[self criterionControllers] insertObject:obj atIndex:( index + 1 )];
	else [[self criterionControllers] addObject:obj];
	[self reloadTableView];
}

- (void) removeObjectFromCriterionControllersAtIndex:(NSUInteger) index {
	[[self criterionControllers] removeObjectAtIndex:index];
	[self reloadTableView];
}

#pragma mark -

- (JVChatTranscriptPanel *) focusedChatTranscriptPanel {
	NSWindow *window = [[NSApplication sharedApplication] mainWindow];
	if( [[window delegate] isKindOfClass:[JVChatWindowController class]] ) {
		if( [[((id <JVChatViewController>)[window delegate]) activeChatViewController] isKindOfClass:[JVChatTranscriptPanel class]] ) {
			return (JVChatTranscriptPanel *)[((id <JVChatViewController>)[window delegate]) activeChatViewController];
		}
	} return nil;
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

	[[previousRule lastKeyView] setNextKeyView:scrollbackOnly];
}

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

	[[self results] removeAllObjects];
	_lastMessageIndex = 0;

	[self updateKeyViewLoop];
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

	[[self results] removeAllObjects];
	_lastMessageIndex = 0;

	[self updateKeyViewLoop];
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
	JVChatTranscriptPanel *panel = [self focusedChatTranscriptPanel];
	JVChatTranscript *transcript = [panel transcript];
	if( ! transcript ) return;

	JVChatMessage *foundMessage = nil;
	NSEnumerator *enumerator = [[self results] objectEnumerator];
	NSArray *allMessages = nil;
	NSRange range;
	NSArray *rangeMsgs = nil;
	NSEnumerator *messages = nil;
	JVChatMessage *message = nil;

	while( ( foundMessage = [enumerator nextObject] ) )
		[[panel display] clearHighlightForMessage:foundMessage];

	foundMessage = nil;

	if( _lastMessageIndex < ( [[self results] count] - 1 ) && ! [self rulesChangedSinceLastFind] && [[[[self results] lastObject] transcript] isEqual:transcript] ) {
		_lastMessageIndex++;
		foundMessage = [self results][_lastMessageIndex];
		goto end;
	}

	[resultCount setObjectValue:@""];
	[resultProgress setHidden:NO];
	[resultProgress setIndeterminate:YES];
	[resultProgress startAnimation:nil];
	[resultProgress displayIfNeeded];

	allMessages = [transcript messages];

	if( ! [self rulesChangedSinceLastFind] && [[[[self results] lastObject] transcript] isEqual:transcript] ) {
		NSUInteger index = [allMessages indexOfObjectIdenticalTo:[[self results] lastObject]];
		if( index != NSNotFound ) {
			range = NSMakeRange( index + 1, [allMessages count] - ( index + 1 ) );
		} else goto end;
	} else {
		range = NSMakeRange( 0, [allMessages count] );
		[[self results] removeAllObjects];
		_lastMessageIndex = 0;
	}

	if( ! range.length ) goto end;
	if( ! range.location || [scrollbackOnly state] == NSOnState )
		[hiddenResults setHidden:YES];

	_findPasteboardNeedsUpdated = YES;

	rangeMsgs = [transcript messagesInRange:range];
	messages = [rangeMsgs objectEnumerator];

	[resultProgress stopAnimation:nil];
	[resultProgress setIndeterminate:NO];
	[resultProgress setDoubleValue:0.];
	[resultProgress displayIfNeeded];

	NSUInteger hiddenMsgs = 0;
	NSUInteger i = 0;
	NSUInteger totalMsgs = [rangeMsgs count];
	BOOL andOperation = ( [operation selectedTag] == 2 );
	BOOL ignore = ( [ignoreCase state] == NSOnState );

	while( ( message = [messages nextObject] ) ) {
		BOOL scrollback = YES; // [transcript messageIsInScrollback:message];
		if( ! scrollback && [scrollbackOnly state] == NSOnState ) continue;

		BOOL match = ( andOperation ? YES : NO );
		NSEnumerator *rules = [[self criterionControllers] objectEnumerator];
		JVTranscriptCriterionController *rule = nil;
		while( ( rule = [rules nextObject] ) ) {
			BOOL localMatch = [rule matchMessage:message fromChatView:[self focusedChatTranscriptPanel] ignoringCase:ignore];
			match = ( andOperation ? ( match & localMatch ) : ( match | localMatch ) );
			if( ! localMatch && andOperation ) break; // fails, this wont match with all rules
			else if( localMatch && ! andOperation ) break; // passes one, this is enough to match under "any rules"
		}

		if( match ) {
			if( scrollback ) {
				foundMessage = message;
				[[self results] addObject:message];
				_lastMessageIndex++;
				break;
			} else if( ! range.location && ! scrollback ) {
				hiddenMsgs++;
				[hiddenResults setHidden:NO];
				[hiddenResultsCount setStringValue:[NSString stringWithFormat:NSLocalizedString( @"%u hidden", "number of hidden messages" ), hiddenMsgs]];
				[hiddenResults displayIfNeeded];
			}
		}

		if( ! ( i++ % 25 ) ) {
			[resultProgress setDoubleValue:( ( (double) i / (double) totalMsgs ) * 100. )];
			[resultProgress displayIfNeeded];
		}
	}

end:

	if( foundMessage ) {
		[[panel display] highlightMessage:foundMessage];
		[panel jumpToMessage:foundMessage];
	} else NSBeep();

	[resultProgress setDoubleValue:[resultProgress maxValue]];
	[resultProgress displayIfNeeded];
	[self performSelector:@selector( hideProgress ) withObject:nil afterDelay:0.125];
}

- (IBAction) findPrevious:(id) sender {
	JVChatTranscriptPanel *panel = [self focusedChatTranscriptPanel];
	JVChatTranscript *transcript = [panel transcript];
	if( ! transcript ) return;

	JVChatMessage *foundMessage = nil;
	NSEnumerator *enumerator = [[self results] objectEnumerator];

	NSArray *rangeMsgs = nil;
	NSEnumerator *messages = nil;
	JVChatMessage *message = nil;

	while( ( foundMessage = [enumerator nextObject] ) )
		[[panel display] clearHighlightForMessage:foundMessage];

	foundMessage = nil;

	if( [[self results] count] && _lastMessageIndex > 0 && ! [self rulesChangedSinceLastFind] && [[[[self results] lastObject] transcript] isEqual:transcript] ) {
		_lastMessageIndex--;
		foundMessage = [self results][_lastMessageIndex];

		[self endFindWithFoundMessage:foundMessage];
		return;
	}

	[resultCount setObjectValue:@""];
	[resultProgress setHidden:NO];
	[resultProgress setIndeterminate:YES];
	[resultProgress startAnimation:nil];
	[resultProgress displayIfNeeded];

	NSArray *allMessages = [transcript messages];
	NSRange range;

	if( ! [self rulesChangedSinceLastFind] && [[[[self results] lastObject] transcript] isEqual:transcript] && [[self results] count] ) {
		NSUInteger index = [allMessages indexOfObjectIdenticalTo:[self results][0]];
		if( index != NSNotFound && index > 1 ) {
			range = NSMakeRange( 0, index );
		} else {
			[self endFindWithFoundMessage:foundMessage];
			return;
		}
	} else {
		range = NSMakeRange( 0, [allMessages count] );
		[[self results] removeAllObjects];
		_lastMessageIndex = 0;
	}

	if( ! range.length ) {
		[self endFindWithFoundMessage:foundMessage];
		return;
	}
	if( [scrollbackOnly state] == NSOnState )
		[hiddenResults setHidden:YES];

	_findPasteboardNeedsUpdated = YES;

	rangeMsgs = [transcript messagesInRange:range];
	messages = [rangeMsgs reverseObjectEnumerator];
	message = nil;

	[resultProgress stopAnimation:nil];
	[resultProgress setIndeterminate:NO];
	[resultProgress setDoubleValue:0.];
	[resultProgress displayIfNeeded];

	NSUInteger hiddenMsgs = 0;
	NSUInteger i = 0;
	NSUInteger totalMsgs = [rangeMsgs count];
	BOOL andOperation = ( [operation selectedTag] == 2 );
	BOOL ignore = ( [ignoreCase state] == NSOnState );

	while( ( message = [messages nextObject] ) ) {
		BOOL scrollback = YES; // [transcript messageIsInScrollback:message];
		if( ! scrollback && [scrollbackOnly state] == NSOnState ) continue;

		BOOL match = ( andOperation ? YES : NO );
		NSEnumerator *rules = [[self criterionControllers] objectEnumerator];
		JVTranscriptCriterionController *rule = nil;
		while( ( rule = [rules nextObject] ) ) {
			BOOL localMatch = [rule matchMessage:message fromChatView:[self focusedChatTranscriptPanel] ignoringCase:ignore];
			match = ( andOperation ? ( match & localMatch ) : ( match | localMatch ) );
			if( ! localMatch && andOperation ) break; // fails, this wont match with all rules
			else if( localMatch && ! andOperation ) break; // passes one, this is enough to match under "any rules"
		}

		if( match ) {
			if( scrollback ) {
				foundMessage = message;
				[[self results] insertObject:message atIndex:0];
				break;
			} else if( ! range.location && ! scrollback ) {
				hiddenMsgs++;
				[hiddenResults setHidden:NO];
				[hiddenResultsCount setStringValue:[NSString stringWithFormat:NSLocalizedString( @"%u hidden", "number of hidden messages" ), hiddenMsgs]];
				[hiddenResults displayIfNeeded];
			}
		}

		if( ! ( i++ % 25 ) ) {
			[resultProgress setDoubleValue:( ( (double) i / (double) totalMsgs ) * 100. )];
			[resultProgress displayIfNeeded];
		}
	}

	[self endFindWithFoundMessage:foundMessage];
}

- (void) endFindWithFoundMessage:(JVChatMessage *) foundMessage {
	JVChatTranscriptPanel *panel = [self focusedChatTranscriptPanel];

	if( foundMessage ) {
		[[panel display] highlightMessage:foundMessage];
		[panel jumpToMessage:foundMessage];
	} else NSBeep();

	[resultProgress setDoubleValue:[resultProgress maxValue]];
	[resultProgress displayIfNeeded];
	[self performSelector:@selector( hideProgress ) withObject:nil afterDelay:0.125];
}

- (IBAction) findAll:(id) sender {
	JVChatTranscript *transcript = [[self focusedChatTranscriptPanel] transcript];
	if( ! transcript ) return;

	_findPasteboardNeedsUpdated = YES;

	NSEnumerator *messages = [[transcript messages] objectEnumerator];
	JVChatMessage *message = nil;

	BOOL andOperation = ( [operation selectedTag] == 2 );
	BOOL ignore = ( [ignoreCase state] == NSOnState );
	while( ( message = [messages nextObject] ) ) {
		BOOL match = ( andOperation ? YES : NO );
		NSEnumerator *rules = [[self criterionControllers] objectEnumerator];
		JVTranscriptCriterionController *rule = nil;
		while( ( rule = [rules nextObject] ) ) {
			BOOL localMatch = [rule matchMessage:message fromChatView:[self focusedChatTranscriptPanel] ignoringCase:ignore];
			match = ( andOperation ? ( match & localMatch ) : ( match | localMatch ) );
			if( ! localMatch && andOperation ) break; // fails, this wont match with all rules
			else if( localMatch && ! andOperation ) break; // passes one, this is enough to match under any rules
		} if( match ) [[self results] addObject:message];
	}
}

#pragma mark -

- (NSInteger) numberOfRowsInTableView:(NSTableView *) tableView {
	return [[self criterionControllers] count];
}

- (void) tableViewSelectionDidChange:(NSNotification *) notification {
	[subviewTableView deselectAll:nil];
}

- (void) tableView:(NSTableView *) tableView willDisplayCell:(id) cell forTableColumn:(NSTableColumn *) tableColumn row:(NSInteger) row {
	if( [[tableColumn identifier] isEqualToString:@"criteria"] ) {
		[(JVViewCell *)cell setView:[(JVTranscriptCriterionController *)[self criterionControllers][row] view]];
	} else if( [[tableColumn identifier] isEqualToString:@"remove"] ) {
		[cell setEnabled:( [self numberOfRowsInTableView:tableView] > 1 )];
	}
}

- (id) tableView:(NSTableView *) tableView objectValueForTableColumn:(NSTableColumn *) tableColumn row:(NSInteger) row {
	return [self criterionControllers][row];
}

#pragma mark -

- (void) loadFindStringFromPasteboard {
	_findPasteboardNeedsUpdated = NO;

	NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:NSFindPboard];
	if( [[pasteboard types] containsObject:NSStringPboardType] ) {
		NSString *string = [pasteboard stringForType:NSStringPboardType];
		if( [string isKindOfClass:[NSString class]] && [string length] ) {
			NSEnumerator *rules = [[self criterionControllers] objectEnumerator];
			JVTranscriptCriterionController *rule = nil;
			while( ( rule = [rules nextObject] ) ) {
				if( [rule format] == JVTranscriptTextCriterionFormat ) {
					[rule setQuery:string];
					break;
				}
			}
		}
	}
}

- (void) loadFindStringToPasteboard {
	_findPasteboardNeedsUpdated = NO;

	NSString *findString = nil;
	NSEnumerator *rules = [[self criterionControllers] objectEnumerator];
	JVTranscriptCriterionController *rule = nil;
	while( ( rule = [rules nextObject] ) ) {
		if( [rule format] == JVTranscriptTextCriterionFormat ) {
			findString = [rule query];
			break;
		}
	}

	if( ! findString || ! [findString isKindOfClass:[NSString class]] ) return;

	NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:NSFindPboard];
	[pasteboard declareTypes:@[NSStringPboardType] owner:nil];
	[pasteboard setString:findString forType:NSStringPboardType];
}

#pragma mark -

- (void) applicationDidActivate:(NSNotification *) notification {
	[self loadFindStringFromPasteboard];
}

- (void) applicationWillDeactivate:(NSNotification *) notification {
	if( _findPasteboardNeedsUpdated ) [self loadFindStringToPasteboard];
}

#pragma mark -

- (void) windowWillClose:(NSNotification *) notification {
	JVChatTranscriptPanel *panel = [self focusedChatTranscriptPanel];
	NSEnumerator *enumerator = [[self results] objectEnumerator];
	JVChatMessage *foundMessage = nil;

	while( ( foundMessage = [enumerator nextObject] ) )
		[[panel display] clearHighlightForMessage:foundMessage];

	[_results removeAllObjects];
}
@end
