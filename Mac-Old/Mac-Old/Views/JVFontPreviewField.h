@protocol JVFontPreviewFieldDelegate;

@interface JVFontPreviewField : NSTextField {
	NSFont *_actualFont;
	BOOL _showPointSize;
	BOOL _showFontFace;
}
- (id <JVFontPreviewFieldDelegate>)delegate;
- (void)setDelegate:(id <JVFontPreviewFieldDelegate>)anObject;
- (void) selectFont:(id) sender;
- (IBAction) chooseFontWithFontPanel:(id) sender;
- (void) setShowPointSize:(BOOL) show;
@end

@protocol JVFontPreviewFieldDelegate <NSTextFieldDelegate>
- (BOOL) fontPreviewField:(JVFontPreviewField *) field shouldChangeToFont:(NSFont *) font;
- (void) fontPreviewField:(JVFontPreviewField *) field didChangeToFont:(NSFont *) font;
@end
