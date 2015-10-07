#import "CQPreferencesTableViewController.h"

@class CQTextView;

NS_ASSUME_NONNULL_BEGIN

@protocol CQPreferencesTextEditViewDelegate <NSObject>
@optional
- (NSString *) stringForFooterWithTextView:(CQTextView *) textView;
- (NSInteger) integerForCountdownInFooterWithTextView:(CQTextView *) textView;
@end

@interface CQPreferencesTextEditViewController : CQPreferencesTableViewController {
@protected
	id <CQPreferencesTextEditViewDelegate> __weak _delegate;

	NSString *_listItemText;
	NSString *_listItemPlaceholder;

	NSInteger _charactersRemainingBeforeDisplay;

	UILabel *_footerLabel;
}
@property (nonatomic, nullable, weak) id <CQPreferencesTextEditViewDelegate> delegate;
@property (nonatomic, copy) NSString *listItem;
@property (nonatomic, copy) NSString *listItemPlaceholder;
@property (nonatomic) NSInteger charactersRemainingBeforeDisplay;
@end

NS_ASSUME_NONNULL_END
