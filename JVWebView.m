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

- (void) forwardSelector:(SEL) selector withObject:(id) object {
	if( [self nextTextView] ) {
		[[self window] makeFirstResponder:[self nextTextView]];
		[[self nextTextView] tryToPerform:selector with:object];
	}
}

- (void) keyDown:(NSEvent *) event {
	[self forwardSelector:@selector( keyDown: ) withObject:event];
}

- (void) pasteAsPlainText:(id) sender {
	[self forwardSelector:@selector( pasteAsPlainText: ) withObject:sender];
}

- (void) pasteAsRichText:(id) sender {
	[self forwardSelector:@selector( pasteAsRichText: ) withObject:sender];
}

- (NSTextView *) nextTextView {
	return nextTextView;
}

- (void) setNextTextView:(NSTextView *) textView {
	nextTextView = textView;
}
@end