#import "CQTableViewController.h"

@class MPMoviePlayerController;

NS_ASSUME_NONNULL_BEGIN

@interface CQHelpTopicsViewController : CQTableViewController {
	MPMoviePlayerController *_moviePlayer;
	NSMutableArray *_helpSections;
	NSMutableData *_helpData;
	BOOL _loading;
}
- (void) loadHelpContent;
- (void) loadDefaultHelpContent;
@end

NS_ASSUME_NONNULL_END
