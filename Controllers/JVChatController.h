#import <Cocoa/Cocoa.h>
#import "KAIgnoreRule.h"

@class MVChatConnection;
@class MVChatRoom;
@class MVChatUser;
@class MVDirectChatConnection;
@class JVChatWindowController;
@class JVChatRoomPanel;
@class JVDirectChatPanel;
@class JVChatTranscriptPanel;
@class JVSmartTranscriptPanel;
@class JVChatConsolePanel;

@protocol JVChatViewController;

NS_ASSUME_NONNULL_BEGIN

@interface JVChatController : NSObject {
	@private
	NSMutableSet *_chatWindows;
	NSMutableSet *_chatControllers;
	NSArray *_windowRuleSets;
}
+ (JVChatController *) defaultController;
+ (NSMenu *) smartTranscriptMenu;
#if __has_feature(objc_class_property)
@property (readonly, strong, class) JVChatController *defaultController;
@property (readonly, strong, class) NSMenu *smartTranscriptMenu;
#endif
+ (void) refreshSmartTranscriptMenu;

- (void) addViewControllerToPreferedWindowController:(id <JVChatViewController>) controller userInitiated:(BOOL) initiated;

@property (readonly, copy) NSSet<JVChatWindowController*> *allChatWindowControllers;
- (nullable JVChatWindowController *) createChatWindowController NS_RETURNS_RETAINED;
- (JVChatWindowController *) chatWindowControllerWithIdentifier:(NSString *) identifier;
- (void) disposeChatWindowController:(JVChatWindowController *) controller;

@property (readonly, copy) NSSet<id <JVChatViewController>> *allChatViewControllers;
- (NSSet<id <JVChatViewController>> *) chatViewControllersWithConnection:(MVChatConnection *) connection;
- (NSSet<id <JVChatViewController>> *) chatViewControllersOfClass:(Class) class;
- (NSSet<id <JVChatViewController>> *) chatViewControllersKindOfClass:(Class) class;

- (nullable JVChatRoomPanel *) chatViewControllerForRoom:(MVChatRoom *) room ifExists:(BOOL) exists;
- (nullable JVDirectChatPanel *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists;
- (nullable JVDirectChatPanel *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists userInitiated:(BOOL) requested;
- (nullable JVDirectChatPanel *) chatViewControllerForDirectChatConnection:(MVDirectChatConnection *) connection ifExists:(BOOL) exists;
- (nullable JVDirectChatPanel *) chatViewControllerForDirectChatConnection:(MVDirectChatConnection *) connection ifExists:(BOOL) exists userInitiated:(BOOL) initiated;
- (nullable JVChatTranscriptPanel *) chatViewControllerForTranscript:(NSString *) filename;
- (nullable JVChatConsolePanel *) chatConsoleForConnection:(MVChatConnection *) connection ifExists:(BOOL) exists;

- (nullable JVSmartTranscriptPanel *)createSmartTranscript NS_RETURNS_RETAINED;
@property (readonly, copy) NSSet<JVSmartTranscriptPanel*> *smartTranscripts;
- (void) saveSmartTranscripts;
- (void) disposeSmartTranscript:(JVSmartTranscriptPanel *) panel;

- (void) disposeViewController:(id <JVChatViewController>) controller;
- (void) detachViewController:(id <JVChatViewController>) controller;

- (IBAction) detachView:(nullable id) sender;

- (JVIgnoreMatchResult) shouldIgnoreUser:(MVChatUser *) user withMessage:(nullable NSAttributedString *) message inView:(nullable id <JVChatViewController>) view;
@end

@protocol MVChatPluginCommandSupport <MVChatPlugin>
@required
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(nullable MVChatConnection *) connection inView:(nullable id <JVChatViewController>) view;
@end

NS_ASSUME_NONNULL_END
