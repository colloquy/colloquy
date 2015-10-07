#import "CQPreferencesTableViewController.h"

NS_ASSUME_NONNULL_BEGIN

@protocol CQPreferencesTextEditViewDelegate <NSObject>
@optional
- (NSString *) stringForFooterWithTextView:(UITextView *) textView;
- (NSInteger) integerForCountdownInFooterWithTextView:(UITextView *) textView;
@end

@interface CQPreferencesTextEditViewController : CQPreferencesTableViewController
@property (nonatomic, nullable, weak) id <CQPreferencesTextEditViewDelegate> delegate;
@property (nonatomic, copy) NSString *listItem;
@property (nonatomic, copy) NSString *listItemPlaceholder;
@property (nonatomic) NSInteger charactersRemainingBeforeDisplay;
@end

NS_ASSUME_NONNULL_END
