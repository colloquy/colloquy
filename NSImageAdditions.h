#import <AppKit/NSImage.h>

@interface NSImage (NSImageFlippedDrawAdditions)
- (void) drawFlippedInRect:(NSRect) rect operation:(NSCompositingOperation) op fraction:(float) delta;
- (void) drawFlippedInRect:(NSRect) rect operation:(NSCompositingOperation) op;
@end
