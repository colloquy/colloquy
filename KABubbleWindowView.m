#import "KABubbleWindowView.h"

@implementation KABubbleWindowView

- (id)initWithFrame:(NSRect)frameRect{
	if ((self = [super initWithFrame:frameRect]) != nil) {

		if (self) {
			[[NSColor clearColor] set];
			NSRectFill([self frame]);
		}
	}
	return self;
}

- (void)drawRect:(NSRect)rect {
	NSRect myRect			= NSInsetRect( [self bounds], 1.0, 1.0 );
	NSBezierPath *aPath 	= [NSBezierPath bezierPath];
	float radius 			= 9.0;
	
	//define points from which we are gonna connect our rectangle
	NSPoint topMid		= NSMakePoint( NSMidX(myRect), NSMaxY(myRect) );
	NSPoint topLeft		= NSMakePoint( NSMinX(myRect), NSMaxY(myRect) );
	NSPoint topRight	= NSMakePoint( NSMaxX(myRect), NSMaxY(myRect) );
	NSPoint bottomRight	= NSMakePoint( NSMaxX(myRect), NSMinY(myRect) );
	
	//the color we are gonna trace it out with
	[[NSColor blueColor] set];
	[aPath setLineWidth:3.0];
	
	//connect our  points together making sure to round off the edges so that 
	//its all nice and purty
	[aPath moveToPoint:topMid];
	[aPath appendBezierPathWithArcFromPoint:topLeft 
									toPoint:myRect.origin
									 radius:radius];
	
	[aPath appendBezierPathWithArcFromPoint:myRect.origin
									toPoint:bottomRight 
									 radius:radius];
	
	[aPath appendBezierPathWithArcFromPoint:bottomRight 
									toPoint:topRight
									 radius:radius];
	
	[aPath appendBezierPathWithArcFromPoint:topRight 
									toPoint:topLeft 
									 radius:radius];
	[aPath closePath];
	
	//roll that beautiful bean footage!
	[aPath stroke];
	[[NSColor whiteColor] set];
	[aPath fill];
	
	[[self window] invalidateShadow];
	
}

@end
