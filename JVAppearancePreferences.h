#import "NSPreferences.h"

@class WebView;
@class NSPopUpButton;
@class NSTextView;
@class NSTextField;
@class NSStepper;
@class NSSet;

@interface JVAppearancePreferences : NSPreferencesModule {
	IBOutlet WebView *preview;
	IBOutlet NSPopUpButton *styles;
	IBOutlet NSPopUpButton *emoticons;
	IBOutlet NSTextField *standardFont;
	IBOutlet NSTextField *fixedWidthFont;
	IBOutlet NSTextField *serifFont;
	IBOutlet NSTextField *sansSerifFont;
	IBOutlet NSTextField *minimumFontSize;
	IBOutlet NSStepper *minimumFontSizeStepper;
	NSSet *_styleBundles;
	NSSet *_emoticonBundles;
}
- (void) updateChatStylesMenu;
- (void) updateEmoticonsMenu;
- (void) updatePreview;
@end
