#import <Cocoa/Cocoa.h>

@interface MVMenuButton : NSButton <NSCopying, NSCoding> {
	NSTimer *clickHoldTimer;
	IBOutlet NSMenu *menu;
	BOOL menuDidDisplay;
	NSTimeInterval menuDelay;
	NSImage *orgImage, *smallImage;
	NSControlSize size;
	NSToolbarItem *tbitem;
}
- (void) setMenuDelay:(NSTimeInterval) aDelay;
- (NSTimeInterval) menuDelay;

- (void) setMenu:(NSMenu *) aMenu;
- (NSMenu *) menu;

- (void) displayMenu:(id) sender;

- (NSControlSize) controlSize;
- (void) setControlSize:(NSControlSize) controlSize;

- (NSImage *) smallImage;
- (void) setSmallImage:(NSImage *) smimg;

- (NSToolbarItem *) toolbarItem;
- (void) setToolbarItem:(NSToolbarItem *) item;
@end
