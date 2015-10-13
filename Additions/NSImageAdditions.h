@interface NSImage (NSImageAdditions)
- (void) tileInRect:(NSRect) rect;

- (void) cq_compositeToPoint:(NSPoint) point operation:(NSCompositingOperation) operation;
- (void) cq_compositeToPoint:(NSPoint) point operation:(NSCompositingOperation) operation fraction:(CGFloat) delta;
- (void) cq_compositeToPoint:(NSPoint) point fromRect:(NSRect) rect operation:(NSCompositingOperation) operation;
- (void) cq_compositeToPoint:(NSPoint) point fromRect:(NSRect) rect operation:(NSCompositingOperation) operation fraction:(CGFloat) delta;
- (void) cq_dissolveToPoint:(NSPoint) point fraction:(CGFloat) delta;

+ (NSImage *) imageFromPDF:(NSString *) pdfName;

+ (NSImage *)templateName:(NSString *)templateName withColor:(NSColor *)tint andSize:(CGSize)targetSize;
+ (NSImage *)templateImage:(NSImage *)templateImage withColor:(NSColor *)tint andSize:(CGSize)targetSize;
@end
