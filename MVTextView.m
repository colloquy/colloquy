#import <Cocoa/Cocoa.h>
#import "MVTextView.h"

@implementation MVTextView
- (void)interpretKeyEvents:(NSArray *)eventArray
{
	NSMutableArray *newArray = [NSMutableArray array];
	NSEnumerator *e = [eventArray objectEnumerator];
	id anEvent;
	
	if (![self isEditable]) {
		[super interpretKeyEvents:eventArray];
		return;
	}
	
	while (anEvent = [e nextObject]) {
		if (![self checkKeyEvent:(NSEvent *)anEvent])
			[newArray addObject:anEvent];
	}
	
	if ([newArray count] > 0)
		[super interpretKeyEvents:newArray];
	
	if( ! [[self textStorage] length] )
		[self reset:nil];
}

- (BOOL)checkKeyEvent:(NSEvent *) event {
	unichar chr = 0;
	if( [[event charactersIgnoringModifiers] length] )
		chr = [[event charactersIgnoringModifiers] characterAtIndex:0];

	if( chr == NSCarriageReturnCharacter && [[self delegate] respondsToSelector:@selector( textView:returnKeyPressed: )] ) {
		if( [[self delegate] textView:self returnKeyPressed:event] ) return YES;
	} else if( chr == NSEnterCharacter && [[self delegate] respondsToSelector:@selector( textView:enterKeyPressed: )] ) {
		if( [[self delegate] textView:self enterKeyPressed:event] ) return YES;
	} else if( chr == NSTabCharacter && [[self delegate] respondsToSelector:@selector( textView:tabKeyPressed: )]) {
		if( [[self delegate] textView:self tabKeyPressed:event] ) return YES;
	} else if( chr == 0x1B && [[self delegate] respondsToSelector:@selector( textView:escapeKeyPressed: )] ) {
		if( [[self delegate] textView:self escapeKeyPressed:event] ) return YES;
	} else if( chr >= 0xF700 && chr <= 0xF8FF && [[self delegate] respondsToSelector:@selector( textView:functionKeyPressed: )] ) {
		if( [[self delegate] textView:self functionKeyPressed:event] ) return YES;
	}
	
	return NO;
}

- (void) reset:(id) sender {
	if( ! [self isEditable] ) return;
	[self setString:@""];
	[self setTypingAttributes:nil];
	[self resetCursorRects];
}

- (void) resetCursorRects {
	NSRange limitRange, effectiveRange;
	unsigned int count = 0, i = 0;
	NSRectArray rects = NULL;
	NSCursor *linkCursor = [[[NSCursor alloc] initWithImage:[NSImage imageNamed:@"MVLinkCursor"] hotSpot:NSMakePoint( 6., 0. )] autorelease];

	[super resetCursorRects];
	limitRange = NSMakeRange( 0, [[self string] length] );
	while( limitRange.length > 0 ) {
		NSDictionary *dict = [[self textStorage] attributesAtIndex:limitRange.location longestEffectiveRange:&effectiveRange inRange:limitRange];
		NSString *link = [dict objectForKey:NSLinkAttributeName];
		if( link ) {
			rects = [[self layoutManager] rectArrayForCharacterRange:effectiveRange withinSelectedCharacterRange:effectiveRange inTextContainer:[self textContainer] rectCount:&count];
			for( i = 0; i < count; i++ ) [self addCursorRect:NSIntersectionRect( [self visibleRect], rects[i] ) cursor:linkCursor];
		}
		limitRange = NSMakeRange( NSMaxRange( effectiveRange ), NSMaxRange( limitRange ) - NSMaxRange( effectiveRange ) );
	}
}

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
		NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithDictionary:[self typingAttributes]];
		NSFont *font = [attributes objectForKey:NSFontAttributeName];
		if( ! font ) font = [NSFont userFontOfSize:0.];
		if( [[NSFontManager sharedFontManager] traitsOfFont:font] & NSBoldFontMask )
			font = [[NSFontManager sharedFontManager] convertFont:font toNotHaveTrait:NSBoldFontMask];
		else font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSBoldFontMask];
		[attributes setObject:font forKey:NSFontAttributeName];
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
		NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithDictionary:[self typingAttributes]];
		NSFont *font = [attributes objectForKey:NSFontAttributeName];
		if( ! font ) font = [NSFont userFontOfSize:0.];
		if( [[NSFontManager sharedFontManager] traitsOfFont:font] & NSItalicFontMask )
			font = [[NSFontManager sharedFontManager] convertFont:font toNotHaveTrait:NSItalicFontMask];
		else font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSItalicFontMask];
		[attributes setObject:font forKey:NSFontAttributeName];
		[self setTypingAttributes:attributes];
	}
}

- (void) changeBackgroundColor:(id) sender {
	NSColor *color = [sender color];
	NSRange range = [self selectedRange];
	if( ! [self isEditable] ) return;
	if( [color alphaComponent] == 0. ) color = nil;
	if( ! range.length ) {
		NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithDictionary:[self typingAttributes]];
		[attributes setObject:color forKey:NSBackgroundColorAttributeName];
		[self setTypingAttributes:attributes];
	} else [[self textStorage] addAttribute:NSBackgroundColorAttributeName value:color range:range];
}

- (BOOL) validateMenuItem:(NSMenuItem *) menuItem {
	if( [menuItem action] == @selector( bold: ) ) {
		return [self isEditable];
	} else if( [menuItem action] == @selector( italic: ) ) {
		return [self isEditable];
	}
	return [super validateMenuItem:menuItem];
}
@end
