#import "KABubbleWindowView.h"

@implementation KABubbleWindowView
- (id) initWithFrame:(NSRect) frame {
	if( ! ( self = [super initWithFrame:frame] ) ) {
		[[NSColor clearColor] set];
		NSRectFill( [self frame] );
	}
	return self;
}

- (void) drawRect:(NSRect) rect {
	float lineWidth = 3.;
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path setLineWidth:lineWidth];

	float radius = 9.;
	NSRect rect = NSInsetRect( [self bounds], radius + lineWidth, radius + lineWidth );
	[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMinX( rect ), NSMinY( rect ) ) radius:radius startAngle:180. endAngle:270.];
	[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMaxX( rect ), NSMinY( rect ) ) radius:radius startAngle:270. endAngle:360.];
	[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMaxX( rect ), NSMaxY( rect ) ) radius:radius startAngle:0. endAngle:90.];
	[path appendBezierPathWithArcWithCenter:NSMakePoint( NSMinX( rect ), NSMaxY( rect ) ) radius:radius startAngle:90. endAngle:180.];
	[path closePath];

	[[NSColor blueColor] set];
	[path stroke];

	[[NSColor whiteColor] set];
	[path fill];

	[[self window] invalidateShadow];
}
@end
