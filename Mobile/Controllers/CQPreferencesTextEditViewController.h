#import "CQPreferencesTableViewController.h"

@class CQTextView;

@protocol CQPreferencesTextEditViewDelegate <NSObject>
@optional
- (NSString *) stringForFooterWithTextView:(CQTextView *) textView;
- (NSInteger) integerForCountdownInFooterWithTextView:(CQTextView *) textView;
@end

@interface CQPreferencesTextEditViewController : CQPreferencesTableViewController {
@protected
	id <CQPreferencesTextEditViewDelegate> _delegate;

	NSString *_listItemText;
	NSString *_listItemPlaceholder;
	NSString *_assignedPlaceholder;

	NSInteger _charactersRemainingBeforeDisplay;

	UILabel *_footerLabel;
}
@property (nonatomic, retain) id <CQPreferencesTextEditViewDelegate> delegate;
@property (nonatomic, copy) NSString *listItemText;
@property (nonatomic, copy) NSString *listItemPlaceholder;
@property (nonatomic, copy) NSString *assignedPlaceholder;
@property (nonatomic) NSInteger charactersRemainingBeforeDisplay;
@end
