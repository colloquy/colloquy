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

- (id <JVChatViewController>) chatViewController {
	return _controller;
}

- (NSString *) label {
	return [_controller title];
}

- (id) view {
	return [_controller view];
}

- (id) initialFirstResponder {
	return [_controller firstResponder];
}

- (void) drawLabel:(BOOL) shouldTruncateLabel inRect:(NSRect) labelRect {
	BOOL selected = ( [[self tabView] selectedTabViewItem] == self );
	BOOL disabled = ! [(id)_controller isEnabled];
	float alpha = 1.;

	if( ! selected ) alpha = 0.8;
	if( disabled ) alpha = 0.5;

	NSMutableParagraphStyle *paraStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[paraStyle setLineBreakMode:NSLineBreakByTruncatingTail];

	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont labelFontOfSize:11.], NSFontAttributeName, paraStyle, NSParagraphStyleAttributeName, ( alpha < 1. ? [[NSColor controlTextColor] colorWithAlphaComponent:alpha] : [NSColor controlTextColor] ), NSForegroundColorAttributeName, nil];

	NSRect textRect = labelRect;

	textRect.origin.x += 1.;

	if( [_controller respondsToSelector:@selector( statusImage )] && [(id)_controller statusImage] )
		textRect.size.width -= [[(id)_controller statusImage] size].width + 2.;

	[[self label] drawInRect:textRect withAttributes:attributes];

	if( [_controller respondsToSelector:@selector( statusImage )] ) {
		NSImage *statusImage = [(id)_controller statusImage];
		[statusImage compositeToPoint:NSMakePoint( NSMaxX( labelRect ) + 2. - [statusImage size].width, NSMinY( labelRect ) + ( ( NSHeight( labelRect ) / 2 ) - ( [statusImage size].height / 2 ) ) - 1. ) operation:NSCompositeSourceAtop fraction:0.7];
	}
}

- (NSSize) sizeOfLabel:(BOOL) computeMin {
	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont labelFontOfSize:11.], NSFontAttributeName, [NSColor controlTextColor], NSForegroundColorAttributeName, nil];
	NSSize size = [[self label] sizeWithAttributes:attributes];

	if( [_controller respondsToSelector:@selector( statusImage )] && [(id)_controller statusImage] )
		size.width += [[(id)_controller statusImage] size].width;

	return NSMakeSize( size.width + 5., 15. );
}
@end