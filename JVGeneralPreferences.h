#import "NSPreferences.h"

@interface JVGeneralPreferences : NSPreferencesModule {
	IBOutlet NSPopUpButton *encoding;
	IBOutlet NSPopUpButton *yourName;
	IBOutlet NSPopUpButton *buddyNames;
	IBOutlet NSButton *autoCheckVersion;
}
- (void) buildEncodingMenu;
- (IBAction) changeEncoding:(id) sender;
- (IBAction) changeSelfPreferredName:(id) sender;
- (IBAction) changeBuddyPreferredName:(id) sender;
- (IBAction) changeAutomaticVersionCheck:(id) sender;
@end
