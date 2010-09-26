#import "JVSideOutlineView.h"

static void gradientInterpolate( void *info, CGFloat const *inData, CGFloat *outData ) {
	static float light[4] = { 0.67843137, 0.73333333, 0.81568627, 1. };
	static float dark[4] = { 0.59607843, 0.66666667, 0.76862745, 1. };
	float a = inData[0];
	NSUInteger i = 0;

	for( i = 0; i < 4; i++ )
		outData[i] = ( 1. - a ) * dark[i] + a * light[i];
}

@interface NSOutlineView (NSOutlineViewPrivate)
- (NSColor *) _highlightColorForCell:(NSCell *) cell;
- (void) _highlightRow:(int) row clipRect:(NSRect) clip;
@end

@implementation JVSideOutlineView
- (NSColor *) _highlightColorForCell:(NSCell *) cell {
	if( [super respondsToSelector:_cmd] )
		return [super _highlightColorForCell:cell];

    // return nil to prevent normal selection drawing
    return nil;
}

- (void) _highlightRow:(int) row clipRect:(NSRect) clip {
	if( [super respondsToSelector:_cmd] )
		return [super _highlightRow:row clipRect:clip];

	NSRect highlight = [self rectOfRow:row];

	struct CGFunctionCallbacks callbacks = { 0, gradientInterpolate, NULL };
	CGFunctionRef function = CGFunctionCreate( NULL, 1, NULL, 4, NULL, &callbacks );
	CGColorSpaceRef cspace = CGColorSpaceCreateDeviceRGB();

	CGShadingRef shading = CGShadingCreateAxial( cspace, CGPointMake( NSMinX( highlight ), NSMaxY( highlight ) ), CGPointMake( NSMinX( highlight ), NSMinY( highlight ) ), function, false, false );
	CGContextDrawShading( [[NSGraphicsContext currentContext] graphicsPort], shading );

	CGShadingRelease( shading );
	CGColorSpaceRelease( cspace );
	CGFunctionRelease( function );

	static NSColor *rowBottomLine = nil;
	if( ! rowBottomLine )
		rowBottomLine = [[NSColor colorWithCalibratedRed:( 140. / 255. ) green:( 152. / 255. ) blue:( 176. / 255. ) alpha:1.] retain];

	[rowBottomLine set];

	NSRect bottomLine = NSMakeRect( NSMinX( highlight ), NSMaxY( highlight ) - 1., NSWidth( highlight ), 1. );
	NSRectFill( bottomLine );
}

- (void) drawBackgroundInClipRect:(NSRect) clipRect {
	if( [super respondsToSelector:_cmd] )
		return [super drawBackgroundInClipRect:clipRect];

	static NSColor *backgroundColor = nil;
	if( ! backgroundColor )
		backgroundColor = [[NSColor colorWithCalibratedRed:( 229. / 255. ) green:( 237. / 255. ) blue:( 247. / 255. ) alpha:1.] retain];

	[backgroundColor set];
	NSRectFill( clipRect );
}
@end
