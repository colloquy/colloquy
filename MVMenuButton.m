#import "MVMenuButton.h"

@implementation MVMenuButton
- (void) encodeWithCoder:(NSCoder *) coder {
	[super encodeWithCoder:coder];
	if( [coder allowsKeyedCoding] ) {
		[coder encodeDouble:_menuDelay forKey:@"menuDelay"];
		[coder encodeInt:_size forKey:@"controlSize"];
	} else {
		[coder encodeValueOfObjCType:@encode( double ) at:&_menuDelay];
		[coder encodeValueOfObjCType:@encode( int ) at:&_size];
	}
}

- (id) initWithCoder:(NSCoder *) coder {
	self = [super initWithCoder:coder];
	if( [coder allowsKeyedCoding] ) {
		_menuDelay = [coder decodeDoubleForKey:@"menuDelay"];
		_size = (NSControlSize) [coder decodeIntForKey:@"controlSize"];
	} else {
		[coder decodeValueOfObjCType:@encode( double ) at:&_menuDelay];
		[coder decodeValueOfObjCType:@encode( int ) at:&_size];
	}
	_orgImage = nil;
	_smallImage = nil;
	_menuDidDisplay = NO;
	_clickHoldTimer = nil;
	_toolbarItem = nil;
	return self;
}

- (void) dealloc {
	[_clickHoldTimer invalidate];
	[_clickHoldTimer release];
	[_orgImage release];
	[_smallImage release];

	_clickHoldTimer = nil;
	_orgImage = nil;
	_smallImage = nil;
	_toolbarItem = nil;

	[super dealloc];
}

- (void) mouseDown:(NSEvent *) theEvent {
	if( ! [self isEnabled] ) return;
	if( ! [self menu] ) {
		[super mouseDown:theEvent];
		return;
	}
	[self highlight:YES];
	[_clickHoldTimer invalidate];
	[_clickHoldTimer autorelease];
	_menuDidDisplay = NO;
	_clickHoldTimer = [[NSTimer scheduledTimerWithTimeInterval:_menuDelay target:self selector:@selector( displayMenu: ) userInfo:nil repeats:NO] retain];
}

- (void) mouseUp:(NSEvent *) theEvent {
	[_clickHoldTimer invalidate];
	[_clickHoldTimer autorelease];
	_clickHoldTimer = nil;
	if( ! _menuDidDisplay && ([theEvent type] & NSLeftMouseUp) )
		[self sendAction:[self action] to:[self target]];
	if( _menuDidDisplay && ([theEvent type] & NSLeftMouseUp) )
		_menuDidDisplay = NO;
	[self highlight:NO];
	[super mouseUp:theEvent];
}

- (void) mouseDragged:(NSEvent *) theEvent {
	return;
}

- (void) setMenuDelay:(NSTimeInterval) delay {
	_menuDelay = delay;
}

- (NSTimeInterval) menuDelay {
	return _menuDelay;
}

- (void) displayMenu:(id) sender {
	NSPoint point = [self convertPoint:[self bounds].origin toView:nil];
	NSEvent *currentEvent = [[NSApplication sharedApplication] currentEvent];
	NSEvent *event = nil;

	point.y -= NSHeight( [self frame] ) + 2.;
	point.x -= 1.;

	event = [NSEvent mouseEventWithType:[currentEvent type] location:point modifierFlags:[currentEvent modifierFlags] timestamp:[currentEvent timestamp] windowNumber:[[currentEvent window] windowNumber] context:[currentEvent context] eventNumber:[currentEvent eventNumber] clickCount:[currentEvent clickCount] pressure:[currentEvent pressure]];

	[NSMenu popUpContextMenu:[self menu] withEvent:event forView:self];
	_menuDidDisplay = YES;
	[self mouseUp:[[NSApplication sharedApplication] currentEvent]];
}

- (NSControlSize) controlSize {
	return ( _size ? _size : NSRegularControlSize );
}

- (void) setControlSize:(NSControlSize) controlSize {
	if( ! _orgImage ) _orgImage = [[self image] copy];
	if( controlSize == NSRegularControlSize ) {
		[self setImage:_orgImage];
		[_toolbarItem setMinSize:NSMakeSize( 32., 32. )];
		[_toolbarItem setMaxSize:NSMakeSize( 32., 32. )];
	} else if( controlSize == NSSmallControlSize ) {
		if( ! _smallImage ) {
			_smallImage = [_orgImage copy];
			[_smallImage setScalesWhenResized:YES];
			[_smallImage setSize:NSMakeSize( 24., 24. )];
		}
		[self setImage:_smallImage];
		[_toolbarItem setMinSize:NSMakeSize( 24., 24. )];
		[_toolbarItem setMaxSize:NSMakeSize( 24., 24. )];
	}
	_size = controlSize;
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
@end
