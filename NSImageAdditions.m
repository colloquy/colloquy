#import "NSImageAdditions.h"
#import <Cocoa/Cocoa.h>

@implementation NSImage (NSImageFlippedDrawAdditions)
- (void) drawFlippedInRect:(NSRect) rect operation:(NSCompositingOperation) op fraction:(float) delta {
	CGContextRef context;

	context = [[NSGraphicsContext currentContext] graphicsPort];
	CGContextSaveGState( context ); {
		CGContextTranslateCTM( context, 0., NSMaxY( rect ) );
		CGContextScaleCTM( context, 1., -1. );

		rect.origin.y = 0.;
		[self drawInRect:rect fromRect:NSZeroRect operation:op fraction:delta];
	} CGContextRestoreGState( context );
}

- (void) drawFlippedInRect:(NSRect) rect operation:(NSCompositingOperation) op {
    [self drawFlippedInRect:rect operation:op fraction:1.];
}
@end
