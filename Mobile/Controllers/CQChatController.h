#import <ChatCore/MVChatRoom.h>

@class CQChatRoomController;
@class CQChatListViewController;
@class CQDirectChatController;
@class MVChatConnection;
@class MVChatUser;
@class MVDirectChatConnection;
@protocol CQChatViewController;

@interface CQChatController : UINavigationController <UINavigationControllerDelegate, UIActionSheetDelegate, UIAlertViewDelegate> {
	@private
	NSMutableArray *_chatControllers;
	CQChatListViewController *_chatListViewController;
	id <CQChatViewController> _nextController;
	NSString *_nextRoomName;
	MVChatConnection *_nextRoomConnection;
	NSInteger _totalImportantUnreadCount;
	BOOL _active;
}
+ (CQChatController *) defaultController;

@property (nonatomic, readonly) NSArray *chatViewControllers;

@property (nonatomic) NSInteger totalImportantUnreadCount;

- (NSDictionary *) persistentStateForConnection:(MVChatConnection *) connection;
- (void) restorePersistentState:(NSDictionary *) state forConnection:(MVChatConnection *) connection;

- (void) showNewChatActionSheet;
- (void) showChatControllerWhenAvailableForRoomNamed:(NSString *) room andConnection:(MVChatConnection *) connection;
- (void) showChatController:(id <CQChatViewController>) controller animated:(BOOL) animated;

- (NSArray *) chatViewControllersForConnection:(MVChatConnection *) connection;
- (NSArray *) chatViewControllersOfClass:(Class) class;
- (NSArray *) chatViewControllersKindOfClass:(Class) class;

- (CQChatRoomController *) chatViewControllerForRoom:(MVChatRoom *) room ifExists:(BOOL) exists;
- (CQDirectChatController *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists;
- (CQDirectChatController *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists userInitiated:(BOOL) requested;
- (CQDirectChatController *) chatViewControllerForDirectChatConnection:(MVDirectChatConnection *) connection ifExists:(BOOL) exists;

- (void) closeViewController:(id <CQChatViewController>) controller;
@end

@protocol CQChatViewController <NSObject>
@property (nonatomic, readonly) MVChatConnection *connection;
@property (nonatomic, readonly) id target;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) UIImage *icon;
@property (nonatomic, readonly) BOOL available;
@property (nonatomic, readonly) NSStringEncoding encoding;

@optional
- (id) initWithPersistentState:(NSDictionary *) state usingConnection:(MVChatConnection *) connection;
- (void) close;

@property (nonatomic, readonly) NSDictionary *persistentState;
@property (nonatomic, readonly) NSUInteger unreadCount;
@property (nonatomic, readonly) NSUInteger importantUnreadCount;
@end

@interface MVChatRoom (CQChatControllerAdditions)
@property (nonatomic, readonly) NSString *displayName;
@end
