#import <ChatCore/MVAvailability.h>
#import <ChatCore/MVChatString.h>

typedef enum {
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
} MVChatRoomMode;

typedef enum {
	MVChatRoomMemberNoModes = 0,
	MVChatRoomMemberQuietedMode = 1 << 0,
	MVChatRoomMemberVoicedMode = 1 << 1,
	MVChatRoomMemberHalfOperatorMode = 1 << 2,
	MVChatRoomMemberOperatorMode = 1 << 3,
	MVChatRoomMemberAdministratorMode = 1 << 4,
	MVChatRoomMemberFounderMode = 1 << 5
} MVChatRoomMemberMode;

extern NSString *MVChatRoomMemberQuietedFeature;
extern NSString *MVChatRoomMemberVoicedFeature;
extern NSString *MVChatRoomMemberHalfOperatorFeature;
extern NSString *MVChatRoomMemberOperatorFeature;
extern NSString *MVChatRoomMemberAdministratorFeature;
extern NSString *MVChatRoomMemberFounderFeature;

extern NSString *MVChatRoomJoinedNotification;
extern NSString *MVChatRoomPartedNotification;
extern NSString *MVChatRoomKickedNotification;
extern NSString *MVChatRoomInvitedNotification;

extern NSString *MVChatRoomMemberUsersSyncedNotification;
extern NSString *MVChatRoomBannedUsersSyncedNotification;

extern NSString *MVChatRoomUserJoinedNotification;
extern NSString *MVChatRoomUserPartedNotification;
extern NSString *MVChatRoomUserKickedNotification;
extern NSString *MVChatRoomUserBannedNotification;
extern NSString *MVChatRoomUserBanRemovedNotification;
extern NSString *MVChatRoomUserModeChangedNotification;
extern NSString *MVChatRoomUserBrickedNotification;

extern NSString *MVChatRoomGotMessageNotification;
extern NSString *MVChatRoomTopicChangedNotification;
extern NSString *MVChatRoomModesChangedNotification;
extern NSString *MVChatRoomAttributeUpdatedNotification;

@class MVChatConnection;
@class MVChatUser;

@interface MVChatRoom : NSObject {
@protected
	MVChatConnection *_connection;
	id _uniqueIdentifier;
	NSString *_name;
	NSDate *_dateJoined;
	NSDate *_dateParted;
	NSData *_topic;
	MVChatUser *_topicAuthor;
	NSDate *_dateTopicChanged;
	NSMutableDictionary *_attributes;
	NSMutableSet *_memberUsers;
	NSMutableSet *_bannedUsers;
	NSMutableDictionary *_modeAttributes;
	NSMutableDictionary *_memberModes;
	NSStringEncoding _encoding;
	unsigned long _modes;
	unsigned int _hash;
	BOOL _releasing;
}

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
@property(readonly) MVChatConnection *connection;

@property(readonly) NSURL *url;
@property(readonly) NSString *name;
@property(readonly) NSString *displayName;
@property(readonly) id uniqueIdentifier;

@property(readonly, getter=isJoined) BOOL joined;
@property(readonly) NSDate *dateJoined;
@property(readonly) NSDate *dateParted;

@property NSStringEncoding encoding;

@property(readonly) NSData *topic;
@property(readonly) MVChatUser *topicAuthor;
@property(readonly) NSDate *dateTopicChanged;

@property(readonly) NSSet *supportedAttributes;
@property(readonly) NSDictionary *attributes;

@property(readonly) unsigned long supportedModes;
@property(readonly) unsigned long supportedMemberUserModes;
@property(readonly) unsigned long modes;

@property(readonly) MVChatUser *localMemberUser;
@property(readonly) NSSet *memberUsers;
@property(readonly) NSSet *bannedUsers;

#else

- (MVChatConnection *) connection;

- (NSURL *) url;
- (NSString *) name;
- (NSString *) displayName;
- (id) uniqueIdentifier;

- (NSDate *) dateJoined;
- (NSDate *) dateParted;

- (NSStringEncoding) encoding;
- (void) setEncoding:(NSStringEncoding) encoding;

- (NSData *) topic;
- (MVChatUser *) topicAuthor;
- (NSDate *) dateTopicChanged;

- (NSSet *) supportedAttributes;
- (NSDictionary *) attributes;

- (unsigned long) supportedModes;
- (unsigned long) supportedMemberUserModes;
- (unsigned long) modes;

- (MVChatUser *) localMemberUser;
- (NSSet *) memberUsers;
- (NSSet *) bannedUsers;
#endif

- (BOOL) isEqual:(id) object;
- (BOOL) isEqualToChatRoom:(MVChatRoom *) anotherUser;

- (NSComparisonResult) compare:(MVChatRoom *) otherRoom;
- (NSComparisonResult) compareByUserCount:(MVChatRoom *) otherRoom;

- (BOOL) isJoined;

- (void) join;
- (void) part;

- (void) partWithReason:(MVChatString *) reason;

- (void) setTopic:(MVChatString *) topic;

- (void) sendMessage:(MVChatString *) message asAction:(BOOL) action;
- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action;
- (void) sendMessage:(MVChatString *) message withEncoding:(NSStringEncoding) encoding withAttributes:(NSDictionary *) attributes;

- (void) sendCommand:(NSString *) command withArguments:(MVChatString *) arguments;
- (void) sendCommand:(NSString *) command withArguments:(MVChatString *) arguments withEncoding:(NSStringEncoding) encoding;

- (void) sendSubcodeRequest:(NSString *) command withArguments:(id) arguments;
- (void) sendSubcodeReply:(NSString *) command withArguments:(id) arguments;

- (void) refreshAttributes;
- (void) refreshAttributeForKey:(NSString *) key;

- (BOOL) hasAttributeForKey:(NSString *) key;
- (id) attributeForKey:(NSString *) key;
- (void) setAttribute:(id) attribute forKey:(id) key;

- (id) attributeForMode:(MVChatRoomMode) mode;

- (void) setModes:(unsigned long) modes;
- (void) setMode:(MVChatRoomMode) mode;
- (void) setMode:(MVChatRoomMode) mode withAttribute:(id) attribute;
- (void) removeMode:(MVChatRoomMode) mode;

- (NSSet *) memberUsersWithModes:(unsigned long) modes;
- (NSSet *) memberUsersWithNickname:(NSString *) nickname;
- (NSSet *) memberUsersWithFingerprint:(NSString *) fingerprint;
- (MVChatUser *) memberUserWithUniqueIdentifier:(id) identifier;
- (BOOL) hasUser:(MVChatUser *) user;

- (void) kickOutMemberUser:(MVChatUser *) user forReason:(MVChatString *) reason;

- (void) addBanForUser:(MVChatUser *) user;
- (void) removeBanForUser:(MVChatUser *) user;

- (unsigned long) modesForMemberUser:(MVChatUser *) user;

- (void) setModes:(unsigned long) modes forMemberUser:(MVChatUser *) user;
- (void) setMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user;
- (void) removeMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user;
@end

#pragma mark -

#if ENABLE(SCRIPTING)
@interface MVChatRoom (MVChatRoomScripting)
#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
@property(readonly) NSString *scriptUniqueIdentifier;
@property(readonly) NSScriptObjectSpecifier *objectSpecifier;
#else
- (NSString *) scriptUniqueIdentifier;
- (NSScriptObjectSpecifier *) objectSpecifier;
#endif
@end
#endif
