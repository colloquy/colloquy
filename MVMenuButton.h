#import <Cocoa/Cocoa.h>

@interface MVMenuButton : NSButton <NSCoding> {
@protected
	NSTimer *_clickHoldTimer;
	BOOL _menuDidDisplay;
	NSTimeInterval _menuDelay;
	NSImage *_orgImage, *_smallImage;
	NSControlSize _size;
	NSToolbarItem *_toolbarItem;
}
- (void) setMenuDelay:(NSTimeInterval) delay;
- (NSTimeInterval) menuDelay;

- (void) displayMenu:(id) sender;

- (NSControlSize) controlSize;
- (void) setControlSize:(NSControlSize) controlSize;

- (NSImage *) smallImage;
- (void) setSmallImage:(NSImage *) image;

- (NSToolbarItem *) toolbarItem;
- (void) setToolbarItem:(NSToolbarItem *) item;
@end
