#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSString.h>
#import <Foundation/NSURL.h>

#define MVURLEncodeString(t) ([(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)(t), NULL, CFSTR(",;:/?@&$=|^~`\{}[]"), kCFStringEncodingUTF8) autorelease])
#define MVURLDecodeString(t) ([(NSString *)CFURLCreateStringByReplacingPercentEscapes(NULL, (CFStringRef)(t), NULL) autorelease])

typedef enum {
	MVChatConnectionDisconnectedStatus			= 'disC',
	MVChatConnectionServerDisconnectedStatus	= 'sdsC',
	MVChatConnectionConnectingStatus			= 'conG',
	MVChatConnectionConnectedStatus				= 'conD',
	MVChatConnectionSuspendedStatus				= 'susP'
} MVChatConnectionStatus;

typedef enum {
	MVChatConnectionNoProxy		= 'nonE',
	MVChatConnectionHTTPSProxy  = 'htpS',
	MVChatConnectionSOCKSProxy  = 'sokS'
} MVChatConnectionProxy;

typedef enum {
	MVChatRoomNoModes					= 0x0,
	MVChatRoomPrivateMode				= 0x1,
	MVChatRoomSecretMode				= 0x2,
	MVChatRoomInviteOnlyMode			= 0x4,
	MVChatRoomModeratedMode				= 0x8,
	MVChatRoomSetTopicOperatorOnlyMode  = 0x10,
	MVChatRoomNoOutsideMessagesMode		= 0x20,
	MVChatRoomPasswordRequiredMode		= 0x40,
	MVChatRoomMemberLimitMode			= 0x80
} MVChatRoomMode;

typedef enum {
	MVChatMemberNoModes				= 0x0,
	MVChatMemberOperatorMode		= 0x1,
	MVChatMemberHalfOperatorMode	= 0x2,
	MVChatMemberVoiceMode			= 0x4
} MVChatMemberMode;

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

extern NSString *MVChatConnectionNeedNicknamePasswordNotification;

extern NSString *MVChatConnectionGotPrivateMessageNotification;

extern NSString *MVChatConnectionBuddyIsOnlineNotification;
extern NSString *MVChatConnectionBuddyIsOfflineNotification;
extern NSString *MVChatConnectionBuddyIsAwayNotification;
extern NSString *MVChatConnectionBuddyIsUnawayNotification;
extern NSString *MVChatConnectionBuddyIsIdleNotification;

extern NSString *MVChatConnectionSelfAwayStatusNotification;

extern NSString *MVChatConnectionGotUserWhoisNotification;
extern NSString *MVChatConnectionGotUserServerNotification;
extern NSString *MVChatConnectionGotUserChannelsNotification;
extern NSString *MVChatConnectionGotUserOperatorNotification;
extern NSString *MVChatConnectionGotUserIdleNotification;
extern NSString *MVChatConnectionGotUserWhoisCompleteNotification;

extern NSString *MVChatConnectionGotRoomInfoNotification;

extern NSString *MVChatConnectionRoomExistingMemberListNotification;
extern NSString *MVChatConnectionJoinedRoomNotification;
extern NSString *MVChatConnectionLeftRoomNotification;
extern NSString *MVChatConnectionUserJoinedRoomNotification;
extern NSString *MVChatConnectionUserLeftRoomNotification;
extern NSString *MVChatConnectionUserQuitNotification;
extern NSString *MVChatConnectionUserNicknameChangedNotification;
extern NSString *MVChatConnectionUserKickedFromRoomNotification;
extern NSString *MVChatConnectionUserAwayStatusNotification;
extern NSString *MVChatConnectionGotMemberModeNotification;
extern NSString *MVChatConnectionGotRoomModeNotification;
extern NSString *MVChatConnectionGotRoomMessageNotification;
extern NSString *MVChatConnectionGotRoomTopicNotification;

extern NSString *MVChatConnectionNewBanNotification;
extern NSString *MVChatConnectionRemovedBanNotification;
extern NSString *MVChatConnectionBanlistReceivedNotification;

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
	NSString				*_npassword;
	MVChatConnectionStatus  _status;
	MVChatConnectionProxy   _proxy;
	
	void					*_chatConnection;
	NSMutableDictionary		*_roomsCache;
	NSDate					*_cachedDate;
	NSAttributedString		*_awayMessage;
	
	BOOL					_nickIdentified;
	unsigned int			_sleepNotifier;		/* io_object_t */
	unsigned int			_powerConnection;   /* io_connect_t */
}

+ (void) setFileTransferPortRange:(NSRange) range;
+ (NSRange) fileTransferPortRange;

+ (NSString *) descriptionForError:(MVChatError) error;

#pragma mark -

- (id) initWithURL:(NSURL *) url;
- (id) initWithServer:(NSString *) server port:(unsigned short) port user:(NSString *) nickname;

- (void) connect;
- (void) connectToServer:(NSString *) server onPort:(unsigned short) port asUser:(NSString *) nickname;
- (void) disconnect;

#pragma mark -

- (NSURL *) url;

#pragma mark -

- (void) setRealName:(NSString *) name;
- (NSString *) realName;

- (void) setNickname:(NSString *) nickname;
- (NSString *) nickname;
- (NSString *) preferredNickname;

- (void) setNicknamePassword:(NSString *) password;
- (NSString *) nicknamePassword;

- (void) setPassword:(NSString *) password;
- (NSString *) password;

- (void) setUsername:(NSString *) username;
- (NSString *) username;

- (void) setServer:(NSString *) server;
- (NSString *) server;

- (void) setServerPort:(unsigned short) port;
- (unsigned short) serverPort;

- (void) setProxyType:(MVChatConnectionProxy) type;
- (MVChatConnectionProxy) proxyType;

#pragma mark -

- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding toUser:(NSString *) user asAction:(BOOL) action;
- (void) sendMessage:(NSAttributedString *) message withEncoding:(NSStringEncoding) encoding toChatRoom:(NSString *) room asAction:(BOOL) action;

- (void) sendRawMessage:(NSString *) raw;
- (void) sendRawMessage:(NSString *) raw immediately:(BOOL) now;
- (void) sendRawMessageWithFormat:(NSString *) format, ...;

#pragma mark -

- (void) sendFile:(NSString *) path toUser:(NSString *) user;
- (void) acceptFileTransfer:(NSString *) identifier saveToPath:(NSString *) path resume:(BOOL) resume;
- (void) cancelFileTransfer:(NSString *) identifier;

#pragma mark -

- (void) sendSubcodeRequest:(NSString *) command toUser:(NSString *) user withArguments:(NSString *) arguments;
- (void) sendSubcodeReply:(NSString *) command toUser:(NSString *) user withArguments:(NSString *) arguments;

#pragma mark -

- (void) joinChatRooms:(NSArray *) rooms;
- (void) joinChatRoom:(NSString *) room;
- (void) partChatRoom:(NSString *) room;

#pragma mark -

- (void) setTopic:(NSAttributedString *) topic withEncoding:(NSStringEncoding) encoding forRoom:(NSString *) room;

- (void) promoteMember:(NSString *) member inRoom:(NSString *) room;
- (void) demoteMember:(NSString *) member inRoom:(NSString *) room;
- (void) halfopMember:(NSString *) member inRoom:(NSString *) room;
- (void) dehalfopMember:(NSString *) member inRoom:(NSString *) room;
- (void) voiceMember:(NSString *) member inRoom:(NSString *) room;
- (void) devoiceMember:(NSString *) member inRoom:(NSString *) room;
- (void) kickMember:(NSString *) member inRoom:(NSString *) room forReason:(NSString *) reason;
- (void) banMember:(NSString *) member inRoom:(NSString *) room;
- (void) unbanMember:(NSString *) member inRoom:(NSString *) room;

#pragma mark -

- (void) addUserToNotificationList:(NSString *) user;
- (void) removeUserFromNotificationList:(NSString *) user;

- (void) fetchInformationForUser:(NSString *) user withPriority:(BOOL) priority fromLocalServer:(BOOL) localOnly;

#pragma mark -

- (void) fetchRoomList;
- (void) fetchRoomListWithRooms:(NSArray *) rooms;
- (void) stopFetchingRoomList;
- (NSMutableDictionary *) roomListResults;

#pragma mark -

- (NSAttributedString *) awayStatusMessage;
- (void) setAwayStatusWithMessage:(NSAttributedString *) message;
- (void) clearAwayStatus;

#pragma mark -

- (BOOL) isConnected;
- (MVChatConnectionStatus) status;
- (BOOL) waitingToReconnect;
- (unsigned int) lag;
@end

@interface MVChatConnection (MVChatConnectionScripting)
- (NSNumber *) uniqueIdentifier;
@end

@interface NSObject (MVChatPluginConnectionSupport)
- (BOOL) processSubcodeRequest:(NSString *) command withArguments:(NSString *) arguments fromUser:(NSString *) user forConnection:(MVChatConnection *) connection;
- (BOOL) processSubcodeReply:(NSString *) command withArguments:(NSString *) arguments fromUser:(NSString *) user forConnection:(MVChatConnection *) connection;

- (void) connected:(MVChatConnection *) connection;
- (void) disconnecting:(MVChatConnection *) connection;
@end

@interface NSURL (NSURLChatAdditions)
- (BOOL) isChatURL;
- (BOOL) isChatRoomURL;
- (BOOL) isDirectChatURL;
@end