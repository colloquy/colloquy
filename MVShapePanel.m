#import "MVShapePanel.h"

@implementation MVShapePanel
- (id) initWithContentRect:(NSRect) contentRect styleMask:(unsigned int) aStyle backing:(NSBackingStoreType) bufferingType defer:(BOOL) flag {
	self = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:flag];
    [self setBackgroundColor:[NSColor clearColor]];
    [self setOpaque:NO];
	[self setHasShadow:YES];
	return self;
}
@end
