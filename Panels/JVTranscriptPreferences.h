#import "NSPreferences.h"

@interface JVTranscriptPreferences : NSPreferencesModule {
	IBOutlet NSPopUpButton *transcriptFolder;
}
- (IBAction) changeTranscriptFolder:(id) sender;
@end