#import "KABubbleWindowController.h"
#import "KABubbleWindowView.h"

@implementation KABubbleWindowController

#define TIMER_INTERVAL  (1.0/30)
#define FADE_INCREMENT  0.02
#define DISPLAY_TIME	3.0

#pragma mark -

- (id) init {
	NSWindow* window = [[[NSWindow alloc] initWithContentRect:NSMakeRect( 0., 0., 250., 50. ) 
										styleMask:NSBorderlessWindowMask 
										  backing:NSBackingStoreBuffered 
											defer:NO] autorelease];

	//set up our window
	[window setBackgroundColor: [NSColor clearColor]];
	[window setLevel: NSStatusWindowLevel];
	[window setAlphaValue:0.15];
	[window setOpaque:NO];
	[window setHasShadow: YES];
	[window setCanHide:NO ];

	NSView *view = [[[KABubbleWindowView alloc] initWithFrame:NSMakeRect( 0., 0., 250., 50. )] autorelease];

	[window setContentView:view];

	self = [super initWithWindow:window];

	[[self window] setTitle:@"Alert"];
	[self showWindow:self];
	[[self window] setDelegate:self];

	//set the timer
	animationTimer = [NSTimer scheduledTimerWithTimeInterval:TIMER_INTERVAL
													  target:self
													selector:@selector(fadeIn:)
													userInfo:nil
													 repeats:YES];
	return self;
}

- (void) dealloc {
	if ( animationTimer ) {
		[animationTimer invalidate];
		[animationTimer release];	
	}
}

#pragma mark -

//these are called from the timer method, they merely increment 
- (void) fadeIn:(NSTimer *) inTimer {
	if ( [[self window] alphaValue] < 1.0 ) {
		[[self window] setAlphaValue:[[self window] alphaValue] + FADE_INCREMENT];
	} else {
		[self stopTimer];
	}
}

- (void) fadeOut:(NSTimer *) inTimer {
	if ( [[self window] alphaValue] > 0.0 ) {
		[[self window] setAlphaValue:[[self window] alphaValue] - FADE_INCREMENT];
	} else {
		[self stopTimer];
	}
}

- (void) stopTimer {
	[animationTimer invalidate];
	[animationTimer release];
}

@end
