#import <Cocoa/Cocoa.h>
#import "JVWebView.h"

@implementation JVWebView
- (id) initWithCoder:(NSCoder *) coder {
	self = [super initWithCoder:coder];
	[self setNextTextView:nil];
	return self;
}

- (void) dealloc {
	[self setNextTextView:nil];
	[super dealloc];
}

- (void) keyDown:(NSEvent *) event {
	if( [self nextTextView] ) {
		[[self window] makeFirstResponder:[self nextTextView]];
		[[self nextTextView] keyDown:event];
	}
}

- (NSTextView *) nextTextView {
	return nextTextView;
}

- (void) setNextTextView:(NSTextView *) textView {
	nextTextView = textView;
}
@end
