#import <AppKit/NSNibDeclarations.h>
#import "NSPreferences.h"

@class NSButton;

@interface JVBehaviorPreferences : NSPreferencesModule {
	IBOutlet NSButton *checkSpelling;
	IBOutlet NSButton *detectNaturalActions;
	IBOutlet NSPopUpButton *returnKeyAction;
	IBOutlet NSPopUpButton *enterKeyAction;
	IBOutlet NSTextField *sendHistory;
	IBOutlet NSStepper *sendHistoryStepper;
	IBOutlet NSButton *tabKeyComplete;
	IBOutlet NSTextField *tabKeyCompleteLabel;
}
- (IBAction) changeSendOnReturnAction:(id) sender;
- (IBAction) changeSendOnEnterAction:(id) sender;
- (IBAction) changeSendHistory:(id) sender;
- (IBAction) changeTabKeyComplete:(id) sender;
- (IBAction) changeSpellChecking:(id) sender;
- (IBAction) changeNaturalActionDetection:(id) sender;
@end
