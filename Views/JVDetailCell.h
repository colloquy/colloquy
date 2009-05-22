@interface JVDetailCell : NSImageCell {
	@private
	NSImage *_statusImage;
	NSImage *_altImage;
	NSString *_mainText;
	NSString *_infoText;
	NSLineBreakMode _lineBreakMode;
	NSUInteger _statusNumber;
	NSUInteger _importantStatusNumber;
	CGFloat _leftMargin;
	BOOL _boldAndWhiteOnHighlight;
}
- (void) setStatusImage:(NSImage *) image;
- (NSImage *) statusImage;

- (void) setHighlightedImage:(NSImage *) image;
- (NSImage *) highlightedImage;

- (void) setMainText:(NSString *) text;
- (NSString *) mainText;

- (void) setInformationText:(NSString *) text;
- (NSString *) informationText;

- (void) setLineBreakMode:(NSLineBreakMode) mode;
- (NSLineBreakMode) lineBreakMode;

- (void) setBoldAndWhiteOnHighlight:(BOOL) boldAndWhite;
- (BOOL) boldAndWhiteOnHighlight;

- (void) setStatusNumber:(NSUInteger) number;
- (NSUInteger) statusNumber;

- (void) setImportantStatusNumber:(NSUInteger) number;
- (NSUInteger) importantStatusNumber;

- (void) setLeftMargin:(CGFloat) margin;
- (CGFloat) leftMargin;
@end
