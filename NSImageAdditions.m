#import <Foundation/Foundation.h>
#import "NSImageAdditions.h"
#import <ChatCore/NSDataAdditions.h>

@implementation NSImage (NSImageAdditions)
// Created for Adium by Evan Schoenberg on Tue Dec 02 2003 under the GPL.
// Returns an image from the owners bundle with the specified name
+ (NSImage *) imageNamed:(NSString *) name forClass:(Class) class {
	NSBundle *ownerBundle = [NSBundle bundleForClass:class];
	NSString *imagePath = [ownerBundle pathForImageResource:name];
	return [[[NSImage alloc] initWithContentsOfFile:imagePath] autorelease];
}

// Created for Adium by Evan Schoenberg on Tue Dec 02 2003 under the GPL.
// Draw this image in a rect, tiling if the rect is larger than the image
- (void) tileInRect:(NSRect) rect {
	NSSize size = [self size];
	NSRect destRect = NSMakeRect( rect.origin.x, rect.origin.y, size.width, size.height );
	double top = rect.origin.y + rect.size.height;
	double right = rect.origin.x + rect.size.width;

	// Tile vertically
	while( destRect.origin.y < top ) {
		// Tile horizontally
		while( destRect.origin.x < right ) {
			NSRect sourceRect = NSMakeRect( 0, 0, size.width, size.height );

			// Crop as necessary
			if( ( destRect.origin.x + destRect.size.width ) > right )
				sourceRect.size.width -= ( destRect.origin.x + destRect.size.width ) - right;

			if( ( destRect.origin.y + destRect.size.height ) > top )
				sourceRect.size.height -= ( destRect.origin.y + destRect.size.height ) - top;

			// Draw and shift
			[self compositeToPoint:destRect.origin fromRect:sourceRect operation:NSCompositeSourceOver];
			destRect.origin.x += destRect.size.width;
		}

		destRect.origin.y += destRect.size.height;
	}
}

+ (NSImage *) imageWithBase64EncodedString:(NSString *) base64String {
	NSImage	*result = [[NSImage alloc ] initWithBase64EncodedString:base64String];
	return [result autorelease];
}

- (id) initWithBase64EncodedString:(NSString *) base64String {
	if( [base64String length] ) {
		NSSize tempSize = { 100, 100 };
		NSData *data = nil;
		NSImageRep *imageRep = nil;

		self = [self initWithSize:tempSize];

		if( self ) {
			// Now, interpret the inBase64String.
			data = [NSData dataWithBase64EncodedString:base64String];

			// Create an image representation from the data.
			if( data ) imageRep = [NSBitmapImageRep imageRepWithData:data];

			if( imageRep ) {
				// Set the real size of the image and add the representation.
				[self setSize:[imageRep size]];
				[self addRepresentation:imageRep];
			}
		}

		return self;
	}

	return nil;
}

- (NSString *) base64EncodingWithFileType:(NSBitmapImageFileType) fileType {
	NSString *result = nil;
	NSBitmapImageRep *imageRep = nil;
	NSData *imageData = nil;

	NSEnumerator *enumerator = [[self representations] objectEnumerator];
	id object = nil;

	// Look for an existing representation in the NSBitmapImageRep class.
	while( ! imageRep && ( object = [enumerator nextObject] ) )
		if( [object isKindOfClass:[NSBitmapImageRep class]] )
			imageRep = object;

	if ( ! imageRep ) {
		imageRep = [NSBitmapImageRep imageRepWithData:[self TIFFRepresentation]];
		if( imageRep ) [self addRepresentation:imageRep];
	}

	if( imageRep ) { 
		NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:1];
		[dict setObject:[NSNumber numberWithBool:NO] forKey:NSImageInterlaced];
		imageData = [imageRep representationUsingType:fileType properties:dict];
	}

	if( imageData ) result = [imageData base64EncodingWithLineLength:78];

	return result;
}
@end