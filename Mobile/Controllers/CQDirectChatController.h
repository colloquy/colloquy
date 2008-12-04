#import "CQChatController.h"
#import "CQChatInputBar.h"
#import "CQChatTranscriptView.h"

@class CQChatTableCell;
@class CQStyleView;
@class CQChatInputBar;
@class CQChatTranscriptView;
@class MVChatUser;

@interface CQDirectChatController : UIViewController <CQChatViewController, CQChatInputBarDelegate, CQChatTranscriptViewDelegate> {
	IBOutlet CQChatInputBar *chatInputBar;
	IBOutlet CQChatTranscriptView *transcriptView;

	id _target;
	NSUInteger _unreadMessages;
	NSUInteger _unreadHighlightedMessages;
	BOOL _active;
	BOOL _allowEditingToEnd;
	BOOL _didSendRecently;
}
- (id) initWithTarget:(id) target;

@property (nonatomic, readonly) MVChatUser *user;

@property (nonatomic, readonly) NSUInteger unreadMessages;
@property (nonatomic, readonly) NSUInteger unreadHighlightedMessages;

- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier andType:(CQChatMessageType) type;
- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user withAttributes:(NSDictionary *) msgAttributes withIdentifier:(NSString *) identifier andType:(CQChatMessageType) type;
@end
