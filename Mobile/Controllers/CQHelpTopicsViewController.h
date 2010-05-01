#import "CQTableViewController.h"

@class MPMoviePlayerController;

@interface CQHelpTopicsViewController : CQTableViewController {
	MPMoviePlayerController *_moviePlayer;
	NSMutableArray *_helpSections;
	NSMutableData *_helpData;
	BOOL _loading;
}
- (void) loadHelpContent;
- (void) loadDefaultHelpContent;
@end
