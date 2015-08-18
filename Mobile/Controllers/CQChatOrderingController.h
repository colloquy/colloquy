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

@interface CQChatOrderingController : NSObject {
	@private
	NSMutableArray *_chatControllers;
}
+ (CQChatOrderingController *) defaultController;

@property (nonatomic, readonly) NSArray *chatViewControllers;

- (NSUInteger) indexOfViewController:(id <CQChatViewController>) controller;
- (void) addViewController:(id <CQChatViewController>) controller;
- (void) addViewControllers:(NSArray *) controllers;
- (void) removeViewController:(id <CQChatViewController>) controller;

- (BOOL) connectionHasAnyChatRooms:(MVChatConnection *) connection;
- (BOOL) connectionHasAnyPrivateChats:(MVChatConnection *) connection;

- (CQDirectChatController *) chatViewControllerForDirectChatConnection:(MVDirectChatConnection *) connection ifExists:(BOOL) exists;
- (CQDirectChatController *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists userInitiated:(BOOL) initiated;
- (CQDirectChatController *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists;

- (CQChatRoomController *) chatViewControllerForRoom:(MVChatRoom *) room ifExists:(BOOL) exists;
- (NSArray *) chatViewControllersKindOfClass:(Class) class;
- (NSArray *) chatViewControllersOfClass:(Class) class;

- (NSArray *) chatViewControllersForConnection:(MVChatConnection *) connection;
- (CQConsoleController *) chatViewControllerForConnection:(MVChatConnection *) connection ifExists:(BOOL) exists userInitiated:(BOOL) initiated;
- (CQConsoleController *) consoleViewControllerForConnection:(MVChatConnection *) connection ifExists:(BOOL) exists;

- (id <CQChatViewController>) chatViewControllerPreceedingChatController:(id <CQChatViewController>) chatViewController requiringActivity:(BOOL) requiringActivity requiringHighlight:(BOOL) requiringHighlight;
- (id <CQChatViewController>) chatViewControllerFollowingChatController:(id <CQChatViewController>) chatViewController requiringActivity:(BOOL) requiringActivity requiringHighlight:(BOOL) requiringHighlight;

- (id) connectionAtIndex:(NSInteger) index;
- (NSUInteger) sectionIndexForConnection:(id) connection;
@end

NS_ASSUME_NONNULL_END
