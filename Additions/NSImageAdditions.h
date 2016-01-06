@interface NSImage (NSImageAdditions)
- (void) tileInRect:(NSRect) rect;

+ (NSImage *) imageFromPDF:(NSString *) pdfName;
@end
