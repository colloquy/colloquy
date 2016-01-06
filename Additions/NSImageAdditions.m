#import "NSImageAdditions.h"

@implementation NSImage (NSImageAdditions)
// Created for Adium by Evan Schoenberg on Tue Dec 02 2003 under the GPL.
// Draw this image in a rect, tiling if the rect is larger than the image
- (void) tileInRect:(NSRect) rect {
	NSSize size = [self size];
	NSRect destRect = NSMakeRect( rect.origin.x, rect.origin.y, size.width, size.height );
	double top = rect.origin.y + rect.size.height;
	double right = rect.origin.x + rect.size.width;

	NSRect sourceRect = NSMakeRect( 0, 0, size.width, size.height );

	// Tile vertically
	while( destRect.origin.y < top ) {
		// Tile horizontally
		while( destRect.origin.x < right ) {
			// Crop as necessary
			if( ( destRect.origin.x + destRect.size.width ) > right )
				sourceRect.size.width -= ( destRect.origin.x + destRect.size.width ) - right;

			if( ( destRect.origin.y + destRect.size.height ) > top )
				sourceRect.size.height -= ( destRect.origin.y + destRect.size.height ) - top;

			// Draw and shift
			[self drawAtPoint:destRect.origin fromRect:sourceRect operation:NSCompositeSourceOver fraction:1.0];
			destRect.origin.x += destRect.size.width;
		}

		destRect.origin.y += destRect.size.height;
	}
}

// Everything below here was created for Colloquy by Zachary Drayer under the same license as Chat Core
+ (NSImage *) imageFromPDF:(NSString *) pdfName {
	static NSMutableDictionary *images = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		images = [NSMutableDictionary dictionary];
	});

	NSImage *image = images[pdfName];
	if (!image) {
		NSImage *temporaryImage = [NSImage imageNamed:pdfName];
		image = [[NSImage alloc] initWithData:temporaryImage.TIFFRepresentation];

		images[pdfName] = image;
	}

	return image;
}
@end
