@interface JVDetailCell : NSImageCell {
	@private
	NSImage *_statusImage;
	NSImage *_altImage;
	NSString *_mainText;
	NSString *_infoText;
	NSLineBreakMode _lineBreakMode;
	unsigned _statusNumber;
	unsigned _importantStatusNumber;
	float _leftMargin;
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

- (void) setStatusNumber:(unsigned) number;
- (unsigned) statusNumber;

- (void) setImportantStatusNumber:(unsigned) number;
- (unsigned) importantStatusNumber;

- (void) setLeftMargin:(float) margin;
- (float) leftMargin;
@end
