#import "CQLoggingController.h"

#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatUser.h>

#define CQLoggingSaveToDiskInterval 60.

@implementation CQLoggingController {
	BOOL _needsAppending;
}

+ (CQLoggingController *) loggingController {
	static CQLoggingController *loggingController = nil;
	static dispatch_once_t pred;

	dispatch_once(&pred, ^{
		loggingController = [[CQLoggingController alloc] init];
	});

	return loggingController;
}

- (id) init {
	if (!(self = [super init]))
		return nil;

	int error = sqlite3_open("file::memory:?cache=shared", &_database);

	_sessionIdentifier = [[NSUserDefaults standardUserDefaults] integerForKey:@"CQSessionIdentifier"];

	[self performSelector:@selector(appendToDisk) withObject:nil afterDelay:CQLoggingSaveToDiskInterval];

	return self;
}

#pragma mark -

- (void) appendToDisk {
	if (_needsAppending) {
//		attach 'c:\test\b.db3' as toMerge;
//		BEGIN;
//		insert into AuditRecords select * from toMerge.AuditRecords;
//		COMMIT;

		_needsAppending = NO;
	}

	[self performSelector:@selector(appendToDisk) withObject:nil afterDelay:CQLoggingSaveToDiskInterval];
}

#pragma mark -

- (NSArray *) conversationsWithTranscriptsAvailable {
	return nil;
}

- (NSArray *) informationForTranscriptsOfConversation:(id) conversation {
	return nil;
}

- (NSArray *) transcriptForConversation:(id) conversation withSessionIdentifier:(NSUInteger) sessionIdentifier {
	return nil;
}

#pragma mark -


@end
