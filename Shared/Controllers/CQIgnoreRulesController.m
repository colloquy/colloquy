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

	NSURL *_appSupportURL;
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

	if (self._ignoreFileURL) {
		NSData *root = [NSData dataWithContentsOfURL:self._ignoreFileURL];

		for (NSData *data in [NSKeyedUnarchiver unarchiveObjectWithData:root])
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

	if (!permanentIgnores.count && self._ignoreFileURL) {
		[[NSFileManager defaultManager] removeItemAtURL:self._ignoreFileURL error:nil];

		return;
	}

	if (!self._ignoreFileURL) {
		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:CQIgnoreRulesNotSavedNotification object:nil userInfo:nil];

		return;
	}


	NSError *error = nil;
	NSData *rootData = [NSKeyedArchiver archivedDataWithRootObject:permanentIgnores];
	if (![rootData writeToURL:self._ignoreFileURL options:NSDataWritingAtomic error:&error]`)
		[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:CQIgnoreRulesNotSavedNotification object:nil userInfo:@{@"connection": _connection, @"error": error}];
}

#pragma mark -

- (NSURL *__nullable) _ignoreFileURL {
	if (!_appSupportURL) {
		_appSupportURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
		_appSupportURL = [[_appSupportURL URLByAppendingPathComponent:[NSBundle mainBundle].infoDictionary[(id)kCFBundleExecutableKey]] copy];
	}

	NSString *ignoreFile = [NSString stringWithFormat:@"%@:%d.dat", _connection.server, _connection.serverPort];
	return [_appSupportURL URLByAppendingPathComponent:ignoreFile];
}
@end

NS_ASSUME_NONNULL_END
