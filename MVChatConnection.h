#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#define MVURLEncodeString(t) ((NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)(t), NULL, CFSTR(",;:/?@&$=|^~`\{}[]"), kCFStringEncodingUTF8))
#define MVURLDecodeString(t) ((NSString *)CFURLCreateStringByReplacingPercentEscapes(NULL, (CFStringRef)(t), NULL))

typedef enum {
	MVChatConnectionDisconnectedStatus = 'disC',
	MVChatConnectionConnectingStatus = 'conG',
	MVChatConnectionConnectedStatus = 'conD',
	MVChatConnectionSuspendedStatus = 'susP'
} MVChatConnectionStatus;

typedef enum {
	MVChatConnectionNoProxy = 'nonE',
	MVChatConnectionHTTPSProxy = 'htpS',
	MVChatConnectionSOCKSProxy = 'sokS'
} MVChatConnectionProxy;

typedef enum {
	MVChatRoomNoModes = 0x0,
	MVChatRoomPrivateMode = 0x1,
	MVChatRoomSecretMode = 0x2,
	MVChatRoomInviteOnlyMode = 0x4,
	MVChatRoomModeratedMode = 0x8,
	MVChatRoomSetTopicOperatorOnlyMode = 0x10,
	MVChatRoomNoOutsideMessagesMode = 0x20,
	MVChatRoomPasswordRequiredMode = 0x40,
	MVChatRoomMemberLimitMode = 0x80
} MVChatRoomMode;

typedef enum {
	MVChatNoError,
	MVChatConnectingError,
	MVChatNoMatchError,
	MVChatPacketError,
	MVChatBadUserPasswordError,
	MVChatSequenceError,
	MVChatFrameTypeError,
	MVChatPacketSizeError,
	MVChatServerError,
	MVChatUnknownError,
	MVChatBlockedError,
	MVChatWiredPacketError,
	MVChatCallbackNumberError,
	MVChatBadTargetError,
	MVChatNotFoundError,
	MVChatDisconnectError,
	MVChatSocketError,
	MVChatDNSError,
	MVChatVersionError,
	MVChatUserUnavailableError,
	MVChatUserInfoUnavailableError,
	MVChatTooFastError,
	MVChatRoomUnavailableError,
	MVChatIncomingError,
	MVChatUserDisconnectError,
	MVChatInvalidFormatError,
	MVChatIdleFastError,
	MVChatBadRoomError,
	MVChatBadMessageError,
	MVChatBadPrototypeError,
	MVChatNotConnectedError,
	MVChatBadConnectionError,
	MVChatNoPermissionsError,
	MVChatNoChangePasswordError,
	MVChatDuplicateUserError,
	MVChatDuplicateRoomError,
	MVChatIOError,
	MVChatBadHandleError,
	MVChatTimeoutError,
	MVChatNotDoneError
} MVChatError;

extern NSString *MVChatConnectionGotRawMessageNotification;

extern NSString *MVChatConnectionWillConnectNotification;
extern NSString *MVChatConnectionDidConnectNotification;
extern NSString *MVChatConnectionDidNotConnectNotification;
extern NSString *MVChatConnectionWillDisconnectNotification;
extern NSString *MVChatConnectionDidDisconnectNotification;
extern NSString *MVChatConnectionErrorNotification;

extern NSString *MVChatConnectionNeedPasswordNotification;

extern NSString *MVChatConnectionGotPrivateMessageNotification;

extern NSString *MVChatConnectionBuddyIsOnlineNotification;
extern NSString *MVChatConnectionBuddyIsOfflineNotification;
extern NSString *MVChatConnectionBuddyIsAwayNotification;
extern NSString *MVChatConnectionBuddyIsUnawayNotification;
extern NSString *MVChatConnectionBuddyIsIdleNotification;

extern NSString *MVChatConnectionGotUserInfoNotification;
extern NSString *MVChatConnectionGotRoomInfoNotification;

extern NSString *MVChatConnectionJoinedRoomNotification;
extern NSString *MVChatConnectionLeftRoomNotification;
extern NSString *MVChatConnectionUserJoinedRoomNotification;
extern NSString *MVChatConnectionUserLeftRoomNotification;
extern NSString *MVChatConnectionUserNicknameChangedNotification;
extern NSString *MVChatConnectionUserOppedInRoomNotification;
extern NSString *MVChatConnectionUserDeoppedInRoomNotification;
extern NSString *MVChatConnectionUserVoicedInRoomNotification;
extern NSString *MVChatConnectionUserDevoicedInRoomNotification;
extern NSString *MVChatConnectionUserKickedFromRoomNotification;
extern NSString *MVChatConnectionUserAwayStatusNotification;
extern NSString *MVChatConnectionGotRoomModeNotification;
extern NSString *MVChatConnectionGotRoomMessageNotification;
extern NSString *MVChatConnectionGotRoomTopicNotification;

extern NSString *MVChatConnectionKickedFromRoomNotification;
extern NSString *MVChatConnectionInvitedToRoomNotification;

extern NSString *MVChatConnectionNicknameAcceptedNotification;
extern NSString *MVChatConnectionNicknameRejectedNotification;

extern NSString *MVChatConnectionFileTransferAvailableNotification;
extern NSString *MVChatConnectionFileTransferOfferedNotification;
extern NSString *MVChatConnectionFileTransferStartedNotification;
extern NSString *MVChatConnectionFileTransferFinishedNotification;
extern NSString *MVChatConnectionFileTransferErrorNotification;
extern NSString *MVChatConnectionFileTransferStatusNotification;

extern NSString *MVChatConnectionSubcodeRequestNotification;
extern NSString *MVChatConnectionSubcodeReplyNotification;

@class NSTimer;
@class NSMutableArray;
@class NSMutableDictionary;
@class NSDictionary;
@class NSAttributedString;

@interface MVChatConnection : NSObject {
@private
	NSString *_nickname;
	NSString *_npassword;
	NSString *_password;
	NSString *_server;
	unsigned short _port;
	MVChatConnectionStatus _status;
	MVChatConnectionProxy _proxy;
	void *_chatConnection;
	NSTimer *_firetalkSelectTimer;
	NSMutableArray *_joinList;
	NSMutableDictionary *_roomsCache;
	NSDate *_cachedDate;
	NSTimeInterval _backlogDelay;
	NSDictionary *_floodIntervals;
	unsigned int /* io_object_t */ _sleepNotifier;
	unsigned int /* io_connect_t */ _powerConnection;
}
+ (void) setFileTransferPortRange:(NSRange) range;
+ (NSRange) fileTransferPortRange;

+ (NSString *) descriptionForError:(MVChatError) error;

- (id) initWithURL:(NSURL *) url;
- (id) initWithServer:(NSString *) server port:(unsigned short) port user:(NSString *) nickname;

- (void) connect;
- (void) connectToServer:(NSString *) server onPort:(unsigned short) port asUser:(NSString *) nickname;
- (void) disconnect;

- (NSURL *) url;

- (void) setNickname:(NSString *) nickname;
- (NSString *) nickname;

- (void) setNicknamePassword:(NSString *) password;
- (NSString *) nicknamePassword;

- (void) setPassword:(NSString *) password;
- (NSString *) password;

- (void) setServer:(NSString *) server;
- (NSString *) server;

- (void) setServerPort:(unsigned short) port;
- (unsigned short) serverPort;

- (void) setProxyType:(MVChatConnectionProxy) type;
- (MVChatConnectionProxy) proxyType;

- (NSDictionary *) floodControlIntervals;
- (void) setFloodControlIntervals:(NSDictionary *) intervals;
	
- (void) sendMessageToUser:(NSString *) user attributedMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action;
- (void) sendMessageToChatRoom:(NSString *) room attributedMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding asAction:(BOOL) action;

- (void) sendRawMessage:(NSString *) raw;

- (void) sendFileToUser:(NSString *) user withFilePath:(NSString *) path;
- (void) acceptFileTransfer:(NSString *) identifier saveToPath:(NSString *) path resume:(BOOL) resume;
- (void) cancelFileTransfer:(NSString *) identifier;

- (void) sendSubcodeRequest:(NSString *) command toUser:(NSString *) user withArguments:(NSString *) arguments;
- (void) sendSubcodeReply:(NSString *) command toUser:(NSString *) user withArguments:(NSString *) arguments;

- (void) joinChatRooms:(NSArray *) rooms;
- (void) joinChatForRoom:(NSString *) room;
- (void) partChatForRoom:(NSString *) room;

- (void) setTopic:(NSAttributedString *) topic withEncoding:(NSStringEncoding) encoding forRoom:(NSString *) room;

- (void) promoteMember:(NSString *) member inRoom:(NSString *) room;
- (void) demoteMember:(NSString *) member inRoom:(NSString *) room;
- (void) voiceMember:(NSString *) member inRoom:(NSString *) room;
- (void) devoiceMember:(NSString *) member inRoom:(NSString *) room;
- (void) kickMember:(NSString *) member inRoom:(NSString *) room forReason:(NSString *) reason;

- (void) addUserToNotificationList:(NSString *) user;
- (void) removeUserFromNotificationList:(NSString *) user;

- (void) fetchInformationForUser:(NSString *) user withPriority:(BOOL) priority;

- (void) fetchRoomList;
- (void) fetchRoomListWithRooms:(NSArray *) rooms;
- (void) stopFetchingRoomList;
- (NSDictionary *) roomListResults;

- (void) setAwayStatusWithMessage:(NSString *) message;
- (void) clearAwayStatus;

- (BOOL) isConnected;
- (MVChatConnectionStatus) status;
@end

@interface NSURL (NSURLChatAdditions)
- (BOOL) isChatURL;
- (BOOL) isChatRoomURL;
- (BOOL) isDirectChatURL;
@end
