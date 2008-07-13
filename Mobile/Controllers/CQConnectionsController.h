#import "CQColloquyApplication.h"

@class CQChatRoomController;
@class CQConnectionsViewController;
@class CQConnectionEditViewController;
@class CQDirectChatController;
@class MVChatConnection;
@class MVChatRoom;
@class MVChatUser;
@class MVDirectChatConnection;

@interface CQConnectionsController : UINavigationController {
	@private
	NSMutableArray *_connections;

	IBOutlet CQConnectionsViewController *connectionsViewController;
	IBOutlet CQConnectionEditViewController *editViewController;
}
+ (CQConnectionsController *) defaultController;

@property (nonatomic, readonly) NSArray *connections;
@property (nonatomic, readonly) NSArray *connectedConnections;

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
