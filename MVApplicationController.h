extern NSString *JVChatStyleInstalledNotification;
extern NSString *JVChatEmoticonSetInstalledNotification;

@interface MVApplicationController : NSObject {}
- (IBAction) checkForUpdate:(id) sender;
- (IBAction) connectToSupportRoom:(id) sender;
- (IBAction) emailDeveloper:(id) sender;
- (IBAction) productWebsite:(id) sender;

- (IBAction) showPreferences:(id) sender;
- (IBAction) showTransferManager:(id) sender;
- (IBAction) showConnectionManager:(id) sender;
- (IBAction) showBuddyList:(id) sender;

+ (BOOL) isTerminating;
@end

@protocol JVChatViewController;

@interface NSObject (MVChatPluginContextualMenuSupport)
- (NSArray *) contextualMenuItemsForObject:(id) object inView:(id <JVChatViewController>) view;
@end
