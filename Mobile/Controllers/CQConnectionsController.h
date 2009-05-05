#import <ChatCore/MVChatConnection.h>

@class CQBouncerSettings;
@class CQChatRoomController;
@class CQConnectionEditViewController;
@class CQConnectionsViewController;
@class CQDirectChatController;
@class MVChatConnection;
@class MVChatRoom;
@class MVChatUser;
@class MVDirectChatConnection;

@interface CQConnectionsController : UINavigationController <UINavigationControllerDelegate> {
	@protected
	NSMutableArray *_connections;
	NSMutableArray *_bouncers;
	BOOL _wasEditingConnection;
	NSUInteger _connectingCount;
	NSUInteger _connectedCount;

	CQConnectionsViewController *_connectionsViewController;
}
+ (CQConnectionsController *) defaultController;

@property (nonatomic, readonly) NSArray *connections;
@property (nonatomic, readonly) NSArray *connectedConnections;
@property (nonatomic, readonly) NSArray *bouncers;

- (void) saveConnections;

- (BOOL) handleOpenURL:(NSURL *) url;

- (void) showModalNewConnectionView;
- (void) showModalNewConnectionViewForURL:(NSURL *) url;
- (void) editConnection:(MVChatConnection *) connection;

- (MVChatConnection *) connectionForServerAddress:(NSString *) address;
- (NSArray *) connectionsForServerAddress:(NSString *) address;
- (BOOL) managesConnection:(MVChatConnection *) connection;

- (void) addConnection:(MVChatConnection *) connection;
- (void) insertConnection:(MVChatConnection *) connection atIndex:(NSUInteger) index;

- (void) moveConnection:(MVChatConnection *) connection toIndex:(NSUInteger) newIndex;
- (void) moveConnectionAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex;

- (void) removeConnection:(MVChatConnection *) connection;
- (void) removeConnectionAtIndex:(NSUInteger) index;

- (void) replaceConnection:(MVChatConnection *) previousConnection withConnection:(MVChatConnection *) newConnection;
- (void) replaceConnectionAtIndex:(NSUInteger) index withConnection:(MVChatConnection *) connection;

- (CQBouncerSettings *) bouncerSettingsForIdentifier:(NSString *) identifier;

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
@property (nonatomic, copy) NSString *bouncerIdentifier;
@property (nonatomic, copy) CQBouncerSettings *bouncerSettings;
@end
