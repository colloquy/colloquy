#import "KABubbleWindowView.h"

static void KABubbleShadeInterpolate( void *info, CGFloat const *inData, CGFloat *outData ) {
	static const CGFloat dark[4] = { .69412, .83147, .96078, .95 };
	static const CGFloat light[4] = { .93725, .96863, .99216, .95 };
	CGFloat a = inData[0];
	NSUInteger i = 0;

	for( i = 0; i < 4; i++ )
		outData[i] = ( 1. - a ) * dark[i] + a * light[i];
}

#pragma mark -

@implementation KABubbleWindowView

- (void) drawRect:(NSRect) rect {
	[[NSColor clearColor] set];
	NSRectFill( [self frame] );

	CGFloat lineWidth = 4.;
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path setLineWidth:lineWidth];

	CGFloat radius = 9.;
	NSRect irect = NSInsetRect( [self bounds], radius + lineWidth, radius + lineWidth );
	[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMinX( irect ), NSMinY( irect ) ) radius:radius startAngle:180. endAngle:270.];
	[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMaxX( irect ), NSMinY( irect ) ) radius:radius startAngle:270. endAngle:360.];
	[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMaxX( irect ), NSMaxY( irect ) ) radius:radius startAngle:0. endAngle:90.];
	[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMinX( irect ), NSMaxY( irect ) ) radius:radius startAngle:90. endAngle:180.];
	[path closePath];

	[[NSGraphicsContext currentContext] saveGraphicsState];

	[path setClip];

	struct CGFunctionCallbacks callbacks = { 0, KABubbleShadeInterpolate, NULL };
	CGFunctionRef function = CGFunctionCreate( NULL, 1, NULL, 4, NULL, &callbacks );
	CGColorSpaceRef cspace = CGColorSpaceCreateDeviceRGB();

	CGFloat srcX = NSMinX( [self bounds] ), srcY = NSMinY( [self bounds] );
	CGFloat dstX = NSMinX( [self bounds] ), dstY = NSMaxY( [self bounds] );
	CGShadingRef shading = CGShadingCreateAxial( cspace, CGPointMake( srcX, srcY ), CGPointMake( dstX, dstY ), function, false, false );

	CGContextDrawShading( [[NSGraphicsContext currentContext] graphicsPort], shading );

	CGShadingRelease( shading );
	CGColorSpaceRelease( cspace );
	CGFunctionRelease( function );

	[[NSGraphicsContext currentContext] restoreGraphicsState];

	[[NSColor colorWithCalibratedRed:0. green:0. blue:0. alpha:.5] set];
	[path stroke];

	[_title drawAtPoint:NSMakePoint( 55., 40. ) withAttributes:@{NSFontAttributeName: [NSFont boldSystemFontOfSize:13.], NSForegroundColorAttributeName: [NSColor controlTextColor]}];
	[_text drawInRect:NSMakeRect( 55., 10., 200., 30. )];

	if( [_icon size].width > 32. || [_icon size].height > 32. ) { // Assume a square image.
		NSRect rect = NSMakeRect( 0., 0., 32., 32. );
		NSImageRep *sourceImageRep = [_icon bestRepresentationForRect:rect context:[NSGraphicsContext currentContext] hints:nil];
		_icon = [[NSImage alloc] initWithSize:NSMakeSize( 32., 32. )];
		[_icon lockFocus];
		[[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
		[sourceImageRep drawInRect:rect];
		[_icon unlockFocus];
	}

	[_icon drawAtPoint:NSMakePoint( 15., 20. ) fromRect:NSZeroRect operation:NSCompositeSourceAtop fraction:1.];

	[[self window] invalidateShadow];
}

#pragma mark -

- (void) setIcon:(NSImage *) icon {
	_icon = icon;
	[self setNeedsDisplay:YES];
}

- (void) setTitle:(NSString *) title {
	_title = [title copy];
	[self setNeedsDisplay:YES];
}

- (void) setAttributedText:(NSAttributedString *) text {
	_text = [text copy];
	[self setNeedsDisplay:YES];
}

- (void) setText:(NSString *) text {
	_text = [[NSAttributedString alloc] initWithString:text attributes:@{NSFontAttributeName: [NSFont messageFontOfSize:11.], NSForegroundColorAttributeName: [NSColor controlTextColor]}];
	[self setNeedsDisplay:YES];
}

#pragma mark -

- (void) mouseUp:(NSEvent *) event {
	if( _target && _action && [_target respondsToSelector:_action] )
		[_target performSelector:_action withObject:self];
}
@end
