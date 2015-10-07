@class MVChatConnection;

@interface JVChatRoomBrowser : NSWindowController {
	id _self;
	IBOutlet NSTableView *roomsTable;
	IBOutlet NSTabView *browserArea;
	IBOutlet NSTabView *searchArea;
	IBOutlet NSPopUpButton *connectionPopup;
	IBOutlet NSComboBox *roomField;
	IBOutlet NSSearchField *searchField;
	IBOutlet NSTextField *indexResults;
	IBOutlet NSTextField *indexAndFindResults;
	IBOutlet NSButton *showBrowser;
	IBOutlet NSButton *acceptButton;
	BOOL _collapsed;
	BOOL _ascending;
	BOOL _needsRefresh;
	NSString *_sortColumn;
	MVChatConnection *_connection;
	NSMutableDictionary *_roomResults;
	NSMutableArray *_roomOrder;
	NSString *_currentFilter;
}
+ (instancetype) chatRoomBrowserForConnection:(MVChatConnection *) connection;

- (IBAction) close:(id) sender;
- (IBAction) joinRoom:(id) sender;

- (IBAction) hideRoomBrowser:(id) sender;
- (IBAction) showRoomBrowser:(id) sender;
- (IBAction) toggleRoomBrowser:(id) sender;

- (IBAction) changeConnection:(id) sender;

@property (copy) NSString *filter;

@property (strong) MVChatConnection *connection;
@end
