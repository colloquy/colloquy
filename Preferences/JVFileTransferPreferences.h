#import "NSPreferences.h"

@interface JVFileTransferPreferences : NSPreferencesModule {
	IBOutlet NSPopUpButton *saveDownloads;
	IBOutlet NSTextField *minRate;
	IBOutlet NSTextField *maxRate;
}
- (IBAction) changePortRange:(id) sender;
- (IBAction) changeSaveDownloads:(id) sender;
@end
