#import "JVToolbarItem.h"

@implementation JVToolbarItem
- (void) setRepresentedObject:(id) object {
	id old = _representedObject;
	_representedObject = [object retain];
	[old release];
}

- (id) representedObject {
	return _representedObject;
}

- (void) dealloc {
	[_representedObject release];
	[super dealloc];
}
@end
