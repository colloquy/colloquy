#import "NSPreferences.h"

@interface JVGeneralPreferences : NSPreferencesModule {
	IBOutlet NSPopUpButton *encoding;
}
- (void) buildEncodingMenu;
@end
