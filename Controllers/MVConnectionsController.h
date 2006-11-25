#import "JVInspectorController.h"

@class MVChatConnection;

@interface MVConnectionsController : NSWindowController <JVInspectionDelegator> {
@private
	IBOutlet NSTableView *connections;
	IBOutlet NSPanel *openConnection;
	IBOutlet NSPanel *messageUser;
	IBOutlet NSPanel *nicknameAuth;
	IBOutlet NSPanel *certificateAuth;
	IBOutlet NSPanel *publicKeyVerification;
	IBOutlet NSPanel *userSelectionPanel;

	/* Nick Auth */
	IBOutlet NSTextField *authNickname;
	IBOutlet NSTextField *authAddress;
	IBOutlet NSTextField *authPassword;
	IBOutlet NSButton *authKeychain;

	/* Certificate Auth */
	IBOutlet NSTextField *certificateDescription;
	IBOutlet NSTextField *certificatePassphrase;
	IBOutlet NSButton *certificateKeychain;

	/* Public Key Verification */
	IBOutlet NSTextField *publicKeyDescription;
	IBOutlet NSTextField *publicKeyName;
	IBOutlet NSTextField *publicKeyNameDescription;
	IBOutlet NSTextField *publicKeyFingerprint;
	IBOutlet NSTextField *publicKeyBabbleprint;
	IBOutlet NSButton *publicKeyAlwaysAccept;

	/* New Connection */
	IBOutlet NSTextField *newNickname;
	IBOutlet NSPopUpButton *newType;
	IBOutlet NSComboBox *newAddress;
	IBOutlet NSComboBox *newPort;
	IBOutlet NSButton *newRemember;
	IBOutlet NSButton *showDetails;
	IBOutlet NSTabView *detailsTabView;
	IBOutlet NSTextField *newServerPassword;
	IBOutlet NSTextField *newUsername;
	IBOutlet NSTextField *newRealName;
	IBOutlet NSPopUpButton *newProxy;
	IBOutlet NSTableView *newJoinRooms;
	IBOutlet NSButton *newRemoveRoom;
	IBOutlet NSButton *sslConnection;

	/* Message User */
	IBOutlet NSTextField *userToMessage;
	
	/* User selection dialog */
	IBOutlet NSTextField *userSelectionDescription;
	IBOutlet NSTableView *userSelectionTable;
	NSArray *_userSelectionPossibleUsers;

	NSMutableArray *_bookmarks;
	NSMutableArray *_joinRooms;
	MVChatConnection *_passConnection;
	MVChatConnection *_certificateConnection;
	NSDictionary *_publicKeyDictionary;
	NSMutableSet *_publicKeyRequestQueue;
}
+ (MVConnectionsController *) defaultController;

+ (NSMenu *) favoritesMenu;
+ (void) refreshFavoritesMenu;

- (IBAction) showConnectionManager:(id) sender;
- (IBAction) hideConnectionManager:(id) sender;

- (void) newConnectionWithJoinRooms:(NSArray *) rooms;

- (IBAction) newConnection:(id) sender;
- (IBAction) changeNewConnectionProtocol:(id) sender;
- (IBAction) toggleNewConnectionDetails:(id) sender;
- (IBAction) addRoom:(id) sender;
- (IBAction) removeRoom:(id) sender;
- (IBAction) openNetworkPreferences:(id) sender;
- (IBAction) connectNewConnection:(id) sender;

- (IBAction) messageUser:(id) sender;

- (IBAction) sendPassword:(id) sender;

- (IBAction) sendCertificatePassword:(id) sender;

- (IBAction) verifiedPublicKey:(id) sender;

- (IBAction) userSelectionSelected:(id) sender;

- (NSArray *) connections;
- (NSArray *) connectedConnections;
- (MVChatConnection *) connectionForServerAddress:(NSString *) address;
- (NSArray *) connectionsForServerAddress:(NSString *) address;
- (BOOL) managesConnection:(MVChatConnection *) connection;

- (void) setAutoConnect:(BOOL) autoConnect forConnection:(MVChatConnection *) connection;
- (BOOL) autoConnectForConnection:(MVChatConnection *) connection;

- (void) setShowConsoleOnConnect:(BOOL) autoConsole forConnection:(MVChatConnection *) connection;
- (BOOL) showConsoleOnConnectForConnection:(MVChatConnection *) connection;

- (void) setJoinRooms:(NSArray *) rooms forConnection:(MVChatConnection *) connection;
- (NSMutableArray *) joinRoomsForConnection:(MVChatConnection *) connection;

- (void) setConnectCommands:(NSString *) commands forConnection:(MVChatConnection *) connection;
- (NSString *) connectCommandsForConnection:(MVChatConnection *) connection;

- (void) setIgnoreRules:(NSArray *) ignores forConnection:(MVChatConnection *) connection;
- (NSMutableArray *) ignoreRulesForConnection:(MVChatConnection *) connection;

- (void) addConnection:(MVChatConnection *) connection;
- (void) addConnection:(MVChatConnection *) connection keepBookmark:(BOOL) keep;
- (void) insertConnection:(MVChatConnection *) connection atIndex:(unsigned) index;
- (void) removeConnection:(MVChatConnection *) connection;
- (void) removeConnectionAtIndex:(unsigned) index;
- (void) replaceConnectionAtIndex:(unsigned) index withConnection:(MVChatConnection *) connection;

- (void) handleURL:(NSURL *) url andConnectIfPossible:(BOOL) connect;
@end
