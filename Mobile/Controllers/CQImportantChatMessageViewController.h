#import "CQTableViewController.h"

#import "MVChatString.h"

@class CQImportantChatMessageViewController;

@protocol CQImportantChatMessageDelegate <NSObject>
@optional
- (void) importantChatMessageViewController:(CQImportantChatMessageViewController *) importantChatMessageViewController didSelectMessage:(MVChatString *) message isAction:(BOOL) isAction;
@end

@interface CQImportantChatMessageViewController : CQTableViewController {
@private
	NSArray *_messages;
	id <CQImportantChatMessageDelegate> _delegate;
}

- (id) initWithMessages:(NSArray *) messages delegate:(id <CQImportantChatMessageDelegate>) delegate;
@end
