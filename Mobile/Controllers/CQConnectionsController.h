#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>

#import "CQBouncerConnection.h"

@class CQBouncerSettings;
@class CQChatRoomController;
@class CQConnectionEditViewController;
@class CQConnectionsNavigationController;
@class CQConnectionsViewController;
@class CQDirectChatController;
@class MVChatConnection;
@class MVChatRoom;
@class MVChatUser;
@class MVDirectChatConnection;

extern NSString *CQConnectionsControllerAddedConnectionNotification;
extern NSString *CQConnectionsControllerChangedConnectionNotification;
extern NSString *CQConnectionsControllerRemovedConnectionNotification;
extern NSString *CQConnectionsControllerMovedConnectionNotification;
extern NSString *CQConnectionsControllerAddedBouncerSettingsNotification;
extern NSString *CQConnectionsControllerRemovedBouncerSettingsNotification;

@interface CQConnectionsController : NSObject <UIActionSheetDelegate, UIAlertViewDelegate, CQBouncerConnectionDelegate> {
	@protected
	CQConnectionsNavigationController *_connectionsNavigationController;
	NSMutableSet *_connections;
	NSMutableArray *_directConnections;
	NSMutableArray *_bouncers;
	NSMutableSet *_bouncerConnections;
	NSMutableDictionary *_bouncerChatConnections;
	BOOL _loadedConnections;
	NSUInteger _connectingCount;
	NSUInteger _connectedCount;
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_4_0
	UILocalNotification *_timeRemainingLocalNotifiction;
	UIBackgroundTaskIdentifier _backgroundTask;
	NSTimeInterval _allowedBackgroundTime;
	NSMutableSet *_automaticallySetConnectionAwayStatus;
#endif
}
+ (CQConnectionsController *) defaultController;

@property (nonatomic, readonly) CQConnectionsNavigationController *connectionsNavigationController;

@property (nonatomic, readonly) NSSet *connections;
@property (nonatomic, readonly) NSSet *connectedConnections;

@property (nonatomic, readonly) NSArray *directConnections;
@property (nonatomic, readonly) NSArray *bouncers;

- (void) saveConnections;
- (void) saveConnectionPasswordsToKeychain;

- (BOOL) handleOpenURL:(NSURL *) url;

- (void) showNewConnectionPrompt:(id) sender;
- (void) showBouncerCreationView:(id) sender;
- (void) showConnectionCreationView:(id) sender;
- (void) showConnectionCreationViewForURL:(NSURL *) url;

- (MVChatConnection *) connectionForUniqueIdentifier:(NSString *) identifier;
- (MVChatConnection *) connectionForServerAddress:(NSString *) address;
- (NSArray *) connectionsForServerAddress:(NSString *) address;
- (BOOL) managesConnection:(MVChatConnection *) connection;

- (void) addConnection:(MVChatConnection *) connection;
- (void) insertConnection:(MVChatConnection *) connection atIndex:(NSUInteger) index;

- (void) moveConnectionAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex;

- (void) removeConnection:(MVChatConnection *) connection;
- (void) removeConnectionAtIndex:(NSUInteger) index;

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
@property (nonatomic) BOOL multitaskingSupported;
@property (nonatomic) BOOL pushNotifications;
@property (nonatomic, readonly, getter = isDirectConnection) BOOL directConnection;
@property (nonatomic, getter = isTemporaryDirectConnection) BOOL temporaryDirectConnection;
@property (nonatomic, copy) NSString *bouncerIdentifier;
@property (nonatomic, copy) CQBouncerSettings *bouncerSettings;

- (void) savePasswordsToKeychain;
- (void) loadPasswordsFromKeychain;

- (void) connectDirectly;
- (void) connectAppropriately;

- (void) sendPushNotificationCommands;
@end
