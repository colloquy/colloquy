extern NSString *CQHelpTopicsURLString;

@interface CQHelpTopicsViewController : UITableViewController {
	NSMutableArray *_helpSections;
	NSMutableData *_helpData;
	BOOL _loading;
}
- (id) initWithHelpContent:(NSArray *) help;

- (void) loadHelpContent;
- (void) loadDefaultHelpContent;
@end
