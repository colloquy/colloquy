#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>
#import <PreferencePanes/NSPreferencePane.h>

@interface MVNotificationPreferencePane : NSPreferencePane {
	IBOutlet NSButton *playSoundsForActions;
	IBOutlet NSTableView *soundSelections;
	IBOutlet NSButton *showHiddenOnRoomMessage, *showHiddenOnPrivateMessage, *bounceAppIcon, *bounceUntilFront;
	IBOutlet NSTextField *hightlightNames;

	NSMutableArray *chatSoundActions;
	NSMenu *availableSounds;
}
- (IBAction) playActionSoundsChoice:(id) sender;
- (IBAction) showHiddenRoomsChoice:(id) sender;
- (IBAction) showHiddenPrivateMessagesChoice:(id) sender;
- (IBAction) bounceAppIconChoice:(id) sender;
- (IBAction) bounceUntilFrontChoice:(id) sender;

- (void) playSound:(NSString *) path;
@end
