#import "NSPreferences.h"

@class WebView;
@class NSPopUpButton;
@class NSTextView;
@class JVFontPreviewField;
@class NSTextField;
@class NSStepper;
@class NSSet;

@interface JVAppearancePreferences : NSPreferencesModule {
	IBOutlet WebView *preview;
	IBOutlet NSPopUpButton *styles;
	IBOutlet NSPopUpButton *emoticons;
	IBOutlet JVFontPreviewField *standardFont;
	IBOutlet JVFontPreviewField *fixedWidthFont;
	IBOutlet JVFontPreviewField *serifFont;
	IBOutlet JVFontPreviewField *sansSerifFont;
	IBOutlet NSTextField *minimumFontSize;
	IBOutlet NSStepper *minimumFontSizeStepper;
	NSSet *_styleBundles;
	NSSet *_emoticonBundles;
}
- (void) updateChatStylesMenu;
- (void) updateEmoticonsMenu;
- (void) updatePreview;
@end
