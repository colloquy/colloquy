#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>

@class ABPerson;
@class NSWindow;
@class NSTableView;
@class MVChatConnection;
@class ABPeoplePickerController;

@interface MVBuddyListController : NSWindowController {
@private
	IBOutlet NSTableView *buddies;

	IBOutlet NSWindow *pickerWindow;
	IBOutlet NSView *pickerView;

	IBOutlet NSWindow *newPersonWindow;
	IBOutlet NSTextField *nickname;
	IBOutlet NSPopUpButton *server;
	IBOutlet NSTextField *firstName;
	IBOutlet NSTextField *lastName;
	IBOutlet NSTextField *email;
	IBOutlet NSImageView *image;
	IBOutlet NSButton *addButton;

	NSMutableSet *_buddyList;
	NSMutableSet *_onlineBuddies;
	NSMutableDictionary *_buddyInfo;
	ABPeoplePickerController* _picker;
	NSString *_addPerson;
}
+ (MVBuddyListController *) sharedBuddyList;

- (IBAction) showBuddyList:(id) sender;

- (IBAction) showBuddyPickerSheet:(id) sender;
- (IBAction) cancelBuddySelection:(id) sender;
- (IBAction) confirmBuddySelection:(id) sender;

- (IBAction) showNewPersonSheet:(id) sender;
- (IBAction) cancelNewBuddy:(id) sender;
- (IBAction) confirmNewBuddy:(id) sender;

- (IBAction) messageSelectedBuddy:(id) sender;
@end
