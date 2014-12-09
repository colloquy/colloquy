#import "CQChatController.h"
#import "CQChatInputBar.h"
#import "CQUIChatTranscriptView.h"
#import "CQWKChatTranscriptView.h"
#import "CQImportantChatMessageViewController.h"
#import "CQViewController.h"

#define ReconnectAlertTag 1
#define RejoinRoomAlertTag 2

#define ToolbarTitleButtonTag 1
#define ToolbarLastButtonTag 2

@class CQChatTableCell;
@class CQChatInputBar;
@class CQUIChatTranscriptView;
@class CQWKChatTranscriptView;
@class MVChatUser;
@class MVChatUserWatchRule;

extern NSString *CQChatViewControllerRecentMessagesUpdatedNotification;
extern NSString *CQChatViewControllerUnreadMessagesUpdatedNotification;

typedef NS_ENUM(NSInteger, CQDirectChatBatchType) {
	CQBatchTypeUnknown = -1,
	CQBatchTypeBuffer = 0
};


@interface CQDirectChatController : CQViewController <CQChatViewController, CQChatInputBarDelegate, CQChatTranscriptViewDelegate, CQImportantChatMessageDelegate, UIAlertViewDelegate, UIActionSheetDelegate> {
	@protected
	IBOutlet CQChatInputBar *chatInputBar;
	IBOutlet UIView <CQChatTranscriptView> *transcriptView;
	IBOutlet UIView *containerView;

	NSMutableArray *_pendingPreviousSessionComponents;
	NSMutableArray *_pendingComponents;
	NSMutableArray *_recentMessages;
	NSMutableArray *_sentMessages;

	id _target;
	NSStringEncoding _encoding;
	MVChatUserWatchRule *_watchRule;

	NSUInteger _unreadMessages;
	NSUInteger _unreadHighlightedMessages;
	BOOL _active;
	BOOL _showingAlert;
	BOOL _allowEditingToEnd;
	BOOL _didSendRecently;
	BOOL _revealKeyboard;
	BOOL _showingKeyboard;
	BOOL _showDeviceTokenWhenRegistered;

	NSTimeInterval _lastTimestampTime;
	NSTimeInterval _lastMessageTime;

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0
	BOOL _isShowingCompletionsBeforeRotation;
#endif

	NSInteger _batchType;
	NSMutableDictionary *_batchStorage;
}
- (id) initWithTarget:(id) target;

@property (nonatomic, readonly) MVChatUser *user;

@property (nonatomic, readonly) NSArray *recentMessages;

- (void) clearController;

- (void) markScrollback;

- (void) showRecentlySentMessages;

- (void) sendMessage:(NSString *) message asAction:(BOOL) action;

- (void) addMessage:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier;
- (void) addMessage:(NSDictionary *) message;

- (void) addEventMessage:(NSString *) message withIdentifier:(NSString *) identifier;
- (void) addEventMessage:(NSString *) message withIdentifier:(NSString *) identifier announceWithVoiceOver:(BOOL) announce;

- (void) addEventMessageAsHTML:(NSString *) message withIdentifier:(NSString *) identifier;
- (void) addEventMessageAsHTML:(NSString *) message withIdentifier:(NSString *) identifier announceWithVoiceOver:(BOOL) announce;
@end
