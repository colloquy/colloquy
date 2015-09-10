#import <ChatCore/MVIRCChatRoom.h>

@class CQChatNavigationController;
@class CQChatPresentationController;
@class MVChatConnection;
@class MVChatUser;
@protocol CQChatViewController;

#if ENABLE(FILE_TRANSFERS)
@class CQFileTransferController;
@class MVFileTransfer;
#endif

NS_ASSUME_NONNULL_BEGIN

extern NSString *CQChatControllerAddedChatViewControllerNotification;
extern NSString *CQChatControllerRemovedChatViewControllerNotification;
extern NSString *CQChatControllerChangedTotalImportantUnreadCountNotification;

@interface CQChatController : NSObject
+ (CQChatController *) defaultController;

@property (nonatomic, readonly) id <CQChatViewController> visibleChatController;
@property (nonatomic, readonly) CQChatNavigationController *chatNavigationController;
@property (nonatomic, readonly) CQChatPresentationController *chatPresentationController;

@property (nonatomic, readonly) MVChatConnection *nextRoomConnection;

@property (nonatomic) NSInteger totalImportantUnreadCount;
@property (nonatomic, readonly) NSInteger totalUnreadCount;
- (void) resetTotalUnreadCount;

- (NSDictionary *) persistentStateForConnection:(MVChatConnection *) connection;
- (void) restorePersistentState:(NSDictionary *) state forConnection:(MVChatConnection *) connection;

- (void) showNewChatActionSheetForConnection:(MVChatConnection *) connection fromPoint:(CGPoint) point;

- (void) showChatControllerWhenAvailableForRoomNamed:(NSString *) room andConnection:(MVChatConnection *) connection;
- (void) showChatControllerForUserNicknamed:(NSString *) nickname andConnection:(MVChatConnection *) connection;
- (void) showChatController:(id <CQChatViewController>) controller animated:(BOOL) animated;

- (void) setFirstChatController;
- (void) showPendingChatControllerAnimated:(BOOL) animated;
@property (readonly) BOOL hasPendingChatController;

#if ENABLE(FILE_TRANSFERS)
- (void) showFilePickerWithUser:(MVChatUser *) user;
#endif

- (void) joinSupportRoom;

- (void) showConsoleForConnection:(MVChatConnection *) connection;

#if ENABLE(FILE_TRANSFERS)
- (CQFileTransferController *) chatViewControllerForFileTransfer:(MVFileTransfer *) transfer ifExists:(BOOL) exists;
#endif

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
- (instancetype) initWithPersistentState:(NSDictionary *) state usingConnection:(MVChatConnection *) connection;
- (void) restorePersistentState:(NSDictionary *) state usingConnection:(MVChatConnection *) connection;
- (void) close;

- (void) dismissPopoversAnimated:(BOOL) animated;

@property (nonatomic, readonly) NSDictionary *persistentState;
@property (nonatomic, readonly) NSUInteger unreadCount;
@property (nonatomic, readonly) NSUInteger importantUnreadCount;
- (void) markAsRead;

@property (nonatomic, readonly) UIActionSheet *actionSheet;

#if SYSTEM(IOS)
@property (nonatomic, readonly) UIScrollView *scrollView;
#endif
@end

@interface MVIRCChatRoom (CQChatControllerAdditions)
@property (nonatomic, readonly) NSString *displayName;
@end

NS_ASSUME_NONNULL_END
