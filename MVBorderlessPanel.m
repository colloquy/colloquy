#import "MVBorderlessPanel.h"

@implementation MVBorderlessPanel
- (id) initWithContentRect:(NSRect) contentRect styleMask:(unsigned int) aStyle backing:(NSBackingStoreType) bufferingType defer:(BOOL) flag {
	self = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:flag];
	[self setHasShadow:YES];
	return self;
}

- (void) mouseDragged:(NSEvent *) theEvent {
	NSPoint	currentLocation;
	NSPoint	newOrigin;
	NSRect screenFrame = [[self screen] visibleFrame];
	NSRect windowFrame = [self frame];

	currentLocation = [self convertBaseToScreen:[self mouseLocationOutsideOfEventStream]];
	newOrigin.x = currentLocation.x - initialLocation.x;
	newOrigin.y = currentLocation.y - initialLocation.y;

	if( NSHeight( [[self screen] frame] ) != NSHeight( [[self screen] visibleFrame] ) ) {
		if( ( newOrigin.y + windowFrame.size.height ) > ( screenFrame.origin.y + screenFrame.size.height ) ) {
			newOrigin.y = screenFrame.origin.y + ( screenFrame.size.height - windowFrame.size.height );
		}
	}

	[self setFrameOrigin:newOrigin];
}

- (void) mouseDown:(NSEvent *) theEvent {    
	NSRect windowFrame = [self frame];
	initialLocation = [self convertBaseToScreen:[theEvent locationInWindow]];
	initialLocation.x -= windowFrame.origin.x;
	initialLocation.y -= windowFrame.origin.y;
}
@end
