#import "NSPreferences.h"

@interface JVTranscriptPreferences : NSPreferencesModule {
	IBOutlet NSButton *logChatRooms;
	IBOutlet NSButton *logPrivateChats;
	IBOutlet NSPopUpButton *transcriptFolder;
	IBOutlet NSPopUpButton *folderOrganization;
	IBOutlet NSPopUpButton *sessionHandling;
	IBOutlet NSButton *humanReadable;
}
- (IBAction) changeLogChatRooms:(id) sender;
- (IBAction) changeLogPrivateChats:(id) sender;
- (IBAction) changeTranscriptFolder:(id) sender;
- (IBAction) changeFolderOrganization:(id) sender;
- (IBAction) changeSessionHandling:(id) sender;
- (IBAction) changeHumanReadable:(id) sender;
@end