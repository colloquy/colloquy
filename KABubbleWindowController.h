/* KABubbleWindowController */

#import <Cocoa/Cocoa.h>

@interface KABubbleWindowController : NSWindowController
{
    IBOutlet NSImageView *icon;
    IBOutlet NSTextField *msgText;
    IBOutlet NSTextField *username;
	
	NSTimer *animationTimer;
}

- (void) fadeIn:(NSTimer *) inTimer;
- (void) fadeOut:(NSTimer *) inTimer;
- (void) stopTimer;

@end
