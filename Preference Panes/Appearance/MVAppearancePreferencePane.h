#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>
#import <PreferencePanes/NSPreferencePane.h>

@interface MVAppearancePreferencePane : NSPreferencePane {
	IBOutlet NSTextView *exampleChat;
	IBOutlet NSColorWell *defaultTextColor, *actionTextColor, *linkColor, *backgroundColor;
	IBOutlet NSColorWell *myColor, *otherMessageColor, *alertColor, *highlightBackgroundColor;
	IBOutlet NSButton *allowColorMessages, *allowTextFormatting, *disableGraphicEmoticons, *disableLinkHighlighting;
}
- (IBAction) allowsColorChoice:(id) sender;
- (IBAction) allowsTextFormattingChoice:(id) sender;
- (IBAction) showEmoticonsChoice:(id) sender;
- (IBAction) linkHighlightingChoice:(id) sender;

- (void) buildExampleText:(id) sender;
- (void) addMessageToDisplay:(NSString *) message fromUser:(NSString *) user asAction:(BOOL) action asAlert:(BOOL) alert;
@end
