#import <Cocoa/Cocoa.h>
#import "MVImageTextCell.h"

@implementation MVImageTextCell
- (void) dealloc {
	[self setImage:nil];
	[super dealloc];
}

- (id) copyWithZone:(NSZone *) zone {
	MVImageTextCell *cell = (MVImageTextCell *)[super copyWithZone:zone];
	cell -> image = [image retain];
	return cell;
}

- (void) setImage:(NSImage *) anImage {
	[image autorelease];
	image = [anImage retain];
}

- (NSImage *) image {
	return image;
}

- (NSRect) imageFrameForCellFrame:(NSRect) cellFrame {
	if( image ) {
		NSRect imageFrame = NSZeroRect;
		imageFrame.size = [image size];
		imageFrame.origin = cellFrame.origin;
		imageFrame.origin.x += 3.;
		imageFrame.origin.y += ceil( ( cellFrame.size.height - imageFrame.size.height ) / 2 );
		return imageFrame;
	} else return NSZeroRect;
}

- (void) editWithFrame:(NSRect) aRect inView:(NSView *) controlView editor:(NSText *) textObj delegate:(id) anObject event:(NSEvent *) theEvent {
	NSRect textFrame = NSZeroRect, imageFrame = NSZeroRect;
	NSDivideRect( aRect, &imageFrame, &textFrame, 3. + [image size].width, NSMinXEdge );
	[super editWithFrame:textFrame inView:controlView editor:textObj delegate:anObject event:theEvent];
}

- (void) selectWithFrame:(NSRect) aRect inView:(NSView *) controlView editor:(NSText *) textObj delegate:(id) anObject start:(int) selStart length:(int) selLength {
	NSRect textFrame = NSZeroRect, imageFrame = NSZeroRect;
	NSDivideRect( aRect, &imageFrame, &textFrame, 3. + [image size].width, NSMinXEdge );
	[super selectWithFrame:textFrame inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

- (void) drawWithFrame:(NSRect) cellFrame inView:(NSView *) controlView {
	if( image != nil ) {
		NSSize imageSize = NSZeroSize;
		NSRect imageFrame = NSZeroRect;

		imageSize = [image size];
		NSDivideRect( cellFrame, &imageFrame, &cellFrame, 3. + imageSize.width, NSMinXEdge );
		if( [self drawsBackground] ) {
			[[self backgroundColor] set];
			NSRectFill( imageFrame );
		}
		imageFrame.origin.x += 0;
		imageFrame.origin.y += -1;
		imageFrame.size = imageSize;

		if( [controlView isFlipped] ) imageFrame.origin.y += ceil( ( cellFrame.size.height + imageFrame.size.height ) / 2 );
		else imageFrame.origin.y += ceil( ( cellFrame.size.height - imageFrame.size.height) / 2 );

		[image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
	}
	[super drawWithFrame:cellFrame inView:controlView];
}

- (NSSize) cellSize {
	NSSize cellSize = [super cellSize];
	cellSize.width += ( image ? [image size].width : 0 ) + 3.;
	return cellSize;
}
@end