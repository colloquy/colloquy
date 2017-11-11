#import "UIPrintPageRendererAdditions.h"

@implementation UIPrintPageRenderer (Additions)
- (NSData *) PDFRender {
	NSMutableData *PDFRepresentation = [NSMutableData data];

	UIGraphicsBeginPDFContextToData(PDFRepresentation, self.paperRect, nil); {
		[self prepareForDrawingPages:NSMakeRange(0, self.numberOfPages)];

		CGRect bounds = UIGraphicsGetPDFContextBounds();
		for (NSInteger i = 0; i < self.numberOfPages; i++ ) {
			UIGraphicsBeginPDFPage();

			[self drawPageAtIndex:i inRect:bounds];
		}
	} UIGraphicsEndPDFContext();

	return PDFRepresentation;
}
@end
