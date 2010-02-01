@class MPMoviePlayerController;

@interface CQHelpTopicsViewController : UITableViewController {
	MPMoviePlayerController *_moviePlayer;
	NSMutableArray *_helpSections;
	NSMutableData *_helpData;
	BOOL _loading;
}
- (void) loadHelpContent;
- (void) loadDefaultHelpContent;
@end
