extern NSString *JVBuddyCameOnlineNotification;
extern NSString *JVBuddyWentOfflineNotification;

extern NSString *JVBuddyUserCameOnlineNotification;
extern NSString *JVBuddyUserWentOfflineNotification;
extern NSString *JVBuddyUserStatusChangedNotification;
extern NSString *JVBuddyUserIdleTimeUpdatedNotification;

extern NSString *JVBuddyActiveUserChangedNotification;

@class ABPerson;
@class MVChatUserWatchRule;

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
	NSMutableArray *_users;
	MVChatUser *_activeUser;
}
+ (JVBuddyName) preferredName;
+ (void) setPreferredName:(JVBuddyName) preferred;

- (id) initWithDictionaryRepresentation:(NSDictionary *) dictionary;
- (NSDictionary *) dictionaryRepresentation;

- (void) registerWithApplicableConnections;
- (void) unregisterWithApplicableConnections;

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

- (NSArray *) users;

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

- (void) setFirstName:(NSString *) name;
- (void) setLastName:(NSString *) name;
- (void) setPrimaryEmail:(NSString *) email;
- (void) setGivenNickname:(NSString *) name;
- (void) setSpeechVoice:(NSString *) voice;
- (NSString *) uniqueIdentifier;
- (ABPerson *) person;

- (void) editInAddressBook;
- (void) viewInAddressBook;

- (NSComparisonResult) availabilityCompare:(JVBuddy *) buddy;
- (NSComparisonResult) firstNameCompare:(JVBuddy *) buddy;
- (NSComparisonResult) lastNameCompare:(JVBuddy *) buddy;
- (NSComparisonResult) serverCompare:(JVBuddy *) buddy;
- (NSComparisonResult) nicknameCompare:(JVBuddy *) buddy;
@end
