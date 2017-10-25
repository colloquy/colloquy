//
//  ESFloater.m
//  Adium
//
//  Created by Evan Schoenberg on Wed Oct 08 2003.//

#import "ESFloater.h"

#define WINDOW_FADE_FPS                         24.0
#define WINDOW_FADE_STEP                        0.3
#define WINDOW_FADE_SLOW_STEP                   0.1
#define WINDOW_FADE_MAX                         1.0
#define WINDOW_FADE_MIN                         0.0
#define WINDOW_FADE_SNAP                        0.05 //How close to min/max we must get before fade is finished

@interface ESFloater (PRIVATE)
- (instancetype)initWithImage:(NSImage *)inImage styleMask:(NSUInteger)styleMask;
- (void)_setWindowOpacity:(CGFloat)opacity;
@end

@implementation ESFloater

//
+ (instancetype)floaterWithImage:(NSImage *)inImage styleMask:(NSUInteger)styleMask title:(NSString *) title
{
    return([[self alloc] initWithImage:inImage styleMask:styleMask title:title]);
}

//
- (instancetype)initWithImage:(NSImage *)inImage styleMask:(NSUInteger)styleMask title:(NSString *) title
{
    NSRect  frame;

    //Init
    if (!(self = [super init])) return nil;
    windowIsVisible = NO;
    visibilityTimer = nil;
    maxOpacity = WINDOW_FADE_MAX;

    //Set up the panel
    frame = NSMakeRect(0, 0, [inImage size].width, [inImage size].height);
    panel = [[NSPanel alloc] initWithContentRect:frame
                                       styleMask:styleMask
                                         backing:NSBackingStoreBuffered
                                           defer:NO];
	if( title) [panel setTitle:title];
    [panel setHidesOnDeactivate:NO];
    [panel setIgnoresMouseEvents:YES];
    [panel setLevel:NSStatusWindowLevel];
    [self _setWindowOpacity:WINDOW_FADE_MIN];

    //Setup the static view
    staticView = [[NSImageView alloc] initWithFrame:frame];
	[staticView setImage:inImage];
    [staticView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[panel contentView] addSubview:staticView];

    return(self);
}

//
- (void)moveFloaterToPoint:(NSPoint)inPoint
{
    [panel setFrameOrigin:inPoint];
    [panel orderFront:nil];
}

//
- (void)setImage:(NSImage *)inImage
{
    NSRect frame = [panel frame];
    frame.size = NSMakeSize([inImage size].width, [inImage size].height);
    [staticView setImage:inImage];
    [panel setFrame:frame display:YES animate:NO];
}

//
- (NSImage *)image
{
    return [staticView image];
}

//
- (void)endFloater
{
    [self close:nil];
}

//
- (IBAction)close:(id)sender
{
    [visibilityTimer invalidate];  visibilityTimer = nil;
    [panel orderOut:nil];
     panel = nil;

}

//
- (void)setMaxOpacity:(CGFloat)inMaxOpacity
{
    maxOpacity = inMaxOpacity;
    if(windowIsVisible) [self _setWindowOpacity:maxOpacity];
}

//Window Visibility --------------------------------------------------------------------------------------------------
//Update the visibility of this window (Window is visible if there are any tabs present)
- (void)setVisible:(BOOL)inVisible animate:(BOOL)animate
{
    if(inVisible != windowIsVisible){
        windowIsVisible = inVisible;

        if(animate){
            if(!visibilityTimer){
                visibilityTimer = [NSTimer scheduledTimerWithTimeInterval:(1.0/WINDOW_FADE_FPS) target:self selector:@selector(_updateWindowVisiblityTimer:) userInfo:nil repeats:YES];
            }
        }else{
            [self _setWindowOpacity:(windowIsVisible ? maxOpacity : WINDOW_FADE_MIN)];
        }
    }
}

//Smoothly
- (void)_updateWindowVisiblityTimer:(NSTimer *)inTimer
{
    CGFloat   alphaValue = [panel alphaValue];

    if(windowIsVisible){
        alphaValue += (maxOpacity - alphaValue) * (( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSShiftKeyMask ) ? WINDOW_FADE_SLOW_STEP : WINDOW_FADE_STEP);
        if(alphaValue > maxOpacity - WINDOW_FADE_SNAP) alphaValue = maxOpacity;
    }else{
        alphaValue -= (alphaValue - WINDOW_FADE_MIN) * (( [[[NSApplication sharedApplication] currentEvent] modifierFlags] & NSShiftKeyMask ) ? WINDOW_FADE_SLOW_STEP : WINDOW_FADE_STEP);
        if(alphaValue < WINDOW_FADE_MIN + WINDOW_FADE_SNAP) alphaValue = WINDOW_FADE_MIN;
    }
    [self _setWindowOpacity:alphaValue];

    //
    if(alphaValue == maxOpacity || alphaValue == WINDOW_FADE_MIN){
        [visibilityTimer invalidate];  visibilityTimer = nil;
    }
}

- (void)_setWindowOpacity:(CGFloat)opacity
{
    [panel setAlphaValue:opacity];
    [panel setOpaque:(opacity == 1.0)];
}


@end
