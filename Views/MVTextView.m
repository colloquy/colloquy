#import "MVTextView.h"
#import "JVTranscriptFindWindowController.h"

@interface MVTextView ()
- (BOOL) checkKeyEvent:(NSEvent *) event;
- (BOOL) triggerKeyEvent:(NSEvent *) event;
@end

#pragma mark -

@implementation MVTextView
- (instancetype)initWithFrame:(NSRect)frameRect textContainer:(NSTextContainer *)aTextContainer {
	if( (self = [super initWithFrame:frameRect textContainer:aTextContainer] ) )
		defaultTypingAttributes = [[NSDictionary alloc] init];
	return self;
}

#pragma mark -

- (id <MVTextViewDelegate>)delegate {
	return (id <MVTextViewDelegate>)[super delegate];
}

- (void)setDelegate:(id <MVTextViewDelegate>)anObject {
	[super setDelegate:anObject];
}

#pragma mark -

- (void) interpretKeyEvents:(NSArray *) eventArray {
	NSMutableArray *newArray = [[NSMutableArray alloc] init];

	if( ! [self isEditable] ) {
		[super interpretKeyEvents:eventArray];
		return;
	}

	for( NSEvent *anEvent in eventArray ) {
		if( [self checkKeyEvent:anEvent] ) {
			if( [newArray count] > 0 ) {
				[super interpretKeyEvents:newArray];
				[newArray removeAllObjects];
			}
			if( ! [self triggerKeyEvent:anEvent] )
				[newArray addObject:anEvent];
		} else {
			[newArray addObject:anEvent];
		}
	}

	if( [newArray count] > 0 )
		[super interpretKeyEvents:newArray];
}

- (BOOL) checkKeyEvent:(NSEvent *) event {
	unichar chr = 0;
	if( [[event charactersIgnoringModifiers] length] )
		chr = [[event charactersIgnoringModifiers] characterAtIndex:0];

	if( chr == NSCarriageReturnCharacter && [[self delegate] respondsToSelector:@selector( textView:returnKeyPressed: )] ) {
		return YES;
	} else if( chr == NSEnterCharacter && [[self delegate] respondsToSelector:@selector( textView:enterKeyPressed: )] ) {
		return YES;
	} else if( chr == NSTabCharacter ) {
		return YES;
	} else if( chr == 0x1B && [[self delegate] respondsToSelector:@selector( textView:escapeKeyPressed: )] ) {
		_tabCompletting = NO;
		return YES;
	} else if( chr >= 0xF700 && chr <= 0xF8FF && [[self delegate] respondsToSelector:@selector( textView:functionKeyPressed: )] ) {
		return YES;
	} else if( chr == NSDeleteCharacter || chr == NSBackspaceCharacter ) {
		_tabCompletting = NO;
	} else if( _tabCompletting && chr != NSDeleteCharacter && chr != NSBackspaceCharacter ) {
		return YES;
	}

	return NO;
}

- (BOOL) triggerKeyEvent:(NSEvent *) event {
	unichar chr = 0;
	if( [[event charactersIgnoringModifiers] length] )
		chr = [[event charactersIgnoringModifiers] characterAtIndex:0];

	if( _tabCompletting && chr == ' ' ) {
		NSRange curPos = [self selectedRange];
		[self setSelectedRange:NSMakeRange( curPos.location + curPos.length, 0 )];
		return YES;
	} else if( chr == NSCarriageReturnCharacter && [[self delegate] respondsToSelector:@selector( textView:returnKeyPressed: )] ) {
		return [[self delegate] textView:self returnKeyPressed:event];
	} else if( chr == NSEnterCharacter && [[self delegate] respondsToSelector:@selector( textView:enterKeyPressed: )] ) {
		return [[self delegate] textView:self enterKeyPressed:event];
	} else if( chr == NSTabCharacter ) {
		if( ! _tabCompletting ) {
			NSRange curPos = [self selectedRange];
			_complettingWithSuffix = ( curPos.location == [[self string] length] && ( ! ( [event modifierFlags] & NSAlternateKeyMask ) ) );
		}

		_tabCompletting = YES;
		return [self autocompleteWithSuffix:_complettingWithSuffix];
	} else if( chr == 0x1B && [[self delegate] respondsToSelector:@selector( textView:escapeKeyPressed: )] ) {
		return [[self delegate] textView:self escapeKeyPressed:event];
	} else if( chr >= 0xF700 && chr <= 0xF8FF && [[self delegate] respondsToSelector:@selector( textView:functionKeyPressed: )] ) {
		return [[self delegate] textView:self functionKeyPressed:event];
	}/* else if( _tabCompletting && chr != NSDeleteCharacter && chr != NSBackspaceCharacter ) {
		_ignoreSelectionChanges = YES;
		[self replaceCharactersInRange:[self selectedRange] withString:[event charactersIgnoringModifiers]];
		_ignoreSelectionChanges = NO;
		return [self autocompleteWithSuffix:_complettingWithSuffix];
	} */

	return NO;
}

#pragma mark -

- (void) setBaseFont:(NSFont *) font {
	if( ! font ) {
		font = [NSFont userFontOfSize:0.];
		defaultTypingAttributes = [[NSDictionary alloc] init];
	} else defaultTypingAttributes = @{NSFontAttributeName: font};
	[self setTypingAttributes:defaultTypingAttributes];
	[self setFont:font];
}

- (void) reset:(id) sender {
	if( ! [self isEditable] ) return;
	[self setString:@""];
	[self setTypingAttributes:defaultTypingAttributes];
	[self resetCursorRects];
	[[self undoManager] removeAllActionsWithTarget:[self textStorage]];
	_tabCompletting = NO;
}

- (void) setSelectedRange:(NSRange) charRange affinity:(NSSelectionAffinity) affinity stillSelecting:(BOOL) stillSelectingFlag {
	if( ! _ignoreSelectionChanges && _tabCompletting && ! stillSelectingFlag && charRange.length == 0 ) {
		_tabCompletting = NO;

		if( _lastCompletionMatch && _lastCompletionPrefix && [[self delegate] respondsToSelector:@selector( textView:selectedCompletion:fromPrefix: )] )
			[[self delegate] textView:self selectedCompletion:_lastCompletionMatch fromPrefix:_lastCompletionPrefix];

		_lastCompletionMatch = nil;

		_lastCompletionPrefix = nil;
	}

	[super setSelectedRange:charRange affinity:affinity stillSelecting:stillSelectingFlag];
}

- (void) resetCursorRects {
	NSRange limitRange, effectiveRange;
	NSUInteger count = 0, i = 0;
	NSRectArray rects = NULL;
	NSCursor *linkCursor = [[NSCursor alloc] initWithImage:[NSImage imageNamed:@"MVLinkCursor"] hotSpot:NSMakePoint( 6., 0. )];

	[super resetCursorRects];
	limitRange = NSMakeRange( 0, [[self string] length] );
	while( limitRange.length > 0 ) {
		NSDictionary *dict = [[self textStorage] attributesAtIndex:limitRange.location longestEffectiveRange:&effectiveRange inRange:limitRange];
		NSString *link = dict[NSLinkAttributeName];
		if( link ) {
			rects = [[self layoutManager] rectArrayForCharacterRange:effectiveRange withinSelectedCharacterRange:effectiveRange inTextContainer:[self textContainer] rectCount:&count];
			for( i = 0; i < count; i++ ) [self addCursorRect:NSIntersectionRect( [self visibleRect], rects[i] ) cursor:linkCursor];
		}
		limitRange = NSMakeRange( NSMaxRange( effectiveRange ), NSMaxRange( limitRange ) - NSMaxRange( effectiveRange ) );
	}
}

#pragma mark -

- (NSSize) minimumSizeForContent {
	NSLayoutManager *layoutManager = [self layoutManager];
	NSTextContainer *textContainer = [self textContainer];
	[layoutManager glyphRangeForTextContainer:textContainer]; // dummy call to force layout
	return [layoutManager usedRectForTextContainer:textContainer].size;
}

#pragma mark -

- (void) bold:(id) sender {
	if( ! [self isEditable] ) return;
	if( [self selectedRange].length ) {
		NSRange limitRange, effectiveRange;
		NSTextStorage *text = [self textStorage];
		NSFont *font = nil;
		BOOL hasBold = NO;

		limitRange = [self selectedRange];
		font = [text attribute:NSFontAttributeName atIndex:limitRange.location longestEffectiveRange:NULL inRange:limitRange];
		if( [[NSFontManager sharedFontManager] traitsOfFont:font] & NSBoldFontMask ) hasBold = YES;
		else hasBold = NO;
		while( limitRange.length > 0 ) {
			font = [text attribute:NSFontAttributeName atIndex:limitRange.location longestEffectiveRange:&effectiveRange inRange:limitRange];
			if( ! font ) font = [NSFont userFontOfSize:0.];
			if( hasBold ) font = [[NSFontManager sharedFontManager] convertFont:font toNotHaveTrait:NSBoldFontMask];
			else font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSBoldFontMask];
			[text addAttribute:NSFontAttributeName value:font range:effectiveRange];
			limitRange = NSMakeRange( NSMaxRange( effectiveRange ), NSMaxRange( limitRange ) - NSMaxRange( effectiveRange ) );
		}
	} else {
		NSMutableDictionary *attributes = [[self typingAttributes] mutableCopy];
		NSFont *font = attributes[NSFontAttributeName];
		if( ! font ) font = [NSFont userFontOfSize:0.];
		if( [[NSFontManager sharedFontManager] traitsOfFont:font] & NSBoldFontMask )
			font = [[NSFontManager sharedFontManager] convertFont:font toNotHaveTrait:NSBoldFontMask];
		else font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSBoldFontMask];
		attributes[NSFontAttributeName] = font;
		[self setTypingAttributes:attributes];
	}
}

- (void) italic:(id) sender {
	if( ! [self isEditable] ) return;
	if( [self selectedRange].length ) {
		NSRange limitRange, effectiveRange;
		NSTextStorage *text = [self textStorage];
		NSFont *font = nil;
		BOOL hasBold = NO;

		limitRange = [self selectedRange];
		font = [text attribute:NSFontAttributeName atIndex:limitRange.location longestEffectiveRange:NULL inRange:limitRange];
		if( [[NSFontManager sharedFontManager] traitsOfFont:font] & NSItalicFontMask ) hasBold = YES;
		else hasBold = NO;
		while( limitRange.length > 0 ) {
			font = [text attribute:NSFontAttributeName atIndex:limitRange.location longestEffectiveRange:&effectiveRange inRange:limitRange];
			if( ! font ) font = [NSFont userFontOfSize:0.];
			if( hasBold ) font = [[NSFontManager sharedFontManager] convertFont:font toNotHaveTrait:NSItalicFontMask];
			else font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSItalicFontMask];
			[text addAttribute:NSFontAttributeName value:font range:effectiveRange];
			limitRange = NSMakeRange( NSMaxRange( effectiveRange ), NSMaxRange( limitRange ) - NSMaxRange( effectiveRange ) );
		}
	} else {
		NSMutableDictionary *attributes = [[self typingAttributes] mutableCopy];
		NSFont *font = attributes[NSFontAttributeName];
		if( ! font ) font = [NSFont userFontOfSize:0.];
		if( [[NSFontManager sharedFontManager] traitsOfFont:font] & NSItalicFontMask )
			font = [[NSFontManager sharedFontManager] convertFont:font toNotHaveTrait:NSItalicFontMask];
		else font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSItalicFontMask];
		attributes[NSFontAttributeName] = font;
		[self setTypingAttributes:attributes];
	}
}

- (void) changeBackgroundColor:(id) sender {
	NSParameterAssert( [sender respondsToSelector:@selector( color )] );

	NSColor *color = [sender performSelector:@selector( color )];
	NSRange range = [self selectedRange];
	if( ! [self isEditable] ) return;
	if( [color alphaComponent] == 0. ) color = nil;
	if( color && ! range.length ) {
		NSMutableDictionary *attributes = [[self typingAttributes] mutableCopy];
		attributes[NSBackgroundColorAttributeName] = color;
		[self setTypingAttributes:attributes];
	} else [[self textStorage] addAttribute:NSBackgroundColorAttributeName value:color range:range];
}

#pragma mark -
#pragma mark Find Support

- (IBAction) orderFrontFindPanel:(id) sender {
	[[JVTranscriptFindWindowController sharedController] showWindow:sender];
}

- (IBAction) findNext:(id) sender {
	[[JVTranscriptFindWindowController sharedController] findNext:sender];
}

- (IBAction) findPrevious:(id) sender {
	[[JVTranscriptFindWindowController sharedController] findPrevious:sender];
}

#pragma mark -

- (BOOL) autocompleteWithSuffix:(BOOL) suffix {
	if( [self usesSystemCompleteOnTab] ) {
		[self complete:nil];
		return YES;
	}

	_lastCompletionMatch = nil;

	_lastCompletionPrefix = nil;

	NSMutableCharacterSet *allowedCharacters = (NSMutableCharacterSet *)[NSMutableCharacterSet alphanumericCharacterSet];
	[allowedCharacters addCharactersInString:@"#/`_-|^{}[]\\~"];

	NSCharacterSet *illegalCharacters = [allowedCharacters invertedSet];

	// get partial completion & insertion point location
	NSRange curPos = [self selectedRange];
	NSString *partialCompletion = nil;
	NSRange wordStart = [[self string] rangeOfCharacterFromSet:illegalCharacters options:NSBackwardsSearch range:NSMakeRange( 0, curPos.location )];

	// get the string before
	if( wordStart.location == NSNotFound )
		wordStart = NSMakeRange( 0, 0 );
	NSRange theRange = NSMakeRange( NSMaxRange( wordStart ), curPos.location - NSMaxRange( wordStart ) );
	partialCompletion = [[self string] substringWithRange:theRange];

	// only allow an empty tab completion if the current position is zero, this feels best in practice
	if( curPos.location && ! [partialCompletion length] ) {
		NSBeep();
		return YES;
	}

	// compile list of possible completions
	NSArray *possibleNicks = [[self delegate] textView:self stringCompletionsForPrefix:partialCompletion];
	NSString *name = nil;
	NSString *tabCompletion = [[NSUserDefaults standardUserDefaults] stringForKey:@"JVTabCompletionString"];

	// insert word or suggestion
	if( [possibleNicks count] == 1 && ( curPos.location == [[self string] length] || [illegalCharacters characterIsMember:[[self string] characterAtIndex:curPos.location]] ) ) {
		name = possibleNicks[0];
		NSRange replacementRange = NSMakeRange( curPos.location - [partialCompletion length], [partialCompletion length] );

		_ignoreSelectionChanges = YES;
		[self replaceCharactersInRange:replacementRange withString:name];

		if( suffix && replacementRange.location == 0 )	{
			if( [tabCompletion length] ) [self insertText:tabCompletion];
			else [self insertText:@": "];
		}
		else if( suffix ) [self insertText:@" "];
		_tabCompletting = NO;
		_ignoreSelectionChanges = NO;

		if( [[self delegate] respondsToSelector:@selector( textView:selectedCompletion:fromPrefix: )] )
			[[self delegate] textView:self selectedCompletion:name fromPrefix:partialCompletion];
	} else if( [possibleNicks count] > 1 ) {
		// since several are available, we highlight the modified text
		NSRange wordRange;
		BOOL full = YES;

		_lastCompletionPrefix = [partialCompletion copy];

		if( curPos.location == [[self string] length] || [illegalCharacters characterIsMember:[[self string] characterAtIndex:curPos.location]] ) {
			wordRange = NSMakeRange( curPos.location - [partialCompletion length], [partialCompletion length] );
			name = possibleNicks[0];
		} else {
			wordRange = [[self string] rangeOfCharacterFromSet:illegalCharacters options:0 range:NSMakeRange( curPos.location, [[self string] length] - curPos.location )];
			if( wordRange.location == NSNotFound )
				wordRange = NSMakeRange( NSMaxRange( wordStart ), [[self string] length] - NSMaxRange( wordStart )) ;
			else wordRange = NSMakeRange( NSMaxRange( wordStart ), wordRange.location - NSMaxRange( wordStart ));

			NSString *tempWord = [[self string] substringWithRange:wordRange];
			BOOL keepSearching = YES;
			unsigned count = 0;

			do {
				keepSearching = ! [possibleNicks[count] isEqualToString:tempWord];
			} while ( ++count < [possibleNicks count] && keepSearching );

			if( count == [possibleNicks count] ) count = 0;

			name = possibleNicks[count];
			full = NO;
		}

		_lastCompletionMatch = [name copy];

		if ( suffix && wordRange.location == 0 )	{
			if ( [tabCompletion length] ) name = [name stringByAppendingString:tabCompletion];
			else name = [name stringByAppendingString:@": "];
		}
		else if ( suffix ) name = [name stringByAppendingString:@" "];

		_ignoreSelectionChanges = YES;
		[self replaceCharactersInRange:wordRange withString:( full ? name : _lastCompletionMatch )];
		[self setSelectedRange:NSMakeRange( curPos.location, [name length] - [partialCompletion length] )];
		_ignoreSelectionChanges = NO;
	} else {
		NSBeep(); // no matches
		_tabCompletting = NO;
	}

	return YES;
}

#pragma mark -

- (BOOL) validateMenuItem:(NSMenuItem *) menuItem {
	if( [menuItem action] == @selector( bold: ) ) {
		return [self isEditable];
	} else if( [menuItem action] == @selector( italic: ) ) {
		return [self isEditable];
	}
	return [super validateMenuItem:menuItem];
}
@end
