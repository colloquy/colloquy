#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <AppKit/NSNibDeclarations.h>

@class MVChatConnection;
@class MVTextView;
@class MVTableView;
@class MVMenuButton;
@class NSWindow;
@class NSButton;
@class NSTextField;
@class NSDrawer;
@class NSPopUpButton;
@class NSString;
@class NSDictionary;
@class NSMutableDictionary;
@class NSMutableArray;
@class NSDate;
@class NSScrollView;

void MVChatPlaySoundForAction( NSString *action );

extern NSArray *chatActionVerbs;

@interface MVChatWindowController : NSObject {
@private
	IBOutlet NSWindow *window;
	IBOutlet MVTextView *sendText;
	IBOutlet MVTextView *displayText;
	IBOutlet NSScrollView *sendTextScrollView;
	IBOutlet MVMenuButton *emoticonView;
	IBOutlet NSButton *infoButton, *msgButton;
	IBOutlet NSTextField *topicArea;
	IBOutlet NSDrawer *memberDrawer;
	IBOutlet MVTableView *memberListTable;
	IBOutlet NSPopUpButton *encodingView;
	MVChatConnection *_connection;
	NSString *outlet;
	NSMutableDictionary *memberList;
	NSMutableArray *sortedMembers, *sendHistory;
	NSStringEncoding encoding;
	int historyIndex;
	BOOL chatRoom, setup, firstMessage, memberDrawerWasOpen;
	BOOL invalidateMembers;
	BOOL _windowClosed;
	NSTimer *_refreshTimer;
	NSData *_topic;
	NSString *_topicAuth;
	NSMenu *_spillEncodingMenu;
	NSDate *_lastDateMessage;
}
+ (NSDictionary *) allChatWindowsForConnection:(MVChatConnection *) connection;
+ (NSDictionary *) roomChatWindowsForConnection:(MVChatConnection *) connection;
+ (NSDictionary *) userChatWindowsForConnection:(MVChatConnection *) connection;

+ (MVChatWindowController *) chatWindowForRoom:(NSString *) room withConnection:(MVChatConnection *) connection ifExists:(BOOL) exists;
+ (void) disposeWindowForRoom:(NSString *) room withConnection:(MVChatConnection *) connection;
+ (MVChatWindowController *) chatWindowWithUser:(NSString *) user withConnection:(MVChatConnection *) connection ifExists:(BOOL) exists;
+ (void) disposeWindowWithUser:(NSString *) user withConnection:(MVChatConnection *) connection;
+ (void) changeMemberInChatWindowsFrom:(NSString *) user to:(NSString *) nick forConnection:(MVChatConnection *) connection;
+ (void) updateChatWindowsMember:(NSString *) member withInfo:(NSDictionary *) info forConnection:(MVChatConnection *) connection;
+ (void) changeSelfInChatWindowsTo:(NSString *) nick forConnection:(MVChatConnection *) connection;

+ (NSData *) flattenedHTMLDataForMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding;

- (id) initWithRoom:(NSString *) room forConnection:(MVChatConnection *) connection;
- (id) initWithUser:(NSString *) user forConnection:(MVChatConnection *) connection;

- (MVChatConnection *) connection;
- (NSString *) targetUser;
- (NSString *) targetRoom;

- (BOOL) isChatRoom;
- (NSMutableArray *) memberList;

- (void) addMemberToChat:(NSString *) member asPreviousMember:(BOOL) previous;
- (void) updateMember:(NSString *) member withInfo:(NSDictionary *) info;
- (void) removeChatMember:(NSString *) member withReason:(NSData *) reason;
- (void) changeChatMember:(NSString *) member to:(NSString *) nick;
- (void) changeSelfTo:(NSString *) nick;

- (void) promoteChatMember:(NSString *) member by:(NSString *) by;
- (void) demoteChatMember:(NSString *) member by:(NSString *) by;
- (void) voiceChatMember:(NSString *) member by:(NSString *) by;
- (void) devoiceChatMember:(NSString *) member by:(NSString *) by;

- (void) chatMemberKicked:(NSString *) member by:(NSString *) by forReason:(NSData *) reason;
- (void) kickedFromChatBy:(NSString *) by forReason:(NSData *) reason;

- (void) connected;
- (void) disconnected;
- (void) unavailable;

- (IBAction) addEmoticon:(id) sender;

- (void) addStatusMessageToDisplay:(NSString *) message;

- (void) addMessageToDisplay:(NSString *) message fromUser:(NSString *) user asAction:(BOOL) action asAlert:(BOOL) alert;
- (void) addHTMLMessageToDisplay:(NSData *) message fromUser:(NSString *) user asAction:(BOOL) action asAlert:(BOOL) alert;
- (void) addAttributedMessageToDisplay:(NSAttributedString *) message fromUser:(NSString *) user asAction:(BOOL) actio asAlert:(BOOL) alertn;

- (IBAction) send:(id) sender;
- (IBAction) clear:(id) sender;
- (IBAction) clearDisplay:(id) sender;

- (void) changeTopic:(NSData *) topic by:(NSString *) author;

- (NSStringEncoding) encoding;
- (IBAction) changeEncoding:(id) sender;

- (IBAction) partChat:(id) sender;

- (BOOL) isVisible;
- (IBAction) showWindow:(id) sender;
- (IBAction) showWindowAndMakeKey:(id) sender;
- (IBAction) hideWindow:(id) sender;
- (NSWindow *) window;

- (IBAction) toggleMemberDrawer:(id) sender;
- (IBAction) openMemberDrawer:(id) sender;
- (IBAction) closeMemberDrawer:(id) sender;

- (IBAction) startChatWithSelectedUser:(id) sender;

- (IBAction) promoteSelectedUser:(id) sender;
- (IBAction) voiceSelectedUser:(id) sender;
- (IBAction) kickSelectedUser:(id) sender;
@end
