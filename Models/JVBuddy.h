extern NSString *JVBuddyCameOnlineNotification;
extern NSString *JVBuddyWentOfflineNotification;

extern NSString *JVBuddyUserCameOnlineNotification;
extern NSString *JVBuddyUserWentOfflineNotification;
extern NSString *JVBuddyUserStatusChangedNotification;
extern NSString *JVBuddyUserIdleTimeUpdatedNotification;

extern NSString *JVBuddyActiveUserChangedNotification;

@class ABPerson;

extern NSString * const JVBuddyAddressBookIRCNicknameProperty;
extern NSString* const JVBuddyAddressBookSpeechVoiceProperty;

typedef enum {
	JVBuddyActiveNickname = 0x0,
	JVBuddyGivenNickname = 0x1,
	JVBuddyFullName = 0x2
} JVBuddyName;

@interface JVBuddy : NSObject {
	ABPerson *_person;
	NSMutableArray *_rules;
	NSMutableSet *_users;
	MVChatUser *_activeUser;
	NSImage *_picture;
	NSString *_firstName;
	NSString *_lastName;
	NSString *_primaryEmail;
	NSString *_givenNickname;
	NSString *_speechVoice;
	NSString *_uniqueIdentifier;
}
+ (JVBuddyName) preferredName;
+ (void) setPreferredName:(JVBuddyName) preferred;

- (id) initWithDictionaryRepresentation:(NSDictionary *) dictionary;
- (NSDictionary *) dictionaryRepresentation;

- (void) registerWithConnection:(MVChatConnection *) connection;
- (void) registerWithApplicableConnections;
- (void) unregisterWithConnection:(MVChatConnection *) connection;
- (void) unregisterWithConnections;

- (MVChatUser *) activeUser;
- (void) setActiveUser:(MVChatUser *) user;

- (MVChatUserStatus) status;
- (NSData *) awayStatusMessage;

- (BOOL) isOnline;
- (NSDate *) dateConnected;
- (NSDate *) dateDisconnected;

- (NSTimeInterval) idleTime;

- (NSString *) displayName;
- (NSString *) nickname;

- (NSSet *) users;

- (NSArray *) watchRules;
- (void) addWatchRule:(MVChatUserWatchRule *) rule;
- (void) removeWatchRule:(MVChatUserWatchRule *) rule;

- (NSImage *) picture;
- (void) setPicture:(NSImage *) picture;

- (NSString *) compositeName;
- (NSString *) firstName;
- (NSString *) lastName;
- (NSString *) primaryEmail;
- (NSString *) givenNickname;
- (NSString *) speechVoice;
- (NSString *) uniqueIdentifier;

- (void) setFirstName:(NSString *) name;
- (void) setLastName:(NSString *) name;
- (void) setPrimaryEmail:(NSString *) email;
- (void) setGivenNickname:(NSString *) name;
- (void) setSpeechVoice:(NSString *) voice;

- (ABPerson *) addressBookPersonRecord;
- (void) setAddressBookPersonRecord:(ABPerson *) record;
- (void) editInAddressBook;
- (void) viewInAddressBook;

- (NSComparisonResult) availabilityCompare:(JVBuddy *) buddy;
- (NSComparisonResult) firstNameCompare:(JVBuddy *) buddy;
- (NSComparisonResult) lastNameCompare:(JVBuddy *) buddy;
- (NSComparisonResult) serverCompare:(JVBuddy *) buddy;
- (NSComparisonResult) nicknameCompare:(JVBuddy *) buddy;
@end
