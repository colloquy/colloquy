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

- (instancetype) initWithNibName:(NSString *) nibNameOrNil bundle:(NSBundle *) nibBundleOrNil NS_UNAVAILABLE;
- (instancetype) initWithStyle:(UITableViewStyle) style NS_UNAVAILABLE;
- (instancetype) initWithCoder:(NSCoder *) aDecoder NS_UNAVAILABLE;

- (instancetype) initWithMessages:(NSArray *) messages delegate:(id <CQImportantChatMessageDelegate>) delegate NS_DESIGNATED_INITIALIZER;
@end
