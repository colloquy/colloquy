#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>

extern NSString *JVBuddyCameOnlineNotification;
extern NSString *JVBuddyWentOfflineNotification;

extern NSString *JVBuddyNicknameCameOnlineNotification;
extern NSString *JVBuddyNicknameWentOfflineNotification;
extern NSString *JVBuddyNicknameStatusChangedNotification;

extern NSString *JVBuddyActiveNicknameChangedNotification;

@class ABPerson;
@class NSMutableSet;
@class NSMutableDictionary;
@class NSURL;
@class NSString;
@class NSImage;
@class NSSet;

typedef enum {
	JVBuddyOfflineStatus = 0,
	JVBuddyAvailableStatus,
	JVBuddyIdleStatus,
	JVBuddyAwayStatus
} JVBuddyStatus;

typedef enum {
	JVBuddyActiveNickname = 0x0,
	JVBuddyGivenNickname = 0x1,
	JVBuddyFullName = 0x2
} JVBuddyName;

@interface JVBuddy : NSObject {
	ABPerson *_person;
	NSMutableSet *_nicknames;
	NSMutableSet *_onlineNicknames;
	NSMutableDictionary *_nicknameStatus;
	NSURL *_activeNickname;
}
+ (JVBuddyName) preferredName;
+ (void) setPreferredName:(JVBuddyName) preferred;

+ (id) buddyWithPerson:(ABPerson *) person;
+ (id) buddyWithUniqueIdentifier:(NSString *) identifier;

- (id) initWithPerson:(ABPerson *) person;

- (void) registerWithApplicableConnections;

- (NSURL *) activeNickname;
- (void) setActiveNickname:(NSURL *) nickname;

- (JVBuddyStatus) status;
- (BOOL) isOnline;
- (NSTimeInterval) idleTime;
- (NSString *) awayMessage;

- (NSSet *) nicknames;
- (NSSet *) onlineNicknames;

- (void) addNickname:(NSURL *) nickname;
- (void) removeNickname:(NSURL *) nickname;
- (void) replaceNickname:(NSURL *) old withNickname:(NSURL *) new;

- (NSImage *) picture;

- (NSString *) preferredName;
- (JVBuddyName) preferredNameWillReturn;
- (unsigned int) availableNames;

- (NSString *) compositeName;
- (NSString *) firstName;
- (NSString *) lastName;
- (NSString *) primaryEmail;
- (NSString *) givenNickname;

- (NSString *) uniqueIdentifier;

- (NSComparisonResult) availabilityCompare:(JVBuddy *) buddy;
- (NSComparisonResult) firstNameCompare:(JVBuddy *) buddy;
- (NSComparisonResult) lastNameCompare:(JVBuddy *) buddy;
- (NSComparisonResult) serverCompare:(JVBuddy *) buddy;
- (NSComparisonResult) nicknameCompare:(JVBuddy *) buddy;
@end
