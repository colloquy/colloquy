extern NSString *JVChatStyleInstalledNotification;
extern NSString *JVChatEmoticonSetInstalledNotification;
extern NSString *JVMachineBecameIdleNotification;
extern NSString *JVMachineStoppedIdlingNotification;

@class JVPreferencesController;
@class SUUpdater;

@interface MVApplicationController : NSObject {
	io_registry_entry_t _hidEntry;
	NSTimer *_idleCheck;
	SUUpdater *_updater;
	NSTimeInterval _lastIdle;
	BOOL _isIdle;
	BOOL _terminateWithoutConfirm;
	NSDate *_launchDate;
	NSMutableArray *_previouslyConnectedConnections;
}
- (IBAction) checkForUpdate:(id) sender;
- (IBAction) helpWebsite:(id) sender;
- (IBAction) connectToSupportRoom:(id) sender;
- (IBAction) emailDeveloper:(id) sender;
- (IBAction) productWebsite:(id) sender;
- (IBAction) bugReportWebsite:(id) sender;

- (IBAction) showPreferences:(id) sender;
- (IBAction) showActivityManager:(id) sender;
- (IBAction) showTranscriptBrowser:(id) sender;
- (IBAction) showConnectionManager:(id) sender;
- (IBAction) showBuddyList:(id) sender;

- (IBAction) markAllDisplays:(id) sender;

+ (BOOL) isTerminating;

- (NSTimeInterval) idleTime;

- (IBAction) terminateWithoutConfirm:(id) sender;

- (void) updateDockTile;
@end

@protocol JVChatViewController;

@interface NSObject (MVChatPluginContextualMenuSupport)
- (NSArray *) contextualMenuItemsForObject:(id) object inView:(id <JVChatViewController>) view;
- (void) setupPreferencesWithController:(JVPreferencesController *) controller;
@end
