#import "MVMenuButton.h"

@implementation MVMenuButton
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
@end
