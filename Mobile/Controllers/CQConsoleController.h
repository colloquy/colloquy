#import "CQDirectChatController.h"

#import "MVDelegateLogger.h"

@class MVChatConnection;

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
