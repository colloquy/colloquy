#import "NSPreferences.h"

@class NSPopUpButton;
@class NSTextField;
@class NSStepper;
@class NSButton;

@interface JVGeneralPreferences : NSPreferencesModule {
	IBOutlet NSPopUpButton *encoding;
	IBOutlet NSPopUpButton *returnKeyAction;
	IBOutlet NSPopUpButton *enterKeyAction;
	IBOutlet NSTextField *sendHistory;
	IBOutlet NSStepper *sendHistoryStepper;
	IBOutlet NSButton *detectNaturalActions;
	IBOutlet NSButton *autoCheckVersion;
}
- (void) buildEncodingMenu;
- (IBAction) changeEncoding:(id) sender;
- (IBAction) changeSendOnReturnAction:(id) sender;
- (IBAction) changeSendOnEnterAction:(id) sender;
- (IBAction) changeNaturalActionDetection:(id) sender;
- (IBAction) changeAutomaticVersionCheck:(id) sender;
@end
