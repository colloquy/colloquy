#import <AppKit/NSTextField.h>

@class NSFont;

@interface JVFontPreviewField : NSTextField {
	NSFont *_actualFont;
}
- (void) selectFont:(id) sender;
- (IBAction) chooseFontWithFontPanel:(id) sender;
@end

@interface NSObject (JVFontPreviewFieldDelegate)
- (BOOL) fontPreviewField:(JVFontPreviewField *) field shouldChangeToFont:(NSFont *) font;
- (void) fontPreviewField:(JVFontPreviewField *) field didChangeToFont:(NSFont *) font;
@end