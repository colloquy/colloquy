#import <Cocoa/Cocoa.h>
#import "MVTextView.h"

@implementation MVTextView

#define kEnterCharCode 3
#define kTabCharCode 9
#define kReturnCharCode 13
#define kPageUpCharCode 63276
#define kPageDownCharCode 63277
#define kUpArrowCharCode 63232
#define kDownArrowCharCode 63233

- (void) keyDown:(NSEvent *) theEvent {
	NSString *chars = [theEvent charactersIgnoringModifiers];
	if( ! [self isEditable] ) {
		[super keyDown:theEvent];
		return;
	}
	if( [chars length] && [chars characterAtIndex:0] == kReturnCharCode ) {
		if ([[self delegate] respondsToSelector:@selector(textView:returnHit:)]) {
			if( [[self delegate] textView:self returnHit:theEvent] ) return;
		}
	} else if( [chars length] && [chars characterAtIndex:0] == kEnterCharCode ) {
		if( [[self delegate] respondsToSelector:@selector(textView:enterHit:)] ) {
			if( [[self delegate] textView:self enterHit:theEvent] ) return;
		}
	} else if( [chars length] && [chars characterAtIndex:0] == kTabCharCode ) {
		if( [[self delegate] respondsToSelector:@selector(textView:tabHit:)] ) {
			if( [[self delegate] textView:self tabHit:theEvent] ) return;
		}
	} else if( [chars length] && [chars characterAtIndex:0] == kUpArrowCharCode ) {
		if( [[self delegate] respondsToSelector:@selector(textView:upArrowHit:)] ) {
			if( [[self delegate] textView:self upArrowHit:theEvent] ) return;
		}
	} else if( [chars length] && [chars characterAtIndex:0] == kDownArrowCharCode ) {
		if( [[self delegate] respondsToSelector:@selector(textView:downArrowHit:)] ) {
			if( [[self delegate] textView:self downArrowHit:theEvent] ) return;
		}
	}
	[super keyDown:theEvent];
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

- (BOOL) validateMenuItem:(id <NSMenuItem>) menuItem {
	if( [menuItem action] == @selector( bold: ) ) {
		return [self isEditable];
	} else if( [menuItem action] == @selector( italic: ) ) {
		return [self isEditable];
	}
	return [super validateMenuItem:menuItem];
}
@end
