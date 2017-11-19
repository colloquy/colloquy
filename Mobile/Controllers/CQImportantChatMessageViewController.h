#import "MVChatString.h"

@class CQImportantChatMessageViewController;

NS_ASSUME_NONNULL_BEGIN

@protocol CQImportantChatMessageDelegate <NSObject>
@optional
- (void) importantChatMessageViewController:(CQImportantChatMessageViewController *) importantChatMessageViewController didSelectMessage:(MVChatString *) message isAction:(BOOL) isAction;
@end

@interface CQImportantChatMessageViewController : UITableViewController
- (instancetype) initWithNibName:(NSString *__nullable) nibNameOrNil bundle:(NSBundle *__nullable) nibBundleOrNil NS_UNAVAILABLE;
- (instancetype) initWithStyle:(UITableViewStyle) style NS_UNAVAILABLE;
- (instancetype) initWithCoder:(NSCoder *) aDecoder NS_UNAVAILABLE;

- (instancetype) initWithMessages:(NSArray <NSDictionary *> *) messages delegate:(id <CQImportantChatMessageDelegate>) delegate NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
