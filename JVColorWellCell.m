#import <Cocoa/Cocoa.h>
#import <ChatCore/NSColorAdditions.h>
#import "JVColorWellCell.h"

static NSMutableSet *colorWellCells = nil;

NSString *JVColorWellCellColorDidChangeNotification = @"JVColorWellCellColorDidChangeNotification";

@implementation JVColorWellCell
+ (void) colorPanelColorChanged:(NSNotification *) notification {
	extern NSMutableSet *colorWellCells;
	NSColorPanel *panel = [notification object];
	NSEnumerator *enumerator = [colorWellCells objectEnumerator];
	JVColorWellCell *cell = nil;

	while( ( cell = [enumerator nextObject] ) ) {
		if( [cell isActive] ) [cell setColor:[panel color]];
	}
}

- (id) initTextCell:(NSString *) string {
	return ( self = [self initImageCell:nil] );
}

- (id) initImageCell:(NSImage *) image {
	[[NSNotificationCenter defaultCenter] addObserver:[self class] selector:@selector( colorPanelColorChanged: ) name:NSColorPanelColorDidChangeNotification object:nil];

	if( ( self = [super initImageCell:nil] ) ) {
		extern NSMutableSet *colorWellCells;
		if( ! colorWellCells ) colorWellCells = [[NSMutableSet set] retain];
		[colorWellCells addObject:self];

		[self setShowsWebValue:YES];
		[self setEditable:YES];
		[self setColor:[NSColor whiteColor]];
		[self setBezelStyle:NSShadowlessSquareBezelStyle];
		[self setButtonType:NSOnOffButton];
		[self setImagePosition:NSImageOnly];
		[super setTarget:self];
		[super setAction:@selector( clicked: )];
	}

	return self;
}

- (id) copyWithZone:(NSZone *) zone {
	JVColorWellCell *ret = [super copyWithZone:zone];
	ret -> _color = [_color copyWithZone:zone];
	ret -> _showsWebValue = _showsWebValue;

	if( ! colorWellCells ) colorWellCells = [[NSMutableSet set] retain];
	[colorWellCells addObject:ret];

	return ret;
}

- (void) release {
	if( ( [self retainCount] - 1 ) == 1 )
		[self performSelector:@selector( releaseFromSet ) withObject:nil afterDelay:0.];

	[super release];
}

- (void) releaseFromSet {
	extern NSMutableSet *colorWellCells;
	[colorWellCells removeObject:self];
	if( ! [colorWellCells count] ) {
		[colorWellCells autorelease];
		colorWellCells = nil;
	}
}

- (void) dealloc {
	[_color release];
	_color = nil;

	[super dealloc];
}

- (void) drawWithFrame:(NSRect) cellFrame inView:(NSView *) controlView {
	NSRect rect = NSInsetRect( cellFrame, 3., 3. );
	rect.size.width = ( rect.size.height * 1.5 );
	[super drawWithFrame:rect inView:controlView];
}

- (void) drawInteriorWithFrame:(NSRect) cellFrame inView:(NSView *) controlView {
	[super drawInteriorWithFrame:cellFrame inView:controlView];
	[_color drawSwatchInRect:NSInsetRect( cellFrame, 5., 5. )];

	if( _showsWebValue ) {
		NSString *webValue = [_color HTMLAttributeValue];
		BOOL highlighted = ( [self isHighlighted] && [[controlView window] firstResponder] == controlView && [[controlView window] isKeyWindow] && [[NSApplication sharedApplication] isActive] );
		NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[self font], NSFontAttributeName, ( [self isEnabled] ? ( highlighted ? [NSColor alternateSelectedControlTextColor] : [NSColor controlTextColor] ) : ( highlighted ? [NSColor alternateSelectedControlTextColor] : [[NSColor controlTextColor] colorWithAlphaComponent:0.50] ) ), NSForegroundColorAttributeName, nil];
		NSSize stringSize = [webValue sizeWithAttributes:attributes];
		float y = NSMinY( cellFrame ) + ( NSHeight( cellFrame ) / 2. ) - ( stringSize.height / 2. );
		[webValue drawInRect:NSMakeRect( NSMinX( cellFrame ) + ( NSHeight( cellFrame ) * 1.5 ) + 8., y, NSMaxX( cellFrame ) - ( NSHeight( cellFrame ) * 1.5 ) - 8., stringSize.height ) withAttributes:attributes];
	}
}

- (BOOL) trackMouse:(NSEvent *) event inRect:(NSRect) cellFrame ofView:(NSView *) controlView untilMouseUp:(BOOL) flag {
	NSRect rect = NSInsetRect( cellFrame, 3., 3. );
	rect.size.width = ( rect.size.height * 1.5 );
	return [super trackMouse:event inRect:rect ofView:controlView untilMouseUp:flag];
}

- (void) deactivate {
	[super setState:NSOffState];
	[[self controlView] setNeedsDisplay:YES];
}

- (void) setState:(int) value {
// do nothing, we handle this internally
}

- (void) clicked:(id) sender {
	[super setState:(! [self state])];
	if( [self state] ) {
		BOOL exclusive = ! ( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSAlternateKeyMask );
		[self activate:exclusive];
	}
}

- (void) activate:(BOOL) exclusive {
	if( exclusive ) {
		extern NSMutableSet *colorWellCells;
		NSEnumerator *enumerator = [colorWellCells objectEnumerator];
		JVColorWellCell *cell = nil;

		while( ( cell = [enumerator nextObject] ) ) {
			if( cell != self && [cell isActive] ) [cell deactivate];
		}
	}

	[[NSColorPanel sharedColorPanel] setContinuous:YES];
	[[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
	[[NSColorPanel sharedColorPanel] setColor:_color];
	[[NSApplication sharedApplication] orderFrontColorPanel:nil];

	[[self controlView] setNeedsDisplay:YES];	
}

- (BOOL) isActive {
	return [self state];
}

- (void) takeColorFrom:(id) sender {
	if( ! [sender respondsToSelector:@selector( color )] ) return;
	[self setColor:[sender color]];
}

- (void) setColor:(NSColor *) color {
	NSParameterAssert( color != nil );
	if( [_color isEqual:color] ) return;

	[_color autorelease];
	_color = [color retain];

	[[NSNotificationCenter defaultCenter] postNotificationName:JVColorWellCellColorDidChangeNotification object:self userInfo:nil];

	if( [self isActive] )
		[[NSColorPanel sharedColorPanel] setColor:_color];

	[[self controlView] setNeedsDisplay:YES];
}

- (NSColor *) color {
	return [[_color retain] autorelease];
}

- (void) setTarget:(id) object {
	[NSException raise:NSIllegalSelectorException format:@"JVColorWellCell does not implement setTarget:"];
}

- (void) setAction:(SEL) action {
	[NSException raise:NSIllegalSelectorException format:@"JVColorWellCell does not implement setAction:"];
}

- (BOOL) hasValidObjectValue {
	return YES;
}

- (id) objectValue {
	return [[_color retain] autorelease];
}

- (void) setObjectValue:(id <NSCopying>) obj {
	if( [(NSObject *)obj isKindOfClass:[NSColor class]] ) {
		[self setColor:(NSColor *)obj];
	} else if( [(NSObject *)obj isKindOfClass:[NSString class]] ) {
		[self setStringValue:(NSString *)obj];
	}
}

- (NSString *) stringValue {
	return [_color HTMLAttributeValue];
}

- (void) setStringValue:(NSString *) string {
	[self setColor:[NSColor colorWithCSSAttributeValue:string]];
}

- (void) setShowsWebValue:(BOOL) web {
	_showsWebValue = web;
}

- (BOOL) showsWebValue {
	return _showsWebValue;
}
@end