#import <Foundation/Foundation.h>

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>

@class CQBouncerConnection;
@class CQBouncerSettings;
@class CQConnectionsNavigationController;
@class CQIgnoreRulesController;

NS_ASSUME_NONNULL_BEGIN

extern NSString *CQConnectionsControllerAddedConnectionNotification;
extern NSString *CQConnectionsControllerChangedConnectionNotification;
extern NSString *CQConnectionsControllerRemovedConnectionNotification;
extern NSString *CQConnectionsControllerMovedConnectionNotification;
extern NSString *CQConnectionsControllerAddedBouncerSettingsNotification;
extern NSString *CQConnectionsControllerRemovedBouncerSettingsNotification;

@interface CQConnectionsController : NSObject
+ (CQConnectionsController *) defaultController;

@property (nonatomic, readonly) CQConnectionsNavigationController *connectionsNavigationController;

@property (nonatomic, readonly) NSSet *connections;
@property (nonatomic, readonly) NSSet *connectedConnections;

@property (nonatomic, readonly) NSArray <MVChatConnection *> *directConnections;
@property (nonatomic, readonly) NSArray <CQBouncerSettings *> *bouncers;

@property (nonatomic) BOOL shouldLogRawMessagesToConsole;

- (void) openAllConnections;
- (void) closeAllConnections;

- (void) saveConnections;
- (void) saveConnectionPasswordsToKeychain;

- (BOOL) handleOpenURL:(NSURL *) url;

- (void) showNewConnectionPromptFromPoint:(CGPoint) point;
- (void) showBouncerCreationView:(__nullable id) sender;
- (void) showConnectionCreationView:(__nullable id) sender;
- (void) showConnectionCreationViewForURL:(NSURL *__nullable) url;

- (MVChatConnection *__nullable) connectionForUniqueIdentifier:(NSString *) identifier;
- (MVChatConnection *__nullable) connectionForServerAddress:(NSString *) address;
- (NSArray <MVChatConnection *> *) connectionsForServerAddress:(NSString *) address;
- (BOOL) managesConnection:(MVChatConnection *) connection;

- (void) addConnection:(MVChatConnection *) connection;
- (void) insertConnection:(MVChatConnection *) connection atIndex:(NSUInteger) index;

- (void) moveConnectionAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex;

- (void) removeConnection:(MVChatConnection *) connection;
- (void) removeConnectionAtIndex:(NSUInteger) index;

- (void) moveConnectionAtIndex:(NSUInteger) oldIndex toIndex:(NSUInteger) newIndex forBouncerIdentifier:(NSString *) identifier;

- (CQBouncerSettings *__nullable) bouncerSettingsForIdentifier:(NSString *) identifier;
- (NSArray <MVChatConnection *> *) bouncerChatConnectionsForIdentifier:(NSString *) identifier;

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
@property (nonatomic, copy) NSArray <NSString *> *automaticJoinedRooms;
@property (nonatomic, copy) NSArray <NSString *> *automaticCommands;
@property (nonatomic) BOOL automaticallyConnect;
@property (nonatomic) BOOL consoleOnLaunch;
@property (nonatomic) BOOL multitaskingSupported;
@property (nonatomic) BOOL pushNotifications;
@property (nonatomic, readonly, getter = isDirectConnection) BOOL directConnection;
@property (nonatomic, getter = isTemporaryDirectConnection) BOOL temporaryDirectConnection;
@property (nonatomic, copy) NSString *bouncerIdentifier;
@property (nonatomic, copy) CQBouncerSettings *bouncerSettings;
@property (nonatomic, readonly) CQIgnoreRulesController *ignoreController;

- (void) savePasswordsToKeychain;
- (void) loadPasswordsFromKeychain;

- (void) connectDirectly;
- (void) connectAppropriately;

- (void) sendPushNotificationCommands;
@end

NS_ASSUME_NONNULL_END
