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

+ (KABubbleWindowController *) bubble {
	return [[[self alloc] init] autorelease];
}

+ (KABubbleWindowController *) bubbleWithTitle:(NSString *) title text:(id) text icon:(NSImage *) icon {
	id ret = [[[self alloc] init] autorelease];
	[ret setTitle:title];
	if( [text isKindOfClass:[NSString class]] ) [ret setText:text];
	else if( [text isKindOfClass:[NSAttributedString class]] ) [ret setAttributedText:text];
	[ret setIcon:icon];
	return ret;
}

- (id) init {
	extern unsigned int bubbleWindowDepth;

	NSPanel *panel = [[[NSPanel alloc] initWithContentRect:NSMakeRect( 0., 0., 270., 65. ) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO] autorelease];
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

	_depth = ++bubbleWindowDepth;

	return ( self = [super initWithWindow:panel] );
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
	[self retain]; // Retain, after fade out we relase.
	[self showWindow:nil];
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
		[self autorelease]; // Relase, we retained when we faded in.
	}
}

- (BOOL) respondsToSelector:(SEL) selector {
	if( [[[self window] contentView] respondsToSelector:selector] )
		return [[[self window] contentView] respondsToSelector:selector];
	else return [super respondsToSelector:selector];
}

- (void) forwardInvocation:(NSInvocation *) invocation {
	if( [[[self window] contentView] respondsToSelector:[invocation selector]] )
		[invocation invokeWithTarget:[[self window] contentView]];
	else [super forwardInvocation:invocation];
}

- (NSMethodSignature *) methodSignatureForSelector:(SEL) selector {
	if( [[[self window] contentView] respondsToSelector:selector] )
		return [(NSObject *)[[self window] contentView] methodSignatureForSelector:selector];
	else return [super methodSignatureForSelector:selector];
}
@end