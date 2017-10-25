@interface NSImage (NSImageAdditions)
- (void) tileInRect:(NSRect) rect;

+ (NSImage *) imageFromPDF:(NSString *) pdfName;

+ (NSImage *)templateName:(NSString *)templateName withColor:(NSColor *)tint andSize:(CGSize)targetSize;
+ (NSImage *)templateImage:(NSImage *)templateImage withColor:(NSColor *)tint andSize:(CGSize)targetSize;
@end
