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
	NSUInteger _unreadMessages;
	NSUInteger _unreadHighlightedMessages;
	BOOL _active;
}
- (id) initWithTarget:(id) target;

@property (nonatomic, readonly) MVChatUser *user;

@property (nonatomic, readonly) NSUInteger unreadMessages;
@property (nonatomic, readonly) NSUInteger unreadHighlightedMessages;

- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user asAction:(BOOL) action withIdentifier:(NSString *) identifier andType:(CQChatMessageType) type;
- (void) addMessageToDisplay:(NSData *) message fromUser:(MVChatUser *) user withAttributes:(NSDictionary *) msgAttributes withIdentifier:(NSString *) identifier andType:(CQChatMessageType) type;

- (void) send:(id) sender;
@end
