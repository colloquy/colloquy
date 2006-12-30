#import "NSPreferences.h"

@interface JVFileTransferPreferences : NSPreferencesModule {
	IBOutlet NSPopUpButton *saveDownloads;
	IBOutlet NSTextField *minRate;
	IBOutlet NSTextField *maxRate;
	IBOutlet NSButton *autoOpenPorts;
}
- (IBAction) changePortRange:(id) sender;
- (IBAction) changeAutoOpenPorts:(id) sender;
- (IBAction) changeSaveDownloads:(id) sender;
@end
