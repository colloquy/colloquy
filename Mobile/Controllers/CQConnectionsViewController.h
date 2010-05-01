#import "CQTableViewController.h"

@class MVChatConnection;
@class CQBouncerSettings;
@class CQConnectionsNavigationController;

@interface CQConnectionsViewController : CQTableViewController <UIActionSheetDelegate> {
	@protected
	NSTimer *_connectTimeUpdateTimer;
	BOOL _active;
	BOOL _ignoreNotifications;
}
@property (nonatomic, readonly, retain) CQConnectionsNavigationController *navigationController;

- (void) connectionAdded:(MVChatConnection *) connection;
- (void) connectionRemovedAtIndexPath:(NSIndexPath *) indexPath;
- (void) connectionMovedFromIndexPath:(NSIndexPath *) oldIndexPath toIndexPath:(NSIndexPath *) newIndexPath;

- (void) bouncerSettingsAdded:(CQBouncerSettings *) bouncer;
- (void) bouncerSettingsRemovedAtIndex:(NSUInteger) index;

- (void) updateConnection:(MVChatConnection *) connection;

- (NSUInteger) sectionForBouncerSettings:(CQBouncerSettings *) bouncer;
- (NSUInteger) sectionForConnection:(MVChatConnection *) connection;
- (NSIndexPath *) indexPathForConnection:(MVChatConnection *) connection;
- (MVChatConnection *) connectionAtIndexPath:(NSIndexPath *) indexPath;
@end
