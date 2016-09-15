#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *JVChatStyleInstalledNotification;
extern NSString *JVChatEmoticonSetInstalledNotification;
extern NSString *JVMachineBecameIdleNotification;
extern NSString *JVMachineStoppedIdlingNotification;

@class CQMPreferencesWindowController;
@class SUUpdater;
@protocol MASPreferencesViewController;

@interface MVApplicationController : NSObject {
	io_registry_entry_t _hidEntry;
	NSTimer *_idleCheck;
	SUUpdater *_updater;
	NSTimeInterval _lastIdle;
	BOOL _isIdle;
	BOOL _terminateWithoutConfirm;
	NSDate *_launchDate;
	NSMutableArray<NSDictionary<NSString*,id>*> *_previouslyConnectedConnections;
}

@property(nonatomic, strong, readonly) CQMPreferencesWindowController *preferencesWindowController;

- (IBAction) checkForUpdate:(nullable id) sender;
- (IBAction) helpWebsite:(nullable id) sender;
- (IBAction) connectToSupportRoom:(nullable id) sender;
- (IBAction) emailDeveloper:(nullable id) sender;
- (IBAction) productWebsite:(nullable id) sender;
- (IBAction) bugReportWebsite:(nullable id) sender;

- (IBAction) showPreferences:(nullable id) sender;
- (IBAction) showTransferManager:(nullable id) sender;
- (IBAction) showTranscriptBrowser:(nullable id) sender;
- (IBAction) showConnectionManager:(nullable id) sender;
- (IBAction) showBuddyList:(nullable id) sender;

- (IBAction) markAllDisplays:(nullable id) sender;

+ (BOOL) isTerminating;
#if __has_feature(objc_class_property)
@property (class, readonly, getter=isTerminating) BOOL terminating;
#endif

@property (readonly) NSTimeInterval idleTime;

- (IBAction) terminateWithoutConfirm:(nullable id) sender;

- (void) updateDockTile;
@end

@protocol JVChatViewController;

@protocol MVChatPluginContextualMenuSupport <MVChatPlugin>
- (nullable NSArray<NSMenuItem*> *) contextualMenuItemsForObject:(nullable id) object inView:(nullable id <JVChatViewController>) view;
@optional
- (nullable NSViewController<MASPreferencesViewController> *) preferencesViewController;
@end

NS_ASSUME_NONNULL_END
