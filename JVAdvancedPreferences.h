#import "NSPreferences.h"
#import <Cocoa/Cocoa.h>

@interface JVAdvancedPreferences : NSPreferencesModule {
	IBOutlet NSButton *openConsole;
	IBOutlet NSButton *verboseConsole;
	IBOutlet NSButton *hideMsgsInConsole;
}
- (IBAction) toggleShowConsoleBeforeConnecting:(id) sender;
- (IBAction) toggleVerboseSetting:(id) sender;
- (IBAction) toggleHidePrivateMessages:(id) sender;
@end
