#import "JVInspectorController.h"

@class MVChatConnection;
@class KAIgnoreRule;

NS_ASSUME_NONNULL_BEGIN

@interface MVConnectionsController : NSWindowController <JVInspectionDelegator, NSToolbarDelegate> {
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

	NSMapTable *_connectionToErrorToAlertMap;
	NSMutableArray<NSMutableDictionary<NSString*,id>*> *_bookmarks;
	NSMutableArray *_joinRooms;
	MVChatConnection *_passConnection;
	MVChatConnection *_certificateConnection;
	NSDictionary *_publicKeyDictionary;
	NSMutableSet *_publicKeyRequestQueue;
}
+ (void) refreshFavoritesMenu;

#if __has_feature(objc_class_property)
@property (readonly, retain, class) MVConnectionsController *defaultController;

@property (readonly, retain, class) NSMenu *favoritesMenu;
#else
+ (MVConnectionsController *) defaultController;

+ (NSMenu *) favoritesMenu;
#endif

- (IBAction) showConnectionManager:(nullable id) sender;
- (IBAction) hideConnectionManager:(nullable id) sender;

- (void) newConnectionWithJoinRooms:(nullable NSArray<NSString*> *) rooms;

- (IBAction) newConnection:(nullable id) sender;
- (IBAction) changeNewConnectionProtocol:(nullable id) sender;
- (IBAction) toggleNewConnectionDetails:(nullable id) sender;
- (IBAction) addRoom:(nullable id) sender;
- (IBAction) removeRoom:(nullable id) sender;
- (IBAction) openNetworkPreferences:(nullable id) sender;
- (IBAction) connectNewConnection:(nullable id) sender;

- (IBAction) messageUser:(nullable id) sender;

- (IBAction) sendPassword:(nullable id) sender;

- (IBAction) sendCertificatePassword:(nullable id) sender;

- (IBAction) verifiedPublicKey:(nullable id) sender;

- (IBAction) userSelectionSelected:(nullable id) sender;

@property (readonly, copy) NSArray<MVChatConnection*> *connections;
@property (readonly, copy) NSArray<MVChatConnection*> *connectedConnections;
- (nullable MVChatConnection *) connectionForServerAddress:(NSString *) address;
- (NSArray<MVChatConnection*> *) connectionsForServerAddress:(NSString *) address;
- (BOOL) managesConnection:(MVChatConnection *) connection;

- (void) setAutoConnect:(BOOL) autoConnect forConnection:(MVChatConnection *) connection;
- (BOOL) autoConnectForConnection:(MVChatConnection *) connection;

- (void) setShowConsoleOnConnect:(BOOL) autoConsole forConnection:(MVChatConnection *) connection;
- (BOOL) showConsoleOnConnectForConnection:(MVChatConnection *) connection;

- (void) setJoinRooms:(NSArray<NSString*> *) rooms forConnection:(MVChatConnection *) connection;
- (NSMutableArray<NSString*> *) joinRoomsForConnection:(MVChatConnection *) connection;

- (void) setConnectCommands:(NSString *) commands forConnection:(MVChatConnection *) connection;
- (NSString *) connectCommandsForConnection:(MVChatConnection *) connection;

- (void) setIgnoreRules:(NSArray<KAIgnoreRule*> *) ignores forConnection:(MVChatConnection *) connection;
- (NSMutableArray<KAIgnoreRule*> *) ignoreRulesForConnection:(MVChatConnection *) connection;

- (void) addConnection:(MVChatConnection *) connection;
- (void) addConnection:(MVChatConnection *) connection keepBookmark:(BOOL) keep;
- (void) insertConnection:(MVChatConnection *) connection atIndex:(NSUInteger) index;
- (void) removeConnection:(MVChatConnection *) connection;
- (void) removeConnectionAtIndex:(NSUInteger) index;
- (void) replaceConnectionAtIndex:(NSUInteger) index withConnection:(MVChatConnection *) connection;

- (void) handleURL:(NSURL *) url andConnectIfPossible:(BOOL) connect;
@end

NS_ASSUME_NONNULL_END
