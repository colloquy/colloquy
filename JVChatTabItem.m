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
	NSImage *active = [_controller icon];

	if( [_controller respondsToSelector:@selector( statusImage )] && [(id)_controller statusImage] )
		active = [(id)_controller statusImage];

	if( [active size].width > 16. || [active size].height > 16. ) {
		NSImage *ret = [[active copy] autorelease];
		[ret setScalesWhenResized:YES];
		[ret setSize:NSMakeSize( 16., 16. )];
		active = ret;
	}

	return active;
}

- (id) view {
	return [_controller view];
}

- (id) initialFirstResponder {
	return [_controller firstResponder];
}
@end