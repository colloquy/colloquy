#import "CQTableViewController.h"

@class CQPreferencesListEditViewController;

@interface CQPreferencesListViewController : CQTableViewController {
	@protected
	NSMutableArray *_items;
	UIImage *_itemImage;
	NSString *_addItemLabelText;
	NSString *_noItemsLabelText;
	NSString *_editViewTitle;
	NSString *_editPlaceholder;
	NSUInteger _editingIndex;
	NSUInteger _selectedItemIndex;
	CQPreferencesListEditViewController *_editingViewController;
	id _customEditingViewController;
	id _target;
	SEL _action;
	BOOL _pendingChanges;
	BOOL _allowEditing;
}
@property (nonatomic) BOOL allowEditing;
@property (nonatomic) NSUInteger selectedItemIndex;
@property (nonatomic, copy) NSArray *items;
@property (nonatomic, retain) UIImage *itemImage;
@property (nonatomic, copy) NSString *addItemLabelText;
@property (nonatomic, copy) NSString *noItemsLabelText;
@property (nonatomic, copy) NSString *editViewTitle;
@property (nonatomic, copy) NSString *editPlaceholder;
@property (nonatomic, retain) id customEditingViewController;

@property (nonatomic, assign) id target;
@property (nonatomic) SEL action;
@end
