#import <ChatCore/MVChatConnection.h>
#import "JVInspectorController.h"
#import "JVChatConsolePanel.h"

@interface MVChatConnection (MVChatConnectionInspection) <JVInspection>
- (id <JVInspector>) inspector;
@end

@interface JVChatConsolePanel (JVChatConsolePanelInspection) <JVInspection>
- (id <JVInspector>) inspector;
@end

@interface JVConnectionInspector : NSObject <JVInspector> {
	IBOutlet NSView *view;
	IBOutlet NSTabView *tabView;

	IBOutlet NSTextField *editNickname;
	IBOutlet NSTextField *editAltNicknames;
	IBOutlet NSTextField *editPassword;
	IBOutlet NSTextField *editRealName;
	IBOutlet NSTextField *editUsername;
	IBOutlet NSTextField *editServerPassword;
	IBOutlet NSTextField *editAddress;
	IBOutlet NSPopUpButton *encoding;
	IBOutlet NSPopUpButton *editProxy;
	IBOutlet NSTextField *editPort;
	IBOutlet NSButton *editAutomatic;
	IBOutlet NSTableView *editRooms;
	IBOutlet NSButton *editRemoveRoom;
	IBOutlet NSTextView *connectCommands;
	IBOutlet NSButton *sslConnection;

	IBOutlet NSTableView *editRules;
	IBOutlet NSPanel *ruleSheet;
	IBOutlet NSTextField *editRuleName;
	IBOutlet NSButton *makeRulePermanent;
	IBOutlet NSButton *ruleUsesSender;
	IBOutlet NSButton *ruleUsesMessage;
	IBOutlet NSButton *ruleUsesRooms;
	IBOutlet NSPopUpButton *senderType;
	IBOutlet NSPopUpButton *messageType;
	IBOutlet NSTextField *editRuleSender;
	IBOutlet NSTextField *editRuleMessage;
	IBOutlet NSTableView *editRuleRooms;
	IBOutlet NSButton *deleteRoomFromRule;
	IBOutlet NSButton *addRoomToRule;
	IBOutlet NSButton *addRule;
	IBOutlet NSButton *deleteRule;
	IBOutlet NSButton *editRule;

	MVChatConnection *_connection;
	BOOL _nibLoaded;
	NSMutableArray *_editingRooms;
	NSMutableArray *_editingRuleRooms;

	BOOL _ignoreRuleIsNew;
	NSMutableArray *_ignoreRules;
}
- (id) initWithConnection:(MVChatConnection *) connection;

- (void) selectTabWithIdentifier:(NSString *) identifier;

- (void) buildEncodingMenu;
- (IBAction) changeEncoding:(id) sender;

- (IBAction) openNetworkPreferences:(id) sender;
- (IBAction) editText:(id) sender;
- (IBAction) toggleAutoConnect:(id) sender;
- (IBAction) toggleSSLConnection:(id) sender;
- (IBAction) changeProxy:(id) sender;

- (IBAction) addRoom:(id) sender;
- (IBAction) removeRoom:(id) sender;

- (IBAction) removeRule:(id) sender;
- (IBAction) addRule:(id) sender;
- (IBAction) removeRoomFromRule:(id) sender;
- (IBAction) addRoomToRule:(id) sender;
- (IBAction) configureRule:(id) sender;
- (IBAction) saveRule:(id) sender;
- (IBAction) discardChangesToRule:(id) sender;
@end