@class CQPreferencesListViewController;

typedef NS_ENUM(NSInteger, CQPreferencesListType) {
	CQPreferencesListTypeNone,
	CQPreferencesListTypeAudio,
	CQPreferencesListTypeFont,
	CQPreferencesListTypeImage
};

NS_ASSUME_NONNULL_BEGIN

typedef void (^CQPreferencesListBlock)(CQPreferencesListViewController *preferencesListViewController);

@interface CQPreferencesListViewController : UITableViewController
@property (nonatomic) BOOL allowEditing;
@property (nonatomic) NSInteger selectedItemIndex;
@property (nonatomic, copy) NSArray *items;
@property (nonatomic, copy) NSArray *values;
@property (nonatomic, copy) NSArray *details;
@property (nonatomic, strong) UIImage *itemImage;
@property (nonatomic, copy) NSString *addItemLabelText;
@property (nonatomic, copy) NSString *noItemsLabelText;
@property (nonatomic, copy) NSString *editViewTitle;
@property (nonatomic, copy) NSString *editPlaceholder;
@property (nonatomic, copy) NSString *footerText;
@property (nonatomic, strong) id customEditingViewController;

@property (nonatomic, nullable, weak) id target;
@property (nonatomic) SEL action;
@property (nonatomic, copy) CQPreferencesListBlock preferencesListBlock;

@property (nonatomic) CQPreferencesListType listType;
@end

NS_ASSUME_NONNULL_END
