#import "MVMenuButton.h"

@implementation MVMenuButton
- (void) encodeWithCoder:(NSCoder *) coder {
	[super encodeWithCoder:coder];
}

- (id) initWithCoder:(NSCoder *) coder {
	self = [super initWithCoder:coder];
	_size = NSRegularControlSize;
	_drawsArrow = NO;
	_orgImage = [[self image] copy];
	_smallImage = nil;
	_toolbarItem = nil;
	return self;
}

- (void) dealloc {
	[_orgImage release];
	[_smallImage release];

	_orgImage = nil;
	_smallImage = nil;
	_toolbarItem = nil;

	[super dealloc];
}

- (void) drawRect:(NSRect) rect {
    [super drawRect:rect];

    if( [self drawsArrow] ) {
	    NSBezierPath *path = [NSBezierPath bezierPath];

		if( _size == NSRegularControlSize ) {
			[path moveToPoint:NSMakePoint( NSWidth( [self frame] ) - 6, NSHeight( [self frame] ) - 3 )];
			[path relativeLineToPoint:NSMakePoint( 6, 0 )];
			[path relativeLineToPoint:NSMakePoint( -3, 3 )];
		} else if( _size == NSSmallControlSize ) {
			[path moveToPoint:NSMakePoint( NSWidth( [self frame] ) - 4, NSHeight( [self frame] ) - 3 )];
			[path relativeLineToPoint:NSMakePoint( 4, 0 )];
			[path relativeLineToPoint:NSMakePoint( -2, 3 )];
		}

		[path closePath];
		[[[NSColor blackColor] colorWithAlphaComponent:0.75] set];
		[path fill];
    }
}

- (void) mouseDown:(NSEvent *) theEvent {
	if( ! [self isEnabled] ) return;
	if( ! [self menu] ) {
		[super mouseDown:theEvent];
		return;
	}

	[self highlight:YES];

	NSPoint point = [self convertPoint:[self bounds].origin toView:nil];
	point.y -= NSHeight( [self frame] ) + 2.;
	point.x -= 1.;

	NSEvent *event = [NSEvent mouseEventWithType:[theEvent type] location:point modifierFlags:[theEvent modifierFlags] timestamp:[theEvent timestamp] windowNumber:[[theEvent window] windowNumber] context:[theEvent context] eventNumber:[theEvent eventNumber] clickCount:[theEvent clickCount] pressure:[theEvent pressure]];
	[NSMenu popUpContextMenu:[self menu] withEvent:event forView:self];

	[self mouseUp:[[NSApplication sharedApplication] currentEvent]];
}

- (void) mouseUp:(NSEvent *) theEvent {
	[self highlight:NO];
	[super mouseUp:theEvent];
}

- (void) mouseDragged:(NSEvent *) theEvent {
	return;
}

- (NSControlSize) controlSize {
	return ( _size ? _size : NSRegularControlSize );
}

- (void) setControlSize:(NSControlSize) controlSize {
	if( ! _orgImage ) _orgImage = [[self image] copy];
	if( controlSize == NSRegularControlSize ) {
		[super setImage:_orgImage];
		[_toolbarItem setMinSize:NSMakeSize( 32., 32. )];
		[_toolbarItem setMaxSize:NSMakeSize( 32., 32. )];
	} else if( controlSize == NSSmallControlSize ) {
		if( ! _smallImage ) {
			_smallImage = [_orgImage copy];
			[_smallImage setScalesWhenResized:YES];
			[_smallImage setSize:NSMakeSize( 24., 24. )];
		}
		[super setImage:_smallImage];
		[_toolbarItem setMinSize:NSMakeSize( 24., 24. )];
		[_toolbarItem setMaxSize:NSMakeSize( 24., 24. )];
	}
	_size = controlSize;
}

- (void) setImage:(NSImage *) image {
	return;
}

- (void) reallySetImage:(NSImage *) image {
    [super setImage:image];
}

- (NSImage *) smallImage {
	return [[_smallImage retain] autorelease];
}

- (void) setSmallImage:(NSImage *) image {
	[_smallImage autorelease];
	_smallImage = [image copy];
}

- (NSToolbarItem *) toolbarItem {
	return [[_toolbarItem retain] autorelease];
}

- (void) setToolbarItem:(NSToolbarItem *) item {
	_toolbarItem = item;
}

- (BOOL) drawsArrow {
	return _drawsArrow;
}

- (void) setDrawsArrow:(BOOL) arrow {
	_drawsArrow = arrow;
}
@end
