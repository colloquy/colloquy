#import <AppKit/NSView.h>
#import <AppKit/NSNibDeclarations.h>
#import <Foundation/NSDate.h>

extern NSString *MVStatusViewWillStartScrollingNotification;
extern NSString *MVStatusViewDidStopScrollingNotification;

@class NSArray;
@class NSTimer;
@class NSFont;
@class NSColor;

@interface MVStatusView : NSView {
	id currentMessage, waitingMessage;
	NSArray *cycledMessages;
	NSMutableArray *waitingMessages;
	NSFont *defaultFont;
	NSColor *foregroundColor;
	NSTimer *updateTimer, *delayTimer;
	NSTimeInterval cycleDelay, updateInterval;
	double x, y;
	unsigned long i;
	BOOL verticalPause, oneStep, dontPause;
}
- (void) startUpdatingAtInterval:(NSTimeInterval) interval;
- (IBAction) stopUpdate:(id) sender;
- (void) step:(id) sender;

- (IBAction) next:(id) sender;

- (void) setCurrentMessage:(id) newMessage;
- (id) currentMessage;

- (void) setCycleDelay:(NSTimeInterval) delay;
- (NSTimeInterval) cycleDelay;

- (void) setCycledMessages:(id) newCycle withContinuedPosition:(BOOL) cont;
- (NSArray *) cycledMessages;

- (void) setDefaultFont:(id) newFont;
- (NSFont *) defaultFont;

- (void) setForegroundColor:(id) color;
- (NSColor *) foregroundColor;
@end
