#import <AppKit/NSNibDeclarations.h>
#import "NSPreferences.h"

@interface JVInterfacePreferences : NSPreferencesModule {
	IBOutlet NSPopUpButton *newRooms;
	IBOutlet NSPopUpButton *newChats;
	IBOutlet NSPopUpButton *newTranscripts;
	IBOutlet NSPopUpButton *newConsoles;
	IBOutlet NSButton *sortByStatus;
	IBOutlet NSButton *tabbedWindows;
}
- (IBAction) changeSortByStatus:(id) sender;
- (IBAction) changeTabbedWindows:(id) sender;
- (IBAction) changePreferredWindow:(id) sender;
@end
