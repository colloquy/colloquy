@protocol CQChatViewController;

@class CQChatRoomController;
@class CQDirectChatController;
@class CQConsoleController;

@class MVChatUser;
@class MVChatRoom;
@class MVChatConnection;
@class MVDirectChatConnection;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const CQChatOrderingControllerDidChangeOrderingNotification;

@interface CQChatOrderingController : NSObject
+ (CQChatOrderingController *) defaultController;

@property (nonatomic, readonly) NSArray <id <CQChatViewController>> *chatViewControllers;

- (NSUInteger) indexOfViewController:(id <CQChatViewController>) controller;
- (void) addViewController:(id <CQChatViewController>) controller;
- (void) addViewControllers:(NSArray <id <CQChatViewController>> *) controllers;
- (void) removeViewController:(id <CQChatViewController>) controller;

- (BOOL) connectionHasAnyChatRooms:(MVChatConnection *) connection;
- (BOOL) connectionHasAnyPrivateChats:(MVChatConnection *) connection;

- (CQDirectChatController * __nullable) chatViewControllerForDirectChatConnection:(MVDirectChatConnection *) connection ifExists:(BOOL) exists;
- (CQDirectChatController * __nullable) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists userInitiated:(BOOL) initiated;
- (CQDirectChatController * __nullable) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists;

- (CQChatRoomController * __nullable) chatViewControllerForRoom:(MVChatRoom *) room ifExists:(BOOL) exists;
- (NSArray <id <CQChatViewController>> * __nullable) chatViewControllersKindOfClass:(Class) class;
- (NSArray <id <CQChatViewController>> * __nullable) chatViewControllersOfClass:(Class) class;

- (NSArray <id <CQChatViewController>> * __nullable) chatViewControllersForConnection:(MVChatConnection *) connection;
- (CQConsoleController *__nullable) chatViewControllerForConnection:(MVChatConnection *) connection ifExists:(BOOL) exists userInitiated:(BOOL) initiated;
- (CQConsoleController *__nullable) consoleViewControllerForConnection:(MVChatConnection *) connection ifExists:(BOOL) exists;

- (id <CQChatViewController> __nullable) chatViewControllerPreceedingChatController:(id <CQChatViewController>) chatViewController requiringActivity:(BOOL) requiringActivity requiringHighlight:(BOOL) requiringHighlight;
- (id <CQChatViewController> __nullable) chatViewControllerFollowingChatController:(id <CQChatViewController>) chatViewController requiringActivity:(BOOL) requiringActivity requiringHighlight:(BOOL) requiringHighlight;

- (id __nullable) connectionAtIndex:(NSInteger) index;
- (NSUInteger) sectionIndexForConnection:(id) connection;
@end

NS_ASSUME_NONNULL_END
