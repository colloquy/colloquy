#import "JVColorWellCell.h"

static NSMutableSet *colorWellCells = nil;

NSString *JVColorWellCellColorDidChangeNotification = @"JVColorWellCellColorDidChangeNotification";

@interface JVColorWellCell ()
- (instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@end

@implementation JVColorWellCell

- (instancetype)initWithCoder:(NSCoder *)coder
{
	return self = [super initWithCoder:coder];
}

+ (void) colorPanelColorChanged:(NSNotification *) notification {
	NSColorPanel *panel = [notification object];

	for( JVColorWellCell *cell in colorWellCells ) {
		if( [cell isActive] ) {
			[cell setColor:[panel color]];
			[[NSNotificationCenter chatCenter] postNotificationName:JVColorWellCellColorDidChangeNotification object:cell userInfo:nil];
		}
	}
}

+ (void) colorPanelClosed:(NSNotification *) notification {
	for( JVColorWellCell *cell in colorWellCells )
		if( [cell isActive] ) [cell deactivate];
}

+ (void) initialize {
	[super initialize];
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( colorPanelColorChanged: ) name:NSColorPanelColorDidChangeNotification object:nil];
		tooLate = YES;
	}
}

#pragma mark -

- (id) initTextCell:(NSString *) string {
	if( ( self = [super initTextCell:@""] ) ) {
		[self _commonInitialization];
	}

	return self;
}

- (id) initImageCell:(NSImage *) image {
	if( ( self = [super initImageCell:nil] ) ) {
		[self _commonInitialization];
	}

	return self;
}

- (void) _commonInitialization {
	static BOOL observingClose = NO;
	if( ! observingClose ) {
		[[NSNotificationCenter defaultCenter] addObserver:[self class] selector:@selector( colorPanelClosed: ) name:NSWindowWillCloseNotification object:[NSColorPanel sharedColorPanel]];
		observingClose = YES;
	}

	if( ! colorWellCells ) colorWellCells = [NSMutableSet set];
	[colorWellCells addObject:self];
	_releasing = NO;

	[self setShowsWebValue:YES];
	[self setEditable:YES];
	[self setColor:[NSColor whiteColor]];
	[self setBezelStyle:NSShadowlessSquareBezelStyle];
	[self setButtonType:NSOnOffButton];
	[self setImagePosition:NSImageOnly];
	[super setTarget:self];
	[super setAction:@selector( clicked: )];
	[super setTitle:@""];
	[super setAlternateTitle:@""];
	[super setImage:nil];
	[super setAlternateImage:nil];
}

- (id) copyWithZone:(NSZone *) zone {
	JVColorWellCell *ret = [super copyWithZone:zone];
	ret -> _color = [_color copyWithZone:zone];
	ret -> _showsWebValue = _showsWebValue;
	ret -> _releasing = NO;

	if( ! colorWellCells ) colorWellCells = [NSMutableSet set];
	[colorWellCells addObject:ret];

	return ret;
}

- (void) dealloc {
	[colorWellCells removeObject:self];
	if( ! [colorWellCells count] ) {
		colorWellCells = nil;
	}
}

#pragma mark -

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
		NSDictionary *attributes = @{NSFontAttributeName: [self font], NSForegroundColorAttributeName: ( [self isEnabled] ? ( highlighted ? [NSColor alternateSelectedControlTextColor] : [NSColor controlTextColor] ) : ( highlighted ? [NSColor alternateSelectedControlTextColor] : [[NSColor controlTextColor] colorWithAlphaComponent:0.50] ) )};
		NSSize stringSize = [webValue sizeWithAttributes:attributes];
		CGFloat y = NSMinY( cellFrame ) + ( NSHeight( cellFrame ) / 2. ) - ( stringSize.height / 2. );
		[webValue drawInRect:NSMakeRect( NSMinX( cellFrame ) + ( NSHeight( cellFrame ) * 1.5 ) + 8., y, NSMaxX( cellFrame ) - ( NSHeight( cellFrame ) * 1.5 ) - 8., stringSize.height ) withAttributes:attributes];
	}
}

- (BOOL) trackMouse:(NSEvent *) event inRect:(NSRect) cellFrame ofView:(NSView *) controlView untilMouseUp:(BOOL) flag {
	NSRect rect = NSInsetRect( cellFrame, 3., 3. );
	rect.size.width = ( rect.size.height * 1.5 );
	return [super trackMouse:event inRect:rect ofView:controlView untilMouseUp:flag];
}

#pragma mark -

- (void) deactivate {
	[super setState:NSOffState];
	[[self controlView] setNeedsDisplay:YES];
}

- (void) setState:(NSInteger) value {
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
		for( JVColorWellCell *cell in colorWellCells ) {
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

#pragma mark -

- (void) takeColorFrom:(id) sender {
	NSParameterAssert( [sender respondsToSelector:@selector( color )] );
	[self setColor:[sender performSelector:@selector( color )]];
}

- (void) setColor:(NSColor *) color {
	if( ! color || [_color isEqual:color] ) return;

	_color = color;

	if( [self isActive] )
		[[NSColorPanel sharedColorPanel] setColor:_color];

	[[self controlView] setNeedsDisplay:YES];
}

- (NSColor *) color {
	return _color;
}

#pragma mark -

- (BOOL) hasValidObjectValue {
	return YES;
}

- (id) objectValue {
	return _color;
}

- (void) setObjectValue:(id <NSCopying>) obj {
	if( [(NSObject *)obj isKindOfClass:[NSColor class]] ) {
		[self setColor:(NSColor *)obj];
	} else if( [(NSObject *)obj isKindOfClass:[NSString class]] ) {
		[self setStringValue:(NSString *)obj];
	}
}

#pragma mark -

- (NSString *) stringValue {
	return [_color HTMLAttributeValue];
}

- (void) setStringValue:(NSString *) string {
	[self setColor:[NSColor colorWithCSSAttributeValue:string]];
}
@end
