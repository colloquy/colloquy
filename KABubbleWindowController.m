#import <Cocoa/Cocoa.h>
#import "KABubbleWindowController.h"
#import "KABubbleWindowView.h"

static unsigned int bubbleWindowDepth = 0;

@implementation KABubbleWindowController

#define TIMER_INTERVAL ( 1. / 30. )
#define FADE_INCREMENT 0.05
#define DISPLAY_TIME 3.
#define KABubblePadding 10.

#pragma mark -

- (id) init {
	extern unsigned int bubbleWindowDepth;

	NSPanel *panel = [[[NSPanel alloc] initWithContentRect:NSMakeRect( 0., 0., 250., 75. ) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO] autorelease];
	[panel setBecomesKeyOnlyIfNeeded:YES];
	[panel setHidesOnDeactivate:NO];
	[panel setBackgroundColor:[NSColor clearColor]];
	[panel setLevel:NSStatusWindowLevel];
	[panel setAlphaValue:0.];
	[panel setOpaque:NO];
	[panel setHasShadow:YES];
	[panel setCanHide:NO];
	[panel setReleasedWhenClosed:YES];
	[panel setDelegate:self];

	NSView *view = [[[KABubbleWindowView alloc] initWithFrame:[panel frame]] autorelease];
	[panel setContentView:view];

	NSRect screen = [[NSScreen mainScreen] visibleFrame];
	[panel setFrameTopLeftPoint:NSMakePoint( NSWidth( screen ) - NSWidth( [panel frame] ) - KABubblePadding, NSMaxY( screen ) - KABubblePadding - ( NSHeight( [panel frame] ) * bubbleWindowDepth ) )];

	self = [super initWithWindow:panel];

	[self showWindow:nil];
	_depth = ++bubbleWindowDepth;

	[self startFadeIn];
	return self;
}

- (void) dealloc {
	[_animationTimer release];
	[super dealloc];
}

#pragma mark -

- (void) _stopTimer {
	[_animationTimer invalidate];
	[_animationTimer release];
	_animationTimer = nil;
}

- (void) _waitBeforeFadeOut {
	[self _stopTimer];
	_animationTimer = [[NSTimer scheduledTimerWithTimeInterval:DISPLAY_TIME target:self selector:@selector( startFadeOut ) userInfo:nil repeats:NO] retain];
}

- (void) startFadeIn {
	[self _stopTimer];
	_animationTimer = [[NSTimer scheduledTimerWithTimeInterval:TIMER_INTERVAL target:self selector:@selector( _fadeIn: ) userInfo:nil repeats:YES] retain];
}

- (void) _fadeIn:(NSTimer *) inTimer {
	if( [[self window] alphaValue] < 1. ) {
		[[self window] setAlphaValue:[[self window] alphaValue] + FADE_INCREMENT];
	} else {
		[self _waitBeforeFadeOut];
	}
}

- (void) startFadeOut {
	[self _stopTimer];
	_animationTimer = [[NSTimer scheduledTimerWithTimeInterval:TIMER_INTERVAL target:self selector:@selector( _fadeOut: ) userInfo:nil repeats:YES] retain];
}

- (void) _fadeOut:(NSTimer *) inTimer {
	extern unsigned int bubbleWindowDepth;
	if( [[self window] alphaValue] > 0. ) {
		[[self window] setAlphaValue:[[self window] alphaValue] - FADE_INCREMENT];
	} else {
		if( _depth == bubbleWindowDepth ) bubbleWindowDepth = 0;
		[self _stopTimer];
		[self close];
		[self autorelease];
	}
}
@end