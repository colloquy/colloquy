#import <Cocoa/Cocoa.h>

@interface MVMenuButton : NSButton {
	NSTimer *clickHoldTimer;
	IBOutlet NSMenu *menu;
	BOOL menuDidDisplay;
	NSTimeInterval menuDelay;
}
- (void) setMenuDelay:(NSTimeInterval) aDelay;
- (NSTimeInterval) menuDelay;

- (void) setMenu:(NSMenu *) aMenu;
- (NSMenu *) menu;

- (void) displayMenu:(id) sender;
@end
