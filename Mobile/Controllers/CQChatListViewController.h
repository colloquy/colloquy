#import "CQTableViewController.h"

@protocol CQChatViewController;

@interface CQChatListViewController : CQTableViewController <UIActionSheetDelegate, UIDocumentInteractionControllerDelegate, UISearchBarDelegate, UISearchDisplayDelegate> {
	@protected
	UISearchBar *_colloquiesSearchBar;
	UISearchDisplayController *_colloquiesSearchDisplayController;

	UIActionSheet *_currentConnectionActionSheet;
	UIActionSheet *_currentChatViewActionSheet;
	id <UIActionSheetDelegate> _currentChatViewActionSheetDelegate;
	id <CQChatViewController> _previousSelectedChatViewController;
	BOOL _active;
	BOOL _needsUpdate;
	BOOL _ignoreNotifications;
	BOOL _isReordering;
	NSTimer *_connectTimeUpdateTimer;
	NSMapTable *_headerViewsForConnections;
	NSMapTable *_connectionsForHeaderViews;
	NSMapTable *_indexPathsForChatControllers; // never in editing state
}
@property (nonatomic) BOOL active;

- (void) chatViewControllerAdded:(id) controller;

- (void) selectChatViewController:(id) controller animatedSelection:(BOOL) animatedSelection animatedScroll:(BOOL) animatedScroll;
@end
