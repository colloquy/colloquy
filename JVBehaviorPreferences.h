#import <AppKit/NSNibDeclarations.h>
#import "NSPreferences.h"

@class NSButton;

@interface JVBehaviorPreferences : NSPreferencesModule {
	IBOutlet NSPopUpButton *newRooms;
	IBOutlet NSPopUpButton *newChats;
	IBOutlet NSPopUpButton *newTranscripts;
	IBOutlet NSPopUpButton *newConsoles;
	IBOutlet NSButton *sortByStatus;
	IBOutlet NSButton *tabbedWindows;

	IBOutlet NSButton *checkSpelling;
	IBOutlet NSButton *detectNaturalActions;
	IBOutlet NSPopUpButton *returnKeyAction;
	IBOutlet NSPopUpButton *enterKeyAction;
	IBOutlet NSTextField *sendHistory;
	IBOutlet NSStepper *sendHistoryStepper;
	IBOutlet NSTextField *messageScrollback;
	IBOutlet NSStepper *messageScrollbackStepper;
	IBOutlet NSButton *tabKeyComplete;
	IBOutlet NSTextField *tabKeyCompleteLabel;
}
- (IBAction) changeSortByStatus:(id) sender;
- (IBAction) changeTabbedWindows:(id) sender;
- (IBAction) changePreferredWindow:(id) sender;

- (IBAction) changeSendOnReturnAction:(id) sender;
- (IBAction) changeSendOnEnterAction:(id) sender;
- (IBAction) changeSendHistory:(id) sender;
- (IBAction) changeMessageScrollback:(id) sender;
- (IBAction) changeTabKeyComplete:(id) sender;
- (IBAction) changeSpellChecking:(id) sender;
- (IBAction) changeNaturalActionDetection:(id) sender;
@end
