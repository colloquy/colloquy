#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>

@class NSPanel;
@class NSProgressIndicator;
@class NSTextField;
@class NSTableView;
@class MVChatConnection;

@interface MVConnectionsController : NSWindowController {
@private
	IBOutlet NSTableView *connections;
	IBOutlet NSWindow *editConnection;
	IBOutlet NSPanel *openConnection;
	IBOutlet NSPanel *joinRoom;
	IBOutlet NSPanel *messageUser;
	IBOutlet NSPanel *nicknameAuth;

	/* Nick Auth */
	IBOutlet NSTextField *authNickname;
	IBOutlet NSTextField *authAddress;
	IBOutlet NSTextField *authPassword;
	IBOutlet NSButton *authKeychain;

	/* New Connection */
	IBOutlet NSTextField *newNickname;
	IBOutlet NSTextField *newAddress;
	IBOutlet NSTextField *newPort;
	IBOutlet NSButton *newRemember;

	/* Edit Connection */
	IBOutlet NSTextField *editNickname;
	IBOutlet NSTextField *editPassword;
	IBOutlet NSTextField *editServerPassword;
	IBOutlet NSTextField *editAddress;
	IBOutlet NSTextField *editPort;
	IBOutlet NSButton *editAutomatic;
	IBOutlet NSTableView *editRooms;
	IBOutlet NSButton *editRemoveRoom;

	/* Join Room & Message User */
	IBOutlet NSComboBox *roomToJoin;
	IBOutlet NSTextField *roomPassword;
	IBOutlet NSTextField *userToMessage;

	NSString *_target;
	BOOL _targetRoom;
	NSMutableArray *_bookmarks;
	int _editingRow;
	NSMutableArray *_editingRooms;
	MVChatConnection *_passConnection;
}
+ (MVConnectionsController *) defaultManager;

- (IBAction) showConnectionManager:(id) sender;

- (IBAction) newConnection:(id) sender;
- (IBAction) conenctNewConnection:(id) sender;

- (IBAction) messageUser:(id) sender;
- (IBAction) joinRoom:(id) sender;

- (IBAction) editConnection:(id) sender;
- (IBAction) addRoom:(id) sender;
- (IBAction) removeRoom:(id) sender;

- (IBAction) sendPassword:(id) sender;

- (void) addConnection:(MVChatConnection *) connection keepBookmark:(BOOL) keep;
- (void) handleURL:(NSURL *) url andConnectIfPossible:(BOOL) connect;
@end
