#import "CQChatController.h"
#import "CQChatInputBar.h"

@class CQChatTableCell;
@class CQStyleView;
@class CQChatInputBar;
@class MVChatUser;

typedef enum _CQChatMessageType {
	CQChatMessageNormalType = 'noMt',
	CQChatMessageNoticeType = 'nTMt'
} CQChatMessageType;

@interface CQDirectChatController : UIViewController <CQChatViewController, CQChatInputBarDelegate> {
	IBOutlet CQChatInputBar *chatInputBar;
	IBOutlet UIWebView *transcriptView;

	id _target;
	NSUInteger _unreadMessages;
	NSUInteger _unreadHighlightedMessages;
	BOOL _active;
	BOOL _viewDisappearing;
}
- (id) initWithTarget:(id) target;

@property (nonatomic, readonly) MVChatUser *user;

@property (nonatomic, readonly) NSUInteger unreadMessages;
@property (nonatomic, readonly) NSUInteger unreadHighlightedMessages;

- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier andType:(CQChatMessageType) type;
- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user withAttributes:(NSDictionary *) msgAttributes withIdentifier:(NSString *) identifier andType:(CQChatMessageType) type;

- (void) send:(id) sender;
@end
