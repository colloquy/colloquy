#import "KAIgnoreRule.h"

@class MVChatConnection;
@class MVChatRoom;
@class MVChatUser;
@class JVChatWindowController;
@class JVChatRoomPanel;
@class JVDirectChatPanel;
@class JVChatTranscriptPanel;
@class JVSmartTranscriptPanel;
@class JVChatConsolePanel;

@protocol JVChatViewController;

@interface JVChatController : NSObject {
	@private
	NSMutableArray *_chatWindows;
	NSMutableArray *_chatControllers;
	NSArray *_windowRuleSets;
}
+ (JVChatController *) defaultController;
+ (NSMenu *) smartTranscriptMenu;
+ (void) refreshSmartTranscriptMenu;

- (void) addViewControllerToPreferedWindowController:(id <JVChatViewController>) controller userInitiated:(BOOL) initiated;

- (NSSet *) allChatWindowControllers;
- (JVChatWindowController *) newChatWindowController;
- (JVChatWindowController *) chatWindowControllerWithIdentifier:(NSString *) identifier;
- (void) disposeChatWindowController:(JVChatWindowController *) controller;

- (NSSet *) allChatViewControllers;
- (NSSet *) chatViewControllersWithConnection:(MVChatConnection *) connection;
- (NSSet *) chatViewControllersOfClass:(Class) class;
- (NSSet *) chatViewControllersKindOfClass:(Class) class;

- (JVChatRoomPanel *) chatViewControllerForRoom:(MVChatRoom *) room ifExists:(BOOL) exists;
- (JVDirectChatPanel *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists;
- (JVDirectChatPanel *) chatViewControllerForUser:(MVChatUser *) user ifExists:(BOOL) exists userInitiated:(BOOL) requested;
- (JVChatTranscriptPanel *) chatViewControllerForTranscript:(NSString *) filename;
- (JVChatConsolePanel *) chatConsoleForConnection:(MVChatConnection *) connection ifExists:(BOOL) exists;

- (JVSmartTranscriptPanel *) newSmartTranscript;
- (NSSet *) smartTranscripts;
- (void) saveSmartTranscripts;
- (void) disposeSmartTranscript:(JVSmartTranscriptPanel *) panel;

- (void) disposeViewController:(id <JVChatViewController>) controller;
- (void) detachViewController:(id <JVChatViewController>) controller;

- (IBAction) detachView:(id) sender;

- (JVIgnoreMatchResult) shouldIgnoreUser:(MVChatUser *) user withMessage:(NSAttributedString *) message inView:(id <JVChatViewController>) view;
@end

@interface NSObject (MVChatPluginCommandSupport)
- (BOOL) processUserCommand:(NSString *) command withArguments:(NSAttributedString *) arguments toConnection:(MVChatConnection *) connection inView:(id <JVChatViewController>) view;
@end