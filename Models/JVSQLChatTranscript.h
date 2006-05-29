#import "JVChatTranscript.h"
#import <sqlite3.h>

@interface JVSQLChatTranscript : JVChatTranscript {
	sqlite3 *_database;
	unsigned long long _currentContext;
	unsigned long long _currentSession;
}
@end
