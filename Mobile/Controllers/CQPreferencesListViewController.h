@interface CQPreferencesListViewController : UITableViewController {
	NSMutableArray *_items;
	UIImage *_itemImage;
	NSString *_addItemLabelText;
	NSString *_noItemsLabelText;
}
@property (nonatomic, copy) NSArray *items;
@property (nonatomic, retain) UIImage *itemImage;
@property (nonatomic, copy) NSString *addItemLabelText;
@property (nonatomic, copy) NSString *noItemsLabelText;
@end
