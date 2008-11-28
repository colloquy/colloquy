#import <ChatCore/MVChatConnection.h>

@class CQChatRoomController;
@class CQConnectionsViewController;
@class CQConnectionEditViewController;
@class CQDirectChatController;
@class MVChatConnection;
@class MVChatRoom;
@class MVChatUser;
@class MVDirectChatConnection;

@interface CQConnectionsController : UINavigationController <UINavigationControllerDelegate> {
	@private
	NSMutableArray *_connections;
	BOOL _wasEditingConnection;

	CQConnectionsViewController *_connectionsViewController;
}
+ (CQConnectionsController *) defaultController;

@property (nonatomic, readonly) NSArray *connections;
@property (nonatomic, readonly) NSArray *connectedConnections;

- (void) saveConnections;

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
@end

@interface MVChatConnection (CQConnectionsControllerAdditions)
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSArray *automaticJoinedRooms;
@property (nonatomic, copy) NSArray *automaticCommands;
@property (nonatomic) BOOL automaticallyConnect;
@end
