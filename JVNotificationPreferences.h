#import <AppKit/NSNibDeclarations.h>
#import "NSPreferences.h"

@interface JVNotificationPreferences : NSPreferencesModule {
	IBOutlet NSTextField *highlightWords;
	IBOutlet NSPopUpButton *chatActions;
	IBOutlet NSButton *playSound;
	IBOutlet NSPopUpButton *sounds;
	IBOutlet NSButton *bounceIcon;
	IBOutlet NSButton *untilAttention;
	IBOutlet NSButton *showBubble;
	IBOutlet NSButton *onlyIfBackground;
	IBOutlet NSButton *keepOnScreen;
	NSMutableDictionary *_eventPrefs;
}
- (void) switchEvent:(id) sender;

- (void) saveEventSettings;
- (void) saveHighlightWords:(id) sender;

- (void) buildEventsMenu;
- (void) buildSoundsMenu;

- (void) selectSoundWithPath:(NSString *) path;
- (void) playSound:(id) sender;
- (void) switchSound:(id) sender;

- (void) bounceIcon:(id) sender;
- (void) bounceIconUntilFront:(id) sender;

- (void) showBubble:(id) sender;
- (void) showBubbleIfBackground:(id) sender;
- (void) keepBubbleOnScreen:(id) sender;
@end
