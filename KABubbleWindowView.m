#import "KABubbleWindowView.h"

void KABubbleShadeInterpolate( void *info, float const *inData, float *outData ) {
	static float dark[4] = { .69412, .83147, .96078, .95 };
	static float light[4] = { .93725, .96863, .99216, .95 };

	float a = inData[0];
	int i = 0;
	for( i = 0; i < 4; i++ )
		outData[i] = ( 1. - a ) * dark[i] + a * light[i];
}

@implementation KABubbleWindowView
- (id) initWithFrame:(NSRect) frame {
	if( ! ( self = [super initWithFrame:frame] ) ) {
		[[NSColor clearColor] set];
		NSRectFill( [self frame] );
	}
	return self;
}

- (void) drawRect:(NSRect) rect {
	float lineWidth = 4.;
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path setLineWidth:lineWidth];

	float radius = 9.;
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

	float srcX = NSMinX( [self bounds] ), srcY = NSMinY( [self bounds] );
	float dstX = NSMinX( [self bounds] ), dstY = NSMaxY( [self bounds] );
	CGShadingRef shading = CGShadingCreateAxial( cspace, CGPointMake( srcX, srcY ), CGPointMake( dstX, dstY ), function, false, false );	

	CGContextDrawShading( [[NSGraphicsContext currentContext] graphicsPort], shading );

	CGShadingRelease( shading );
	CGColorSpaceRelease( cspace );
	CGFunctionRelease( function );

	[[NSGraphicsContext currentContext] restoreGraphicsState];

	[[NSColor colorWithCalibratedRed:0. green:0. blue:0. alpha:.5] set];
	[path stroke];

	[[self window] invalidateShadow];
}
@end
