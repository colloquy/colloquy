#import <Cocoa/Cocoa.h>

@interface MVMenuButton : NSButton <NSCoding> {
@protected
	BOOL _drawsArrow;
	NSImage *_orgImage;
	NSImage *_smallImage;
	NSControlSize _size;
	__unsafe_unretained NSToolbarItem *_toolbarItem;
	BOOL _retina;
}

@property NSControlSize controlSize;
@property (nonatomic, copy) NSImage *smallImage;
@property (nonatomic, assign) NSToolbarItem *toolbarItem;
@property (nonatomic) BOOL drawsArrow;
@property (nonatomic) BOOL retina;
@end
