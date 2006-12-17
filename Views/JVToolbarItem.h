#import <AppKit/NSToolbarItem.h>

@interface JVToolbarItem : NSToolbarItem {
	id _representedObject;
}
- (void) setRepresentedObject:(id) object;
- (id) representedObject;
@end
