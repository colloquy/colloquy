#import "CQIgnoreRulesController.h"

#import "KAIgnoreRule.h"

#import "NSNotificationAdditions.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatString.h>
#import <ChatCore/MVChatUser.h>

NSString *const CQIgnoreRulesNotSavedNotification = @"CQIgnoreRulesNotSavedNotification";

@implementation CQIgnoreRulesController
- (id) initWithConnection:(MVChatConnection *) connection {
	if (!(self = [super init]))
		return nil;

	_connection = [connection retain];
	_ignoreRules = [[NSMutableArray alloc] init];

	for (NSData *data in [NSKeyedUnarchiver unarchiveObjectWithFile:self._ignoreFilePath])
		[_ignoreRules addObject:[NSKeyedUnarchiver unarchiveObjectWithData:data]];

	return self;
}

- (void) dealloc {
	[_connection release];
	[_ignoreRules release];
	[_appSupportPath release];

	[super dealloc];
}

#pragma mark -

- (NSArray *) ignoreRules {
	return [[_ignoreRules copy] autorelease];
}

#pragma mark -

- (void) addIgnoreRule:(KAIgnoreRule *) ignoreRule {
	for (KAIgnoreRule *rule in _ignoreRules)
		if ([rule isEqual:ignoreRule])
			return;

	[_ignoreRules addObject:ignoreRule];

	if (ignoreRule.isPermanent)
		[self synchronizeSoon];
}

- (void) removeIgnoreRule:(KAIgnoreRule *) ignoreRule {
	[_ignoreRules removeObject:ignoreRule];

	if (ignoreRule.isPermanent)
		[self synchronizeSoon];
}

- (void) removeIgnoreRuleFromString:(NSString *) ignoreRuleString {
	BOOL permanentIgnoreRuleWasRemoved = NO;

	for (KAIgnoreRule *rule in [[_ignoreRules copy] autorelease]) {
		if ([rule.user isEqualToString:ignoreRuleString] || [rule.mask isEqualToString:ignoreRuleString] || [rule.message isEqualToString:ignoreRuleString]) {
			[_ignoreRules removeObject:rule];

			if (rule.isPermanent)
				permanentIgnoreRuleWasRemoved = YES;
		}
	}

	if (permanentIgnoreRuleWasRemoved)
		[self synchronizeSoon];
}

#pragma mark -

- (BOOL) hasIgnoreRuleForUser:(MVChatUser *) user {
	for (KAIgnoreRule *rule in _ignoreRules)
		if ([rule.user isEqualToString:user.nickname])
			return YES;
	return NO;
}

- (BOOL) shouldIgnoreMessage:(id) message fromUser:(MVChatUser *) user inRoom:(MVChatRoom *) room {
	for (KAIgnoreRule *rule in _ignoreRules)
		if ([rule matchUser:user message:message inTargetRoom:room] != JVNotIgnored)
			return YES;
	return NO;
}

#pragma mark -

- (void) synchronizeSoon {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(synchronize) object:nil];
	[self performSelector:@selector(synchronize) withObject:nil afterDelay:.25];
}

- (void) synchronize {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(synchronize) object:nil];

	NSMutableArray *permanentIgnores = [NSMutableArray array];

	for (KAIgnoreRule *rule in _ignoreRules)
		if (rule.isPermanent)
			[permanentIgnores addObject:[NSKeyedArchiver archivedDataWithRootObject:rule]];

	if (!permanentIgnores.count) {
		[[NSFileManager defaultManager] removeItemAtPath:self._ignoreFilePath error:nil];

		return;
	}

	NSString *ignoreFilePath = self._ignoreFilePath;
	if (!ignoreFilePath) {
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:CQIgnoreRulesNotSavedNotification object:nil userInfo:nil];

		return;
	}


	NSError *error = nil;
	NSData *rootData = [NSKeyedArchiver archivedDataWithRootObject:permanentIgnores];
	if (![rootData writeToFile:self._ignoreFilePath options:NSDataWritingAtomic error:&error])
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:CQIgnoreRulesNotSavedNotification object:nil userInfo:@{@"connection": _connection, @"error": error}];
}

#pragma mark -

- (NSString *) _ignoreFilePath {
	if (!_appSupportPath) {
		NSString *appSupportPath = nil;
		appSupportPath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
		appSupportPath = [appSupportPath stringByAppendingPathComponent:([NSBundle mainBundle].infoDictionary)[(id)kCFBundleExecutableKey]];

		if (![[NSFileManager defaultManager] fileExistsAtPath:appSupportPath]) {
			[[NSFileManager defaultManager] createDirectoryAtPath:appSupportPath withIntermediateDirectories:YES attributes:nil error:nil];

			if (![[NSFileManager defaultManager] fileExistsAtPath:appSupportPath])
				return nil;
		}

		_appSupportPath = [appSupportPath copy];
	}

	NSString *ignoreFile = [NSString stringWithFormat:@"%@:%d.dat", _connection.server, _connection.serverPort];

	return [_appSupportPath stringByAppendingPathComponent:ignoreFile];
}
@end
