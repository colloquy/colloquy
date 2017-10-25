#import <Cocoa/Cocoa.h>
#import "JVInspectorController.h"
#import <AddressBook/ABPeoplePickerView.h>

@class MVTableView;
@class JVBuddy;
@class MVChatUser;
@class ABPeoplePickerController;
@class MVChatConnection;

typedef NS_ENUM(OSType, MVBuddyListSortOrder) {
	MVAvailabilitySortOrder = 'avlY',
	MVFirstNameSortOrder = 'fSnM',
	MVLastNameSortOrder = 'lSnM',
	MVServerSortOrder = 'serV'
};

COLLOQUY_EXPORT
@interface MVBuddyListController : NSWindowController <JVInspectionDelegator, NSTableViewDataSource> {
	@private
	IBOutlet MVTableView *buddies;
	IBOutlet NSButton *sendMessageButton;
	IBOutlet NSPopUpButton *actionButton;
	IBOutlet NSButton *infoButton;

	IBOutlet NSWindow *pickerWindow;
	IBOutlet ABPeoplePickerView *pickerView;

	IBOutlet NSWindow *newPersonWindow;
	IBOutlet NSTextField *nickname;
	IBOutlet NSTableView *servers;
	IBOutlet NSTextField *firstName;
	IBOutlet NSTextField *lastName;
	IBOutlet NSTextField *email;
	IBOutlet NSImageView *image;
	IBOutlet NSButton *addButton;

	NSString *_addPerson;
	NSMutableSet *_addServers;

	NSMutableSet *_buddyList;
	NSMutableSet *_onlineBuddies;
	NSMutableArray *_buddyOrder;

	BOOL _showFullNames;
	BOOL _showNicknameAndServer;
	BOOL _showIcons;
	BOOL _showOfflineBuddies;
	MVBuddyListSortOrder _sortOrder;

	CGFloat _animationPosition;
	NSMutableArray *_oldPositions;
	BOOL _viewingTop;
	BOOL _needsToAnimate;
	BOOL _animating;
}
#if __has_feature(objc_class_property)
@property (readonly, strong, class) MVBuddyListController *sharedBuddyList;
#else
+ (MVBuddyListController *) sharedBuddyList;
#endif

- (void) save;

- (IBAction) getInfo:(id) sender;

- (IBAction) showBuddyList:(id) sender;
- (IBAction) hideBuddyList:(id) sender;

- (void) addBuddy:(JVBuddy *) buddy;

- (JVBuddy *) buddyForUser:(MVChatUser *) user;
@property (readonly, copy) NSArray<JVBuddy*> *buddies;
@property (readonly, copy) NSSet<JVBuddy*> *onlineBuddies;

- (IBAction) showBuddyPickerSheet:(id) sender;
- (IBAction) cancelBuddySelection:(id) sender;
- (IBAction) confirmBuddySelection:(id) sender;

- (IBAction) showNewPersonSheet:(id) sender;
- (IBAction) cancelNewBuddy:(id) sender;
- (IBAction) confirmNewBuddy:(id) sender;

- (void) setNewBuddyNickname:(NSString *) nick;
- (void) setNewBuddyFullname:(NSString *) name;
- (void) setNewBuddyServer:(MVChatConnection *) connection;

- (IBAction) messageSelectedBuddy:(id) sender;
- (IBAction) sendFileToSelectedBuddy:(id) sender;

@property BOOL showFullNames;
- (IBAction) toggleShowFullNames:(id) sender;

@property BOOL showNicknameAndServer;
- (IBAction) toggleShowNicknameAndServer:(id) sender;

@property BOOL showIcons;
- (IBAction) toggleShowIcons:(id) sender;

@property BOOL showOfflineBuddies;
- (IBAction) toggleShowOfflineBuddies:(id) sender;

@property MVBuddyListSortOrder sortOrder;
- (IBAction) sortByAvailability:(id) sender;
- (IBAction) sortByFirstName:(id) sender;
- (IBAction) sortByLastName:(id) sender;
- (IBAction) sortByServer:(id) sender;
@end
