#import <Cocoa/Cocoa.h>
#import "JVChatTabItem.h"
#import "JVChatWindowController.h"

@implementation JVChatTabItem
- (id) initWithChatViewController:(id <JVChatViewController>) controller {
	if( ( self = [super initWithIdentifier:[controller identifier]] ) ) {
		_controller = [controller retain];
	}
	return self;
}

- (void) dealloc {
	[_controller release];
	_controller = nil;
	[super dealloc];
}

- (id <JVChatViewController>) chatViewController {
	return _controller;
}

- (NSString *) label {
	return [_controller title];
}

- (NSImage *) icon {
	NSImage *ret = [[[_controller icon] copy] autorelease];
	[ret setScalesWhenResized:YES];
	[ret setSize:NSMakeSize( 16., 16. )];

	if( [_controller respondsToSelector:@selector( statusImage )] && [(id)_controller statusImage] )
		return [(id)_controller statusImage];
	return ret;
}

- (id) view {
	return [_controller view];
}

- (id) initialFirstResponder {
	return [_controller firstResponder];
}
@end