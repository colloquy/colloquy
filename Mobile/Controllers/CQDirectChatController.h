#import "CQChatController.h"
#import "CQChatInputBar.h"
#import "CQChatTranscriptView.h"

@class CQChatTableCell;
@class CQStyleView;
@class CQChatInputBar;
@class CQChatTranscriptView;
@class MVChatUser;
@class MVChatUserWatchRule;

@interface CQDirectChatController : UIViewController <CQChatViewController, CQChatInputBarDelegate, CQChatTranscriptViewDelegate, UIAlertViewDelegate> {
	IBOutlet CQChatInputBar *chatInputBar;
	IBOutlet CQChatTranscriptView *transcriptView;

	NSMutableArray *_pendingFormerMessages;
	NSMutableArray *_pendingMessages;
	NSMutableArray *_recentMessages;

	id _target;
	NSStringEncoding _encoding;
	MVChatUserWatchRule *_watchRule;

	NSUInteger _unreadMessages;
	NSUInteger _unreadHighlightedMessages;
	BOOL _active;
	BOOL _showingAlert;
	BOOL _allowEditingToEnd;
	BOOL _didSendRecently;
}
- (id) initWithTarget:(id) target;

@property (nonatomic, readonly) MVChatUser *user;

@property (nonatomic, readonly) NSArray *recentMessages;

- (void) addFormerMessages:(NSArray *) messages;

- (void) addMessage:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier andType:(CQChatMessageType) type;
- (void) addMessage:(NSDictionary *) info;
@end
