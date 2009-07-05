#import <ChatCore/MVChatConnection.h>

#import "CQBouncerConnection.h"

@class CQBouncerSettings;
@class CQChatRoomController;
@class CQConnectionEditViewController;
@class CQConnectionsViewController;
@class CQDirectChatController;
@class MVChatConnection;
@class MVChatRoom;
@class MVChatUser;
@class MVDirectChatConnection;

@interface CQConnectionsController : UINavigationController <UINavigationControllerDelegate, UIActionSheetDelegate, CQBouncerConnectionDelegate> {
	@protected
	NSMutableSet *_connections;
	NSMutableArray *_directConnections;
	NSMutableArray *_bouncers;
	NSMutableSet *_bouncerConnections;
	NSMutableDictionary *_bouncerChatConnections;
	BOOL _wasEditing;
	BOOL _loadedConnections;
	NSUInteger _connectingCount;
	NSUInteger _connectedCount;

	CQConnectionsViewController *_connectionsViewController;
}
+ (CQConnectionsController *) defaultController;

@property (nonatomic, readonly) NSSet *connections;
@property (nonatomic, readonly) NSSet *connectedConnections;

@property (nonatomic, readonly) NSArray *directConnections;
@property (nonatomic, readonly) NSArray *bouncers;

- (void) saveConnections;

- (BOOL) handleOpenURL:(NSURL *) url;

- (void) showCreationOptionSheet;
- (void) showModalNewBouncerView;
- (void) showModalNewConnectionView;
- (void) showModalNewConnectionViewForURL:(NSURL *) url;

- (void) editConnection:(MVChatConnection *) connection;
- (void) editBouncer:(CQBouncerSettings *) settings;

- (MVChatConnection *) connectionForUniqueIdentifier:(NSString *) identifier;
- (MVChatConnection *) connectionForServerAddress:(NSString *) address;
- (NSArray *) connectionsForServerAddress:(NSString *) address;
- (BOOL) managesConnection:(MVChatConnection *) connection;

- (void) addConnection:(MVChatConnection *) connection;
- (void) insertConnection:(MVChatConnection *) connection atIndex:(NSUInteger) index;

- (void) moveConnectionAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex;

- (void) removeConnection:(MVChatConnection *) connection;
- (void) removeConnectionAtIndex:(NSUInteger) index;

- (void) replaceConnection:(MVChatConnection *) previousConnection withConnection:(MVChatConnection *) newConnection;
- (void) replaceConnectionAtIndex:(NSUInteger) index withConnection:(MVChatConnection *) connection;

- (void) moveConnectionAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex forBouncerIdentifier:(NSString *) identifier;

- (CQBouncerSettings *) bouncerSettingsForIdentifier:(NSString *) identifier;
- (NSArray *) bouncerChatConnectionsForIdentifier:(NSString *) identifier;

- (void) refreshBouncerConnectionsWithBouncerSettings:(CQBouncerSettings *) settings;

- (void) addBouncerSettings:(CQBouncerSettings *) settings;
- (void) removeBouncerSettings:(CQBouncerSettings *) settings;
- (void) removeBouncerSettingsAtIndex:(NSUInteger) index;
@end

@interface MVChatConnection (CQConnectionsControllerAdditions)
+ (NSString *) defaultNickname;
+ (NSString *) defaultUsernameWithNickname:(NSString *) nickname;
+ (NSString *) defaultRealName;
+ (NSString *) defaultQuitMessage;
+ (NSStringEncoding) defaultEncoding;

@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSArray *automaticJoinedRooms;
@property (nonatomic, copy) NSArray *automaticCommands;
@property (nonatomic) BOOL automaticallyConnect;
@property (nonatomic) BOOL pushNotifications;
@property (nonatomic, readonly, getter = isDirectConnection) BOOL directConnection;
@property (nonatomic, copy) NSString *bouncerIdentifier;
@property (nonatomic, copy) CQBouncerSettings *bouncerSettings;

- (void) savePasswordsToKeychain;
- (void) loadPasswordsFromKeychain;

- (void) sendPushNotificationCommands;
@end
