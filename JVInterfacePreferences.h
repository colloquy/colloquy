#import <AppKit/NSNibDeclarations.h>
#import "NSPreferences.h"

@interface JVInterfacePreferences : NSPreferencesModule {
	IBOutlet NSPopUpButton *newRooms;
	IBOutlet NSPopUpButton *newChats;
	IBOutlet NSPopUpButton *newTranscripts;
	IBOutlet NSPopUpButton *newConsoles;
	IBOutlet NSPopUpButton *returnKeyAction;
	IBOutlet NSPopUpButton *enterKeyAction;
	IBOutlet NSTextField *sendHistory;
	IBOutlet NSStepper *sendHistoryStepper;
}
- (IBAction) changeSendHistory:(id) sender;
- (IBAction) changePreferredWindow:(id) sender;
- (IBAction) changeSendOnReturnAction:(id) sender;
- (IBAction) changeSendOnEnterAction:(id) sender;
@end
