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
	MVChatRoomMemberOperatorMode = 1 << 2,
	MVChatRoomMemberFounderMode = 1 << 3
} MVChatRoomMemberMode;

extern NSString *MVChatRoomJoinedNotification;
extern NSString *MVChatRoomPartedNotification;
extern NSString *MVChatRoomKickedNotification;
extern NSString *MVChatRoomInvitedNotification;

extern NSString *MVChatRoomUserJoinedNotification;
extern NSString *MVChatRoomUserPartedNotification;
extern NSString *MVChatRoomUserKickedNotification;
extern NSString *MVChatRoomUserBannedNotification;
extern NSString *MVChatRoomUserBanRemovedNotification;
extern NSString *MVChatRoomUserModeChangedNotification;

extern NSString *MVChatRoomGotMessageNotification;
extern NSString *MVChatRoomTopicChangedNotification;
extern NSString *MVChatRoomModeChangedNotification;
extern NSString *MVChatRoomAttributesUpdatedNotification;

@class MVChatConnection;
@class MVChatUser;

@interface MVChatRoom : NSObject {
@protected
	MVChatConnection *_connection;
	NSString *_name;
	NSDate *_dateJoined;
	NSDate *_dateParted;
	NSData *_topicData;
	MVChatUser *_topicAuthor;
	NSDate *_dateTopicChanged;
	NSMutableDictionary *_attributes;
	NSMutableSet *_memberUsers;
	NSMutableSet *_bannedUsers;
	NSMutableDictionary *_modeAttributes;
	NSMutableDictionary *_memberModes;
	NSStringEncoding _encoding;
	unsigned long _modes;
}
- (MVChatConnection *) connection;

- (BOOL) isEqual:(id) object;
- (BOOL) isEqualToChatRoom:(MVChatRoom *) anotherUser;
- (unsigned) hash;

- (NSComparisonResult) compare:(MVChatRoom *) otherRoom;
- (NSComparisonResult) compareByUserCount:(MVChatRoom *) otherRoom;

- (NSURL *) url;
- (NSString *) name;
- (NSString *) displayName;
- (id) uniqueIdentifier;

- (void) join;
- (void) part;
- (void) partWithReason:(NSAttributedString *) reason;

- (BOOL) isJoined;
- (NSDate *) dateJoined;
- (NSDate *) dateParted;

- (NSStringEncoding) encoding;
- (void) setEncoding:(NSStringEncoding) encoding;

- (void) sendMessage:(NSAttributedString *) message asAction:(BOOL) action;

- (void) sendSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments;
- (void) sendSubcodeReply:(NSString *) command withArguments:(NSString *) arguments;

- (NSData *) topic;
- (MVChatUser *) topicAuthor;
- (void) setTopic:(NSAttributedString *) topic;

- (void) refreshAttributes;
- (void) refreshAttributeForKey:(NSString *) key;

- (NSSet *) supportedAttributes;

- (NSDictionary *) attributes;
- (BOOL) hasAttributeForKey:(NSString *) key;
- (id) attributeForKey:(NSString *) key;

- (unsigned long) supportedModes;

- (unsigned long) modes;
- (id) attributeForMode:(MVChatRoomMode) mode;

- (void) setModes:(unsigned long) modes;
- (void) setMode:(MVChatRoomMode) mode;
- (void) setMode:(MVChatRoomMode) mode withAttribute:(id) attribute;

- (NSSet *) memberUsers;
- (NSSet *) memberUsersWithModes:(unsigned long) modes;
- (NSSet *) memberUsersWithNickname:(NSString *) nickname;
- (NSSet *) memberUsersWithFingerprint:(NSString *) fingerprint;
- (MVChatUser *) memberUserWithUniqueIdentifier:(id) identifier;
- (BOOL) hasUser:(MVChatUser *) user;

- (NSSet *) bannedUsers;
- (void) addBanForUser:(MVChatUser *) user;
- (void) removeBanForUser:(MVChatUser *) user;

- (unsigned long) supportedMemberUserModes;

- (unsigned long) modesForMemberUser:(MVChatUser *) user;

- (void) setModes:(unsigned long) modes forMemberUser:(MVChatUser *) user;
- (void) setMode:(MVChatRoomMemberMode) mode forMemberUser:(MVChatUser *) user;
@end