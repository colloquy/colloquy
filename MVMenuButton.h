#import <Cocoa/Cocoa.h>

@interface MVMenuButton : NSButton <NSCoding> {
@protected
	BOOL _menuDidDisplay;
	NSImage *_orgImage, *_smallImage;
	NSControlSize _size;
	NSToolbarItem *_toolbarItem;
}
- (void) displayMenu:(id) sender;

- (NSControlSize) controlSize;
- (void) setControlSize:(NSControlSize) controlSize;

- (NSImage *) smallImage;
- (void) setSmallImage:(NSImage *) image;

- (NSToolbarItem *) toolbarItem;
- (void) setToolbarItem:(NSToolbarItem *) item;
@end
