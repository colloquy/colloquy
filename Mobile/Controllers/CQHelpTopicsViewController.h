@class MPMoviePlayerController;

@interface CQHelpTopicsViewController : UITableViewController {
	MPMoviePlayerController *_moviePlayer;
	NSMutableArray *_helpSections;
	NSMutableData *_helpData;
	BOOL _loading;
}
- (id) init;

- (void) loadHelpContent;
- (void) loadDefaultHelpContent;
@end
