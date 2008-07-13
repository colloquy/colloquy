#import "CQChatController.h"

@class CQChatTableCell;
@class CQStyleView;
@class MVChatUser;

typedef enum _CQChatMessageType {
	CQChatMessageNormalType = 'noMt',
	CQChatMessageNoticeType = 'nTMt'
} CQChatMessageType;

@interface CQDirectChatController : UIViewController <CQChatViewController> {
	id _target;
//	CQStyleView *_transcriptView;
	UITextField *_inputField;
	UIView *_inputBarView;
	BOOL _unreadMessages;
	BOOL _unreadHighlightedMessages;
	BOOL _reallyResignInputFirstResponder;
	BOOL _keyboardVisible;
	BOOL _hiding;
	BOOL _active;
}
- (id) initWithTarget:(id) target;

@property (nonatomic, readonly) MVChatUser *user;

@property (nonatomic, readonly) UIImage *icon;

@property (nonatomic, readonly) NSUInteger unreadMessages;
@property (nonatomic, readonly) NSUInteger unreadHighlightedMessages;

// - (void) setKeyboardVisible:(BOOL) visible animate:(BOOL) animate;

- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier andType:(CQChatMessageType) type;
- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user withAttributes:(NSDictionary *) msgAttributes withIdentifier:(NSString *) identifier andType:(CQChatMessageType) type;

- (void) send:(id) sender;
@end
