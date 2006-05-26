#import "JVChatTranscript.h"
#import <sqlite3.h>

@interface JVSQLChatTranscript : JVChatTranscript {
	sqlite3 *_database;
}
@end
