#import "CQIgnoreRulesController.h"

#import "KAIgnoreRule.h"

#import "NSNotificationAdditions.h"

#import <ChatCore/MVChatConnection.h>
#import <ChatCore/MVChatRoom.h>
#import <ChatCore/MVChatString.h>
#import <ChatCore/MVChatUser.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const CQIgnoreRulesNotSavedNotification = @"CQIgnoreRulesNotSavedNotification";

@implementation CQIgnoreRulesController {
	NSMutableArray *_ignoreRules;
	MVChatConnection *_connection;

	NSString *_appSupportPath;
}

- (instancetype) init {
	NSAssert(NO, @"use [CQIgnoreRulesController initWithConnection:] instead");
	return nil;
}

- (instancetype) initWithConnection:(MVChatConnection *) connection {
	if (!(self = [super init]))
		return nil;

	_connection = connection;
	_ignoreRules = [[NSMutableArray alloc] init];

	if (self._ignoreFilePath.length) {
		for (NSData *data in [NSKeyedUnarchiver unarchiveObjectWithFile:self._ignoreFilePath])
			[_ignoreRules addObject:[NSKeyedUnarchiver unarchiveObjectWithData:data]];
	}

	return self;
}


#pragma mark -

- (NSArray <KAIgnoreRule *> *) ignoreRules {
	return [_ignoreRules copy];
}

#pragma mark -

- (void) addIgnoreRule:(KAIgnoreRule *) ignoreRule {
	for (KAIgnoreRule *rule in self.ignoreRules)
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

	for (KAIgnoreRule *rule in self.ignoreRules) {
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
	for (KAIgnoreRule *rule in self.ignoreRules)
		if ([rule.user isEqualToString:user.nickname])
			return YES;
	return NO;
}

- (BOOL) shouldIgnoreMessage:(id) message fromUser:(MVChatUser *) user inRoom:(MVChatRoom *) room {
	for (KAIgnoreRule *rule in self.ignoreRules)
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

	for (KAIgnoreRule *rule in self.ignoreRules)
		if (rule.isPermanent)
			[permanentIgnores addObject:[NSKeyedArchiver archivedDataWithRootObject:rule]];

	if (!permanentIgnores.count && self._ignoreFilePath.length) {
		[[NSFileManager defaultManager] removeItemAtPath:self._ignoreFilePath error:nil];

		return;
	}

	NSString *ignoreFilePath = self._ignoreFilePath;
	if (!ignoreFilePath) {
		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:CQIgnoreRulesNotSavedNotification object:nil userInfo:nil];

		return;
	}


	NSError *error = nil;
	NSData *rootData = [NSKeyedArchiver archivedDataWithRootObject:permanentIgnores];
	if (![rootData writeToFile:ignoreFilePath options:NSDataWritingAtomic error:&error])
		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:CQIgnoreRulesNotSavedNotification object:nil userInfo:@{@"connection": _connection, @"error": error}];
}

#pragma mark -

- (NSString *__nullable) _ignoreFilePath {
	if (!_appSupportPath) {
		NSString *appSupportPath = nil;
		appSupportPath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
		appSupportPath = [appSupportPath stringByAppendingPathComponent:([NSBundle mainBundle].infoDictionary)[(id)kCFBundleExecutableKey]];

		if (![[NSFileManager defaultManager] fileExistsAtPath:appSupportPath]) {
			[[NSFileManager defaultManager] createDirectoryAtPath:appSupportPath withIntermediateDirectories:YES attributes:nil error:nil];

			if (![[NSFileManager defaultManager] fileExistsAtPath:appSupportPath])
				NSAssert(NO, @"should not reach this point");
				__builtin_unreachable();
		}

		_appSupportPath = [appSupportPath copy];
	}

	NSString *ignoreFile = [NSString stringWithFormat:@"%@:%d.dat", _connection.server, _connection.serverPort];

	return [_appSupportPath stringByAppendingPathComponent:ignoreFile];
}
@end

NS_ASSUME_NONNULL_END
