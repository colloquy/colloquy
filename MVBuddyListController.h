#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>

@class ABPerson;
@class NSWindow;
@class NSTableView;
@class MVChatConnection;

@interface MVBuddyListController : NSWindowController {
@private
	IBOutlet NSTableView *buddies;
	IBOutlet NSTextField *myName;
	IBOutlet NSTextField *myStatus;
	IBOutlet NSButton *editStatusButton;
	IBOutlet NSImageView *myIcon;

	IBOutlet NSWindow *pickerWindow;
	IBOutlet NSView *pickerView;

	ABPerson *_me;
	NSMutableDictionary *_buddyList;
	NSMutableDictionary *_onlineBuddies;
	NSMutableDictionary *_buddiesStatus;
	NSString *_serverFilter;
	NSString *_statusMessage;
	NSMutableArray *_connections;
	unsigned int _online;
}
+ (MVBuddyListController *) sharedBuddyList;

- (IBAction) showBuddyList:(id) sender;

- (void) setStatus:(NSString *) status sendToServers:(BOOL) send;
- (void) editStatus:(id) sender;
@end
