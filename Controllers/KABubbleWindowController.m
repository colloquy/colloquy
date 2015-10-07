#import "KABubbleWindowController.h"
#import "KABubbleWindowView.h"

static NSUInteger bubbleWindowDepth = 0;

@implementation KABubbleWindowController

#define TIMER_INTERVAL ( 1. / 30. )
#define FADE_INCREMENT 0.05
#define DISPLAY_TIME 4.
#define KABubblePadding 10.

#pragma mark -

+ (KABubbleWindowController *) bubble {
	return [[self alloc] init];
}

+ (KABubbleWindowController *) bubbleWithTitle:(NSString *) title text:(id) text icon:(NSImage *) icon {
	id ret = [[self alloc] init];
	[ret setTitle:title];
	if( [text isKindOfClass:[NSString class]] ) [ret setText:text];
	else if( [text isKindOfClass:[NSAttributedString class]] ) [ret setAttributedText:text];
	[ret setIcon:icon];
	return ret;
}

- (instancetype) init {
	NSPanel *panel = [[NSPanel alloc] initWithContentRect:NSMakeRect( 0., 0., 270., 65. ) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
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

	if (self = [super initWithWindow:panel]) {
	KABubbleWindowView *view = [[KABubbleWindowView alloc] initWithFrame:[panel frame]];
	[view setTarget:self];
	[view setAction:@selector( _bubbleClicked: )];
	[panel setContentView:view];

	NSRect screen = [[NSScreen mainScreen] visibleFrame];
	[panel setFrameTopLeftPoint:NSMakePoint( NSWidth( screen ) - NSWidth( [panel frame] ) - KABubblePadding, NSMaxY( screen ) - KABubblePadding - ( NSHeight( [panel frame] ) * bubbleWindowDepth ) )];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _applicationDidSwitch: ) name:NSApplicationDidBecomeActiveNotification object:[NSApplication sharedApplication]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector( _applicationDidSwitch: ) name:NSApplicationDidHideNotification object:[NSApplication sharedApplication]];

	_self = self;
	_depth = ++bubbleWindowDepth;
	_autoFadeOut = YES;
	_delegate = nil;
	_target = nil;
	_representedObject = nil;
	_action = NULL;
	_animationTimer = nil;

	}
	return self;
}

//TODO: check this! dealloc will NEVER be called due to _self retaining self!
- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	_self = nil;
	_target = nil;
	_representedObject = nil;
	_delegate = nil;
	_animationTimer = nil;

	if( _depth == bubbleWindowDepth ) bubbleWindowDepth = 0;

}

#pragma mark -

- (void) _stopTimer {
	[_animationTimer invalidate];
	_animationTimer = nil;
}

- (void) _waitBeforeFadeOut {
	[self _stopTimer];
	_animationTimer = [NSTimer scheduledTimerWithTimeInterval:DISPLAY_TIME target:self selector:@selector( startFadeOut ) userInfo:nil repeats:NO];
}

- (void) _fadeIn:(NSTimer *) inTimer {
	if( [[self window] alphaValue] < 1. ) {
		[[self window] setAlphaValue:[[self window] alphaValue] + FADE_INCREMENT];
	} else if( _autoFadeOut ) {
		if( [_delegate respondsToSelector:@selector( bubbleDidFadeIn: )] )
			[_delegate bubbleDidFadeIn:self];
		[self _waitBeforeFadeOut];
	}
}

- (void) _fadeOut:(NSTimer *) inTimer {
	if( [[self window] alphaValue] > 0. ) {
		[[self window] setAlphaValue:[[self window] alphaValue] - FADE_INCREMENT];
	} else {
		[self _stopTimer];
		if( [_delegate respondsToSelector:@selector( bubbleDidFadeOut: )] )
			[_delegate bubbleDidFadeOut:self];
		[self close];
		_self = nil; // Relase, we retained when we faded in.
	}
}

- (void) _applicationDidSwitch:(NSNotification *) notification {
	[self startFadeOut];
}

- (void) _bubbleClicked:(id) sender {
	if( _target && _action && [_target respondsToSelector:_action] )
		[_target performSelector:_action withObject:self];
	[self startFadeOut];
}

#pragma mark -

- (void) startFadeIn {
	if( [_delegate respondsToSelector:@selector( bubbleWillFadeIn: )] )
		[_delegate bubbleWillFadeIn:self];
	 // Retain, after fade out we release.
	[self showWindow:nil];
	[self _stopTimer];
	_animationTimer = [NSTimer scheduledTimerWithTimeInterval:TIMER_INTERVAL target:self selector:@selector( _fadeIn: ) userInfo:nil repeats:YES];
}

- (void) startFadeOut {
	if( [_delegate respondsToSelector:@selector( bubbleWillFadeOut: )] )
		[_delegate bubbleWillFadeOut:self];
	[self _stopTimer];
	_animationTimer = [NSTimer scheduledTimerWithTimeInterval:TIMER_INTERVAL target:self selector:@selector( _fadeOut: ) userInfo:nil repeats:YES];
}

#pragma mark -

@synthesize automaticallyFadesOut = _autoFadeOut;

#pragma mark -

- (id) representedObject {
	return _representedObject;
}

- (void) setRepresentedObject:(id) object {
	_representedObject = object;
}

#pragma mark -

- (BOOL) respondsToSelector:(SEL) selector {
	if( [[[self window] contentView] respondsToSelector:selector] ) return YES;
	else return [super respondsToSelector:selector];
}

- (void) forwardInvocation:(NSInvocation *) invocation {
	if( [[[self window] contentView] respondsToSelector:[invocation selector]] )
		[invocation invokeWithTarget:[[self window] contentView]];
	else [super forwardInvocation:invocation];
}

- (NSMethodSignature *) methodSignatureForSelector:(SEL) selector {
	if( [[[self window] contentView] respondsToSelector:selector] )
		return [[[self window] contentView] methodSignatureForSelector:selector];
	else return [super methodSignatureForSelector:selector];
}
@end
