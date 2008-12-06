@interface CQSearchCell : UITableViewCell <UISearchBarDelegate> {
	UISearchBar *_searchBar;
	SEL _searchAction;
}
@property (nonatomic) SEL searchAction;
@end
