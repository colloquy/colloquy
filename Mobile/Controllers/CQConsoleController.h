#import "CQDirectChatController.h"

#import "MVDelegateLogger.h"

@class MVChatConnection;

BOOL defaultForServer(NSString *defaultName, NSString *serverName);

extern NSString *const CQConsoleHideNickKey;
extern NSString *const CQConsoleHideTrafficKey; // JOIN, PART, KICK, INVITE
extern NSString *const CQConsoleHideTopicKey;
extern NSString *const CQConsoleHideMessagesKey; // PRIVMSG, NOTICE
extern NSString *const CQConsoleHideModeKey;
extern NSString *const CQConsoleHideNumericKey; // includes IRCv3 commands such as CAP and AUTHENTICATE
extern NSString *const CQConsoleHideUnknownKey; // WALLOP, OLINEs, etc
extern NSString *const CQConsoleHideCtcpKey;
extern NSString *const CQConsoleHidePingKey;
extern NSString *const CQConsoleHideSocketKey;

@interface CQConsoleController : CQDirectChatController <MVLoggingDelegate> {
@private
	MVChatConnection *_connection;

	BOOL _hideNICKs;
	BOOL _hideTraffic; // JOIN, PART, KICK, INVITE
	BOOL _hideTOPICs;
	BOOL _hideMessages; // PRIVMSG, NOTICE
	BOOL _hideMODEs;
	BOOL _hideNumerics; // includes IRCv3 commands such as CAP and AUTHENTICATE
	BOOL _hideUnknown; // WALLOP, OLINEs, etc
	BOOL _hideCTCPs;
	BOOL _hidePINGs;
	BOOL _hideSocketInformation;

	MVDelegateLogger *_delegateLogger;
}
@end
