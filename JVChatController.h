#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>
#import "KAIgnoreRule.h"

@class NSMutableSet;
@class MVChatConnection;
@class NSSet;
@class JVChatWindowController;
@class NSString;
@class JVChatRoom;
@class JVDirectChat;
@class JVChatTranscript;
@class JVChatConsole;
@class NSAttributedString;
@class KAInternalIgnoreRule;

@protocol JVChatViewController;

@interface JVChatController : NSObject {
	@private
	NSMutableArray *_chatWindows;
	NSMutableArray *_chatControllers;
	NSMutableArray *_ignoreRules;
}
+ (JVChatController *) defaultManager;

- (NSSet *) allChatWindowControllers;
- (JVChatWindowController *) newChatWindowController;
- (void) disposeChatWindowController:(JVChatWindowController *) controller;

- (NSSet *) allChatViewControllers;
- (NSSet *) chatViewControllersWithConnection:(MVChatConnection *) connection;
- (NSSet *) chatViewControllersOfClass:(Class) class;
- (NSSet *) chatViewControllersKindOfClass:(Class) class;
- (JVChatRoom *) chatViewControllerForRoom:(NSString *) room withConnection:(MVChatConnection *) connection ifExists:(BOOL) exists;
- (JVDirectChat *) chatViewControllerForUser:(NSString *) user withConnection:(MVChatConnection *) connection ifExists:(BOOL) exists;
- (JVDirectChat *) chatViewControllerForUser:(NSString *) user withConnection:(MVChatConnection *) connection ifExists:(BOOL) exists userInitiated:(BOOL) requested;
- (JVChatTranscript *) chatViewControllerForTranscript:(NSString *) filename;
- (JVChatConsole *) chatConsoleForConnection:(MVChatConnection *) connection ifExists:(BOOL) exists;

- (void) disposeViewController:(id <JVChatViewController>) controller;
- (void) detachViewController:(id <JVChatViewController>) controller;

- (IBAction) detachView:(id) sender;

- (void) addIgnoreForUser:(NSString *)user withMessage:(NSString *)message inRooms:(NSArray *)rooms usesRegex:(BOOL) regex;
- (JVIgnoreMatchResult) shouldIgnoreUser:(NSString *) name withMessage:(NSAttributedString *) message inView:(id <JVChatViewController>) view;
@end
