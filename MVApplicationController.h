extern NSString *JVChatStyleInstalledNotification;
extern NSString *JVChatEmoticonSetInstalledNotification;
extern NSString *JVMachineBecameIdleNotification;
extern NSString *JVMachineStoppedIdlingNotification;

@class JVChatTranscriptBrowserPanel;

@interface MVApplicationController : NSObject {
	io_registry_entry_t _hidEntry;
	NSTimer *_idleCheck;
	NSTimeInterval _lastIdle;
	BOOL _isIdle;
	BOOL _terminateWithoutConfirm;
}

- (IBAction) checkForUpdate:(id) sender;
- (IBAction) connectToSupportRoom:(id) sender;
- (IBAction) emailDeveloper:(id) sender;
- (IBAction) productWebsite:(id) sender;

- (IBAction) showPreferences:(id) sender;
- (IBAction) showTransferManager:(id) sender;
- (IBAction) showTranscriptBrowser:(id) sender;
- (IBAction) showConnectionManager:(id) sender;
- (IBAction) showBuddyList:(id) sender;

- (IBAction) copyStripped:(id) sender;

- (IBAction) markAllDisplays:(id) sender;

+ (BOOL) isTerminating;

- (NSTimeInterval) idleTime;

- (IBAction) terminateWithoutConfirm:(id) sender;
@end

@protocol JVChatViewController;

@interface NSObject (MVChatPluginContextualMenuSupport)
- (NSArray *) contextualMenuItemsForObject:(id) object inView:(id <JVChatViewController>) view;
@end
