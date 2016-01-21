extern NSString *JVBuddyCameOnlineNotification;
extern NSString *JVBuddyWentOfflineNotification;

extern NSString *JVBuddyUserCameOnlineNotification;
extern NSString *JVBuddyUserWentOfflineNotification;
extern NSString *JVBuddyUserStatusChangedNotification;
extern NSString *JVBuddyUserIdleTimeUpdatedNotification;

extern NSString *JVBuddyActiveUserChangedNotification;

@class ABPerson;
@class MVChatUser;

typedef NS_ENUM(NSInteger, JVBuddyName) {
	JVBuddyActiveNickname = 0x0,
	JVBuddyGivenNickname = 0x1,
	JVBuddyFullName = 0x2
};

@interface JVBuddy : NSObject
+ (JVBuddyName) preferredName;
+ (void) setPreferredName:(JVBuddyName) preferred;

- (instancetype) initWithDictionaryRepresentation:(NSDictionary *) dictionary;
- (NSDictionary *) dictionaryRepresentation;

- (void) registerWithConnection:(MVChatConnection *) connection;
- (void) registerWithApplicableConnections;
- (void) unregisterWithConnection:(MVChatConnection *) connection;
- (void) unregisterWithConnections;

@property (nonatomic, strong) MVChatUser *activeUser;

@property (readonly) MVChatUserStatus status;
@property (readonly) NSData *awayStatusMessage;

@property (readonly, getter=isOnline) BOOL online;
@property (readonly) NSDate *dateConnected;
@property (readonly) NSDate *dateDisconnected;

@property (readonly) NSTimeInterval idleTime;

@property (readonly, copy) NSString *displayName;
@property (readonly, copy) NSString *nickname;

@property (readonly, copy) NSSet<MVChatUser*> *users;

@property (readonly, copy) NSArray<MVChatUserWatchRule*> *watchRules;
- (void) addWatchRule:(MVChatUserWatchRule *) rule;
- (void) removeWatchRule:(MVChatUserWatchRule *) rule;

@property (nonatomic, copy) NSImage *picture;
@property (readonly, copy) NSString *compositeName;
@property (nonatomic, copy) NSString *firstName;
@property (nonatomic, copy) NSString *lastName;
@property (nonatomic, copy) NSString *primaryEmail;
@property (nonatomic, copy) NSString *givenNickname;
@property (copy) NSString *speechVoice;
@property (readonly, copy) NSString *uniqueIdentifier;

@property (strong) ABPerson *addressBookPersonRecord;
- (void) editInAddressBook;
- (void) viewInAddressBook;

- (NSComparisonResult) availabilityCompare:(JVBuddy *) buddy;
- (NSComparisonResult) firstNameCompare:(JVBuddy *) buddy;
- (NSComparisonResult) lastNameCompare:(JVBuddy *) buddy;
- (NSComparisonResult) serverCompare:(JVBuddy *) buddy;
- (NSComparisonResult) nicknameCompare:(JVBuddy *) buddy;
@end
