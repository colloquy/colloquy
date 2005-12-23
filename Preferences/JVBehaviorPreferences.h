#import "NSPreferences.h"

@interface JVBehaviorPreferences : NSPreferencesModule {
	IBOutlet NSPopUpButton *returnKeyAction;
	IBOutlet NSPopUpButton *enterKeyAction;
	IBOutlet NSTextField *sendHistory;
	IBOutlet NSStepper *sendHistoryStepper;
	IBOutlet NSTextField *messageScrollback;
	IBOutlet NSStepper *messageScrollbackStepper;
	IBOutlet NSButton *autoRejoinCheck;
	IBOutlet NSStepper *rejoinDelayStepper;
	IBOutlet NSTextField *rejoinDelay;
}
- (IBAction) changeRejoinDelay:(id) sender;
- (IBAction) changeSendOnReturnAction:(id) sender;
- (IBAction) changeSendOnEnterAction:(id) sender;
- (IBAction) changeSendHistory:(id) sender;
- (IBAction) changeMessageScrollback:(id) sender;
@end
