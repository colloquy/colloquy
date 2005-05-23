#import "NSPreferences.h"

@interface JVInterfacePreferences : NSPreferencesModule {
	IBOutlet NSTableView *windowSetsTable;
	IBOutlet NSTableView *rulesTable;
	IBOutlet NSButton *editWindowButton;
	IBOutlet NSButton *editRuleButton;
	IBOutlet NSPopUpButton *interfaceStyle;
	IBOutlet NSButton *sortByStatus;
	IBOutlet NSButton *alwaysShowTabs;

	IBOutlet NSPanel *windowEditPanel;
	IBOutlet NSTextField *windowTitle;
	IBOutlet NSButton *rememberPanels;
	IBOutlet NSButton *windowEditSaveButton;

	IBOutlet NSWindow *ruleEditPanel;
	IBOutlet NSTableView *ruleEditTable;
	IBOutlet NSPopUpButton *ruleOperation;
	IBOutlet NSButton *ignoreCase;

	NSMutableArray *_windowSets;
	NSMutableArray *_editingRuleCriterion;
	unsigned int _selectedWindowSet;
	unsigned int _selectedRuleSet;
	unsigned int _origRuleEditHeight;
	BOOL _makingNewWindowSet;
	BOOL _makingNewRuleSet;
}
- (NSMutableArray *) selectedRules;
- (NSMutableArray *) editingCriterion;

- (IBAction) addWindowSet:(id) sender;
- (IBAction) editWindowSet:(id) sender;
- (IBAction) saveWindowSet:(id) sender;
- (IBAction) cancelWindowSet:(id) sender;

- (IBAction) addRuleCriterionRow:(id) sender;
- (IBAction) removeRuleCriterionRow:(id) sender;
	
- (IBAction) addRuleSet:(id) sender;
- (IBAction) editRuleSet:(id) sender;
- (IBAction) saveRuleSet:(id) sender;
- (IBAction) cancelRuleSet:(id) sender;
@end