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
	IBOutlet NSButton *tabKeyComplete;
	IBOutlet NSButton *sortByStatus;
	IBOutlet NSButton *tabbedWindows;
	IBOutlet NSTextField *tabKeyCompleteLabel;
}
- (IBAction) changeTabKeyComplete:(id) sender;
- (IBAction) changeSortByStatus:(id) sender;
- (IBAction) changeTabbedWindows:(id) sender;
- (IBAction) changeSendHistory:(id) sender;
- (IBAction) changePreferredWindow:(id) sender;
- (IBAction) changeSendOnReturnAction:(id) sender;
- (IBAction) changeSendOnEnterAction:(id) sender;
@end
