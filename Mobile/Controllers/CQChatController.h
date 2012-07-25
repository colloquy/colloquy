#import <ChatCore/MVIRCChatRoom.h>

@class CQChatListViewController;
@class CQChatNavigationController;
@class CQChatPresentationController;
@class CQChatRoomController;
@class CQDirectChatController;
@class MVChatConnection;
@class MVChatUser;
@class MVDirectChatConnection;
@protocol CQChatViewController;

@class CQFileTransferController;
@class MVFileTransfer;

extern NSString *CQChatControllerAddedChatViewControllerNotification;
extern NSString *CQChatControllerRemovedChatViewControllerNotification;
extern NSString *CQChatControllerChangedTotalImportantUnreadCountNotification;

@interface CQChatController : NSObject <UIActionSheetDelegate, UIAlertViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate> {
	@protected
	NSMutableArray *_chatControllers;
	CQChatNavigationController *_chatNavigationController;
	CQChatPresentationController *_chatPresentationController;
	id <CQChatViewController> _nextController;
	id <CQChatViewController> _visibleChatController;
	MVChatConnection *_nextRoomConnection;
	NSInteger _totalImportantUnreadCount;
	MVChatUser *_fileUser;
}
+ (CQChatController *) defaultController;

@property (nonatomic, readonly) id <CQChatViewController> visibleChatController;
@property (nonatomic, readonly) CQChatNavigationController *chatNavigationController;
@property (nonatomic, readonly) CQChatPresentationController *chatPresentationController;

@property (nonatomic, readonly) NSArray *chatViewControllers;

@property (nonatomic) NSInteger totalImportantUnreadCount;

- (NSDictionary *) persistentStateForConnection:(MVChatConnection *) connection;
- (void) restorePersistentState:(NSDictionary *) state forConnection:(MVChatConnection *) connection;

- (void) showNewChatActionSheet:(id) sender;

- (void) showChatControllerWhenAvailableForRoomNamed:(NSString *) room andConnection:(MVChatConnection *) connection;
- (void) showChatControllerForUserNicknamed:(NSString *) nickname andConnection:(MVChatConnection *) connection;
- (void) showChatController:(id <CQChatViewController>) controller animated:(BOOL) animated;

- (void) showPendingChatControllerAnimated:(BOOL) animated;
- (BOOL) hasPendingChatController;

- (void) showFilePickerWithUser:(MVChatUser *) user;

- (void) joinSupportRoom;

- (NSArray *) chatViewControllersForConnection:(MVChatConnection *) connection;
- (NSArray *) chatViewControllersOfClass:(Class) class;
- (NSArray *) chatViewControllersKindOfClass:(Class) class;

- (CQChatRoomController *) chatViewControllerForRoom:(MVChatRoom *) room ifExists:(BOOL) exists;
- (CQDirectChatController *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists;
- (CQDirectChatController *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists userInitiated:(BOOL) requested;
- (CQDirectChatController *) chatViewControllerForDirectChatConnection:(MVDirectChatConnection *) connection ifExists:(BOOL) exists;

- (BOOL) connectionHasAnyChatRooms:(MVChatConnection *) connection;
- (BOOL) connectionHasAnyPrivateChats:(MVChatConnection *) connection;

- (CQFileTransferController *) chatViewControllerForFileTransfer:(MVFileTransfer *) transfer ifExists:(BOOL) exists;

- (void) visibleChatControllerWasHidden;

- (void) closeViewController:(id) controller;
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
- (void) restorePersistentState:(NSDictionary *) state usingConnection:(MVChatConnection *) connection;
- (void) close;

- (void) dismissPopoversAnimated:(BOOL) animated;

@property (nonatomic, readonly) NSDictionary *persistentState;
@property (nonatomic, readonly) NSUInteger unreadCount;
@property (nonatomic, readonly) NSUInteger importantUnreadCount;

@property (nonatomic, readonly) UIActionSheet *actionSheet;
@end

@interface MVIRCChatRoom (CQChatControllerAdditions)
@property (nonatomic, readonly) NSString *displayName;
@end
