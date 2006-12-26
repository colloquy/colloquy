#import "JVBuddy.h"
#import "JVInspectorController.h"

@interface JVBuddy (JVBuddyInspection) <JVInspection>
- (id <JVInspector>) inspector;
@end

@interface JVBuddyInspector : NSObject <JVInspector> {
	IBOutlet NSView *view;
	IBOutlet NSImageView *picture;
	IBOutlet NSTextField *firstName;
	IBOutlet NSTextField *lastName;
	IBOutlet NSTextField *nickname;
	IBOutlet NSTextField *email;
	IBOutlet NSPopUpButton *voices;
	IBOutlet NSTableView *identifiersTable;
	IBOutlet NSButton *removeIdentifier;
	IBOutlet NSButton *addIdentifier;
	IBOutlet NSButton *editIdentifier;

	IBOutlet NSPanel *identifierEditPanel;
	IBOutlet NSTextField *identifierNickname;
	IBOutlet NSTextField *identifierRealName;
	IBOutlet NSTextField *identifierUsername;
	IBOutlet NSTextField *identifierHostname;
	IBOutlet NSMatrix *identifierConnections;
	IBOutlet NSTableView *identifierDomainsTable;
	IBOutlet NSButton *removeDomain;
	IBOutlet NSButton *addDomain;
	IBOutlet NSButton *identifierOkay;

	MVChatUserWatchRule *_currentRule;
	NSMutableArray *_editDomains;

	JVBuddy *_buddy;
	BOOL _nibLoaded;
	BOOL _identifierIsNew;
}
- (id) initWithBuddy:(JVBuddy *) buddy;

- (IBAction) changeBuddyIcon:(id) sender;
- (IBAction) changeFirstName:(id) sender;
- (IBAction) changeLastName:(id) sender;
- (IBAction) changeNickname:(id) sender;
- (IBAction) changeEmail:(id) sender;
- (IBAction) changeSpeechVoice:(id) sender;

- (IBAction) addIdentifier:(id) sender;
- (IBAction) editIdentifier:(id) sender;
- (IBAction) removeIdentifier:(id) sender;

- (IBAction) addDomain:(id) sender;
- (IBAction) removeDomain:(id) sender;

- (IBAction) changeConnectionState:(id) sender;

- (IBAction) discardIdentifierChanges:(id) sender;
- (IBAction) saveIdentifierChanges:(id) sender;

- (IBAction) changeCard:(id) sender;
@end
