#import "MVMenuButton.h"

@implementation MVMenuButton
- (id) copyWithZone:(NSZone *) zone {
	id newObj = [[[self class] allocWithZone:zone] init];

	[newObj setImage:[self image]];
	[newObj setSmallImage:[self smallImage]];
	[newObj setAlternateImage:[self alternateImage]];
	[newObj setImagePosition:[self imagePosition]];
	[newObj setButtonType:NSMomentaryChangeButton];
	[newObj setState:[self state]];
	[newObj setBordered:[self isBordered]];
	[newObj setTransparent:[self isTransparent]];
	[newObj setBezelStyle:[self bezelStyle]];
	[newObj setMenu:[self menu]];
	[newObj setMenuDelay:[self menuDelay]];
	[newObj setControlSize:[self controlSize]];

	return newObj;
}

- (void) encodeWithCoder:(NSCoder *) coder {
	[super encodeWithCoder:coder];
	if( [coder allowsKeyedCoding] ) {
		[coder encodeObject:menu forKey:@"menu"];
		[coder encodeDouble:menuDelay forKey:@"menuDelay"];
	} else {
		[coder encodeObject:menu];
		[coder encodeValueOfObjCType:@encode( double ) at:&menuDelay];
	}
}

- (id) initWithCoder:(NSCoder *) coder {
	self = [super initWithCoder:coder];
	if( [coder allowsKeyedCoding] ) {
		menu = [[coder decodeObjectForKey:@"menu"] retain];
		menuDelay = [coder decodeDoubleForKey:@"menuDelay"];
	} else {
		menu = [[coder decodeObject] retain];
		[coder decodeValueOfObjCType:@encode( double ) at:&menuDelay];
	}
	menuDidDisplay = NO;
	clickHoldTimer = nil;
	return self;
}

- (void) dealloc {
	[clickHoldTimer invalidate];
	[clickHoldTimer autorelease];
	[menu autorelease];

	clickHoldTimer = nil;
	menu = nil;

	[super dealloc];
}

- (void) mouseDown:(NSEvent *) theEvent {
	if( ! [self isEnabled] ) return;
	if( ! menu ) {
		[super mouseDown:theEvent];
		return;
	}
	[self highlight:YES];
	[clickHoldTimer invalidate];
	[clickHoldTimer autorelease];
	menuDidDisplay = NO;
	clickHoldTimer = [[NSTimer scheduledTimerWithTimeInterval:menuDelay target:self selector:@selector( displayMenu: ) userInfo:nil repeats:NO] retain];
}

- (void) mouseUp:(NSEvent *) theEvent {
	[clickHoldTimer invalidate];
	[clickHoldTimer autorelease];
	clickHoldTimer = nil;
	if( ! menuDidDisplay && ([theEvent type] & NSLeftMouseUp) )
		[self sendAction:[self action] to:[self target]];
	if( menuDidDisplay && ([theEvent type] & NSLeftMouseUp) )
		menuDidDisplay = NO;
	[self highlight:NO];
	[super mouseUp:theEvent];
}

- (void) mouseDragged:(NSEvent *) theEvent {
	return;
}

- (void) setMenuDelay:(NSTimeInterval) aDelay {
	menuDelay = aDelay;
}

- (NSTimeInterval) menuDelay {
	return menuDelay;
}

- (void) setMenu:(NSMenu *) aMenu {
	[menu autorelease];
	menu = [aMenu copy];
}

- (NSMenu *) menu {
	return [[menu retain] autorelease];
}

- (void) displayMenu:(id) sender {
	[NSMenu popUpContextMenu:menu withEvent:[[NSApplication sharedApplication] currentEvent] forView:self];
	menuDidDisplay = YES;
	[self mouseUp:[[NSApplication sharedApplication] currentEvent]];
}

- (NSControlSize) controlSize {
	return ( size ? size : NSRegularControlSize );
}

- (void) setControlSize:(NSControlSize) controlSize {
	if( ! orgImage ) orgImage = [[self image] copy];
	if( controlSize == NSRegularControlSize ) {
		[self setImage:orgImage];
	} else if( controlSize == NSSmallControlSize ) {
		if( ! smallImage ) {
			smallImage = [orgImage copy];
			[smallImage setScalesWhenResized:YES];
			[smallImage setSize:NSMakeSize( 22., 22. )];
		}
		[self setImage:smallImage];
	}
	size = controlSize;
}

- (NSImage *) smallImage {
	return [[smallImage retain] autorelease];
}

- (void) setSmallImage:(NSImage *) smimg {
	[smallImage autorelease];
	smallImage = [smimg copy];
}
@end
