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

@interface JVBuddy : NSObject {
	ABPerson *_person;
	NSMutableSet *_nicknames;
	NSMutableSet *_onlineNicknames;
	NSMutableDictionary *_nicknameStatus;
	NSURL *_activeNickname;
}
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

- (NSImage *) picture;
- (NSString *) compositeName;
- (NSString *) firstName;
- (NSString *) lastName;

- (NSString *) uniqueIdentifier;

- (NSComparisonResult) availabilityCompare:(JVBuddy *) buddy;
- (NSComparisonResult) firstNameCompare:(JVBuddy *) buddy;
- (NSComparisonResult) lastNameCompare:(JVBuddy *) buddy;
- (NSComparisonResult) serverCompare:(JVBuddy *) buddy;
- (NSComparisonResult) nicknameCompare:(JVBuddy *) buddy;
@end
