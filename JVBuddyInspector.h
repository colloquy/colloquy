#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>
#import "JVBuddy.h"
#import "JVInspectorController.h"

@class NSView;

@interface JVBuddy (JVBuddyInspection) <JVInspection>
- (id <JVInspector>) inspector;
@end

@interface JVBuddyInspector : NSObject <JVInspector> {
	IBOutlet NSView *view;
	IBOutlet NSImageView *picture;
	IBOutlet NSTextField *firstName;
	IBOutlet NSTextField *lastName;
	IBOutlet NSTextField *nickname;
	IBOutlet NSTextField *email;
	IBOutlet NSPopUpButton *servers;
	IBOutlet NSTableView *nicknames;
	IBOutlet NSButton *removeNickname;
	IBOutlet NSButton *addNickname;
	JVBuddy *_buddy;
	NSMutableArray *_activeNicknames;
	BOOL _nibLoaded;
}
- (id) initWithBuddy:(JVBuddy *) buddy;

- (IBAction) changeBuddyIcon:(id) sender;
- (IBAction) changeFirstName:(id) sender;
- (IBAction) changeLastName:(id) sender;
- (IBAction) changeNickname:(id) sender;
- (IBAction) changeEmail:(id) sender;

- (IBAction) changeServer:(id) sender;

- (IBAction) addNickname:(id) sender;
- (IBAction) removeNickname:(id) sender;

- (IBAction) editCard:(id) sender;
@end