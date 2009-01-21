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
	@protected
	IBOutlet CQChatInputBar *chatInputBar;
	IBOutlet CQChatTranscriptView *transcriptView;

	NSMutableArray *_pendingPreviousSessionComponents;
	NSMutableArray *_pendingComponents;
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
	BOOL _initialView;
	BOOL _revealKeyboard;
}
- (id) initWithTarget:(id) target;

@property (nonatomic, readonly) MVChatUser *user;

@property (nonatomic, readonly) NSArray *recentMessages;

- (void) addMessage:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier;
- (void) addMessage:(NSDictionary *) message;

- (void) addEventMessage:(NSString *) message withIdentifier:(NSString *) identifier;
- (void) addEventMessageAsHTML:(NSString *) message withIdentifier:(NSString *) identifier;
@end
