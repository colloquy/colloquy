#import <Foundation/Foundation.h>

#import <ChatCore/MVAvailability.h>
#import <ChatCore/MVChatString.h>
#import <ChatCore/MVMessaging.h>


NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, MVChatRoomMode) {
	MVChatRoomNoModes = 0,
	MVChatRoomPrivateMode = 1 << 0,
	MVChatRoomSecretMode = 1 << 1,
	MVChatRoomInviteOnlyMode = 1 << 2,
	MVChatRoomNormalUsersSilencedMode = 1 << 3,
	MVChatRoomOperatorsSilencedMode = 1 << 4,
	MVChatRoomOperatorsOnlySetTopicMode = 1 << 5,
	MVChatRoomNoOutsideMessagesMode = 1 << 6,
	MVChatRoomPassphraseToJoinMode = 1 << 7,
	MVChatRoomLimitNumberOfMembersMode = 1 << 8
};

typedef NS_OPTIONS(NSUInteger, MVChatRoomMemberMode) {
	MVChatRoomMemberNoModes = 0,
	MVChatRoomMemberVoicedMode = 1 << 0,
	MVChatRoomMemberHalfOperatorMode = 1 << 1,
	MVChatRoomMemberOperatorMode = 1 << 2,
	MVChatRoomMemberAdministratorMode = 1 << 3,
	MVChatRoomMemberFounderMode = 1 << 4
};

typedef NS_OPTIONS(NSUInteger, MVChatRoomMemberDisciplineMode) {
	MVChatRoomMemberNoDisciplineModes = 0,
	MVChatRoomMemberDisciplineQuietedMode = 1 << 0
};

COLLOQUY_EXPORT extern NSString *MVChatRoomMemberQuietedFeature;
COLLOQUY_EXPORT extern NSString *MVChatRoomMemberVoicedFeature;
COLLOQUY_EXPORT extern NSString *MVChatRoomMemberHalfOperatorFeature;
COLLOQUY_EXPORT extern NSString *MVChatRoomMemberOperatorFeature;
COLLOQUY_EXPORT extern NSString *MVChatRoomMemberAdministratorFeature;
COLLOQUY_EXPORT extern NSString *MVChatRoomMemberFounderFeature;

COLLOQUY_EXPORT extern NSString *MVChatRoomJoinedNotification;
COLLOQUY_EXPORT extern NSString *MVChatRoomPartedNotification;
COLLOQUY_EXPORT extern NSString *MVChatRoomKickedNotification;
COLLOQUY_EXPORT extern NSString *MVChatRoomInvitedNotification;

COLLOQUY_EXPORT extern NSString *MVChatRoomMemberUsersSyncedNotification;
COLLOQUY_EXPORT extern NSString *MVChatRoomBannedUsersSyncedNotification;

COLLOQUY_EXPORT extern NSString *MVChatRoomUserJoinedNotification;
COLLOQUY_EXPORT extern NSString *MVChatRoomUserPartedNotification;
COLLOQUY_EXPORT extern NSString *MVChatRoomUserKickedNotification;
COLLOQUY_EXPORT extern NSString *MVChatRoomUserBannedNotification;
COLLOQUY_EXPORT extern NSString *MVChatRoomUserBanRemovedNotification;
COLLOQUY_EXPORT extern NSString *MVChatRoomUserModeChangedNotification;
COLLOQUY_EXPORT extern NSString *MVChatRoomUserBrickedNotification;

COLLOQUY_EXPORT extern NSString *MVChatRoomGotMessageNotification;
COLLOQUY_EXPORT extern NSString *MVChatRoomTopicChangedNotification;
COLLOQUY_EXPORT extern NSString *MVChatRoomModesChangedNotification;
COLLOQUY_EXPORT extern NSString *MVChatRoomAttributeUpdatedNotification;

@class MVChatConnection;
@class MVChatUser;

COLLOQUY_EXPORT
@interface MVChatRoom : NSObject <MVMessaging> {
@protected
	__weak MVChatConnection *_connection;
	id _uniqueIdentifier;
	NSString *_name;
	NSDate *_dateJoined;
	NSDate *_dateParted;
	NSDate *_mostRecentUserActivity;
	NSData *_topic;
	MVChatUser *_topicAuthor;
	NSDate *_dateTopicChanged;
	NSMutableDictionary *_attributes;
	NSMutableSet *_memberUsers;
	NSMutableSet *_bannedUsers;
	NSMutableDictionary *_modeAttributes;
	NSMutableDictionary *_memberModes;
	NSMutableDictionary *_disciplineMemberModes;
	NSStringEncoding _encoding;
	NSUInteger _modes;
	NSUInteger _hash;
	BOOL _releasing;
}
@property(weak, nullable, readonly) MVChatConnection *connection;

@property(strong, readonly, nullable) NSURL *url;
@property(strong, readonly) NSString *name;
@property(strong, readonly) NSString *displayName;
@property(strong, readonly) id uniqueIdentifier;

@property(readonly, getter=isJoined) BOOL joined;
@property(strong, readonly) NSDate *dateJoined;
@property(strong, readonly) NSDate *dateParted;
@property(nonatomic, copy) NSDate *mostRecentUserActivity;

@property NSStringEncoding encoding;

@property(copy, readonly) NSData *topic;
@property(strong, readonly) MVChatUser *topicAuthor;
@property(copy, readonly) NSDate *dateTopicChanged;

@property(strong, readonly) NSSet<NSString*> *supportedAttributes;
@property(strong, readonly) NSDictionary *attributes;

@property(readonly) NSUInteger supportedModes;
@property(readonly) NSUInteger supportedMemberUserModes;
@property(readonly) NSUInteger supportedMemberDisciplineModes;
@property(readonly) NSUInteger modes;

@property(strong, readonly) MVChatUser *localMemberUser;
@property(strong, readonly) NSSet<MVChatUser*> *memberUsers;
@property(strong, readonly) NSSet<MVChatUser*> *bannedUsers;

- (BOOL) isEqual:(nullable id) object;
- (BOOL) isEqualToChatRoom:(MVChatRoom *) anotherUser;

- (NSComparisonResult) compare:(MVChatRoom *) otherRoom;
- (NSComparisonResult) compareByUserCount:(MVChatRoom *) otherRoom;

- (void) join;
- (void) part;

- (void) partWithReason:(MVChatString * __nullable) reason;

- (void) changeTopic:(MVChatString *) topic;

- (void) sendMessage:(MVChatString *) message asAction:(BOOL) action;
- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action;
- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding withAttributes:(NSDictionary<NSString*,id> *) attributes;

- (void) sendCommand:(NSString *) command withArguments:(MVChatString *) arguments;
- (void) sendCommand:(NSString *) command withArguments:(MVChatString *) arguments withEncoding:(NSStringEncoding) encoding;

- (void) sendSubcodeRequest:(NSString *) command withArguments:(id) arguments;
- (void) sendSubcodeReply:(NSString *) command withArguments:(id) arguments;

- (void) refreshAttributes;
- (void) refreshAttributeForKey:(NSString *) key;

- (BOOL) hasAttributeForKey:(NSString *) key;
- (id __nullable) attributeForKey:(NSString *) key;
- (void) setAttribute:(id __nullable) attribute forKey:(id) key;

- (id) attributeForMode:(MVChatRoomMode) mode;

- (void) setModes:(NSUInteger) modes;
- (void) setMode:(MVChatRoomMode) mode;
- (void) setMode:(MVChatRoomMode) mode withAttribute:(id __nullable) attribute;
- (void) removeMode:(MVChatRoomMode) mode;

- (NSSet<MVChatUser*> *) memberUsersWithModes:(NSUInteger) modes;
- (nullable NSSet<MVChatUser*> *) memberUsersWithNickname:(NSString *) nickname;
- (NSSet<MVChatUser*> *) memberUsersWithFingerprint:(NSString *) fingerprint;
- (MVChatUser *__nullable) memberUserWithUniqueIdentifier:(id) identifier;
- (BOOL) hasUser:(MVChatUser *) user;

- (void) kickOutMemberUser:(MVChatUser *) user forReason:(MVChatString * __nullable) reason;

- (void) addBanForUser:(MVChatUser *) user;
- (void) removeBanForUser:(MVChatUser *) user;

- (NSUInteger) modesForMemberUser:(MVChatUser *) user;
- (NSUInteger) disciplineModesForMemberUser:(MVChatUser *) user;

- (void) setModes:(NSUInteger) modes forMemberUser:(MVChatUser *) user;
- (void) setMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user;
- (void) removeMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user;

- (void) setDisciplineMode:(MVChatRoomMemberDisciplineMode) mode forMemberUser:(MVChatUser *) user;
- (void) removeDisciplineMode:(MVChatRoomMemberDisciplineMode) mode forMemberUser:(MVChatUser *) user;

- (void) requestRecentActivity;
- (void) persistLastActivityDate;
@end

#pragma mark -

#if ENABLE(SCRIPTING)
@interface MVChatRoom (MVChatRoomScripting)
@property(readonly) NSString *scriptUniqueIdentifier;
@property(readonly) NSScriptObjectSpecifier *objectSpecifier;
@end
#endif

NS_ASSUME_NONNULL_END
