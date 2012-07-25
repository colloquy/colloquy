#import <sqlite3.h>

@class MVChatRoom;

@interface CQLoggingController : NSObject {
	sqlite3 *_database;
	NSUInteger _sessionIdentifier;
}

+ (CQLoggingController *) loggingController;

// A bunch of strings, unique and 
- (NSArray *) conversationsWithTranscriptsAvailable;

// Array of dictionaries containing start/end dates for sessions, and session identifier.
// A conversation must be either be a MV*ChatUser or MV*ChatRoom object.
- (NSArray *) informationForTranscriptsOfConversation:(id) conversation;

// Array of dictionaries containing all the info needed to make a CQProcessChatMessageOperation.
// A conversation must be either be a MV*ChatUser or MV*ChatRoom object.
- (NSArray *) transcriptForConversation:(id) conversation withSessionIdentifier:(NSUInteger) sessionIdentifier;
@end
