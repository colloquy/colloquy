#import "JVWebView.h"

@implementation JVWebView
- (id) initWithCoder:(NSCoder *) coder {
	self = [super initWithCoder:coder];
	forwarding = NO;
	[self setNextTextView:nil];
	return self;
}

- (void) dealloc {
	[self setNextTextView:nil];
	[super dealloc];
}

- (void) forwardSelector:(SEL) selector withObject:(id) object {
	if( [self nextTextView] ) {
		[[self window] makeFirstResponder:[self nextTextView]];
		[[self nextTextView] tryToPerform:selector with:object];
	}
}

- (void) keyDown:(NSEvent *) event {
	if( forwarding ) return;
	forwarding = YES;
	[self forwardSelector:@selector( keyDown: ) withObject:event];
	forwarding = NO;
}

- (void) pasteAsPlainText:(id) sender {
	if( forwarding ) return;
	forwarding = YES;
	[self forwardSelector:@selector( pasteAsPlainText: ) withObject:sender];
	forwarding = NO;
}

- (void) pasteAsRichText:(id) sender {
	if( forwarding ) return;
	forwarding = YES;
	[self forwardSelector:@selector( pasteAsRichText: ) withObject:sender];
	forwarding = NO;
}

- (NSTextView *) nextTextView {
	return nextTextView;
}

- (void) setNextTextView:(NSTextView *) textView {
	nextTextView = textView;
}
@end