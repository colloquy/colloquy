@class CQPreferencesListEditViewController;

@interface CQPreferencesListViewController : UITableViewController {
	NSMutableArray *_items;
	UIImage *_itemImage;
	NSString *_addItemLabelText;
	NSString *_noItemsLabelText;
	NSString *_editViewTitle;
	NSString *_editPlaceholder;
	NSUInteger _editingIndex;
	CQPreferencesListEditViewController *_editingView;
	id _target;
	SEL _action;
	BOOL _pendingChanges;
}
@property (nonatomic, copy) NSArray *items;
@property (nonatomic, retain) UIImage *itemImage;
@property (nonatomic, copy) NSString *addItemLabelText;
@property (nonatomic, copy) NSString *noItemsLabelText;
@property (nonatomic, copy) NSString *editViewTitle;
@property (nonatomic, copy) NSString *editPlaceholder;

@property (nonatomic, assign) id target;
@property (nonatomic) SEL action;
@end
