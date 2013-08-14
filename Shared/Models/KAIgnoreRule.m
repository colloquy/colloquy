// KAIgnoreRule.m
// Colloquy
// Created by Karl Adam on Thu Apr 15 2004.

#import "KAIgnoreRule.h"

#import <ChatCore/MVChatUser.h>

#if SYSTEM(MAC)
#import "JVChatWindowController.h"
#import "JVDirectChatPanel.h"
#endif

#define then {

@implementation KAIgnoreRule
@synthesize rooms = _rooms;
@synthesize permanent = _permanent;
@synthesize mask = _ignoreMask;
@synthesize message = _ignoredMessage;
@synthesize friendlyName = _friendlyName;
@synthesize user = _ignoredUser;

+ (id) ruleForUser:(NSString *) user mask:(NSString *) mask message:(NSString *) message inRooms:(NSArray *) rooms isPermanent:(BOOL) permanent friendlyName:(NSString *) friendlyName {
	KAIgnoreRule *ignoreRule = [[KAIgnoreRule alloc] initForUser:user mask:mask message:message inRooms:rooms isPermanent:permanent friendlyName:friendlyName];

	MVAutoreleasedReturn(ignoreRule);
}

- (id) initForUser:(NSString *) user mask:(NSString *) mask message:(NSString *) message inRooms:(NSArray *) rooms isPermanent:(BOOL) permanent friendlyName:(NSString *) friendlyName {
	if (!(self = [super init]))
		return nil;

	self.user = user;
	self.mask = mask;
	self.message = message;

	_rooms = [rooms copy];
	_friendlyName = [friendlyName copy];
	_permanent = permanent;

	return self;
}

+ (KAIgnoreRule *) ruleForUser:(NSString *) user message:(NSString *) message inRooms:(NSArray *) rooms isPermanent:(BOOL) permanent friendlyName:(NSString *) friendlyName {
	return [self ruleForUser:user mask:nil message:message inRooms:rooms isPermanent:permanent friendlyName:friendlyName];
}

- (id) initForUser:(NSString *) user message:(NSString *) message inRooms:(NSArray *) rooms isPermanent:(BOOL) permanent friendlyName:(NSString *) friendlyName {
	return [self initForUser:user mask:nil message:message inRooms:rooms isPermanent:permanent friendlyName:friendlyName];
}

#pragma mark -

- (id) initWithCoder:(NSCoder *) coder {
	if ([coder allowsKeyedCoding])
		return [self initForUser:[coder decodeObjectForKey:@"KAIgnoreUser"] mask:[coder decodeObjectForKey:@"KAIgnoreMask"] message:[coder decodeObjectForKey:@"KAIgnoreMessage"] inRooms:[coder decodeObjectForKey:@"KAIgnoreRooms"] isPermanent:[coder decodeBoolForKey:@"KAIgnorePermanent"] friendlyName:[coder decodeObjectForKey:@"KAIgnoreFriendlyName"]];

	[NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];

	return nil; // Never reached, but gcc and clang both warn about "Control reaches end of non-void function"
}

- (void) encodeWithCoder:(NSCoder *)coder {
	if (![coder allowsKeyedCoding])
		[NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];

	[coder encodeObject:_ignoredUser forKey:@"KAIgnoreUser"];
	[coder encodeObject:_ignoreMask forKey:@"KAIgnoreMask"];
	[coder encodeObject:_ignoredMessage forKey:@"KAIgnoreMessage"];
	[coder encodeObject:_rooms forKey:@"KAIgnoreRooms"];
	[coder encodeBool:_permanent forKey:@"KAIgnorePermanent"];
	[coder encodeObject:_friendlyName forKey:@"KAIgnoreFriendlyName"];
}

#pragma mark -

- (NSString *) description {
	return self.friendlyName;
}

- (BOOL) isEqual:(id) object {
	if (![object isKindOfClass:[self class]])
		return NO;

	KAIgnoreRule *rule = (KAIgnoreRule *)object;
	if (!(rule.user && self.user && [rule.user isEqualToString:self.user]))
		return NO;
	if (!(rule.mask && self.mask && [rule.mask isEqualToString:self.mask]))
		return NO;
	if (!(rule.message && self.message && [rule.message isEqualToString:self.message]))
		return NO;
	if (!(rule.rooms && self.rooms && [rule.rooms isEqualToArray:self.rooms]))
		return NO;

	return YES;
}

#pragma mark -

#if SYSTEM(MAC)
- (JVIgnoreMatchResult) matchUser:(MVChatUser *) user message:(NSString *) message inView:(id <JVChatViewController>) view {
	if (!_rooms.count || !view || ([view isKindOfClass:[JVDirectChatPanel class]] && [_rooms containsObject:[[(JVDirectChatPanel *)view target] displayName]])) {
#else
- (JVIgnoreMatchResult) matchUser:(MVChatUser *) user message:(NSString *) message inTargetRoom:(id) target {
	if (!_rooms.count || !target || (target && [target respondsToSelector:@selector(displayName)] && [target displayName])) {
#endif
		BOOL userFound = NO;
		BOOL messageFound = NO;
		BOOL maskFound = NO;
		BOOL userRequired = (_userRegex || _ignoredUser.length);
		BOOL maskRequired = (user.maskRepresentation.length && _maskRegex);
		BOOL messageRequired = (_messageRegex || [_ignoredMessage length]);

		if (_userRegex && [_userRegex firstMatchInString:user.nickname options:0 range:NSMakeRange(0, user.nickname.length)])
			userFound = YES;
		else if (_ignoredUser.length)
			userFound = [_ignoredUser isEqualToString:user.nickname];

		if (_maskRegex && [_maskRegex firstMatchInString:user.maskRepresentation options:0 range:NSMakeRange(0, user.maskRepresentation.length)])
			maskFound = YES;

		if (_messageRegex && message && [_messageRegex firstMatchInString:message options:0 range:NSMakeRange(0, message.length)])
			messageFound = YES;
		else if ([_ignoredMessage length] && message)
			messageFound = ([message rangeOfString:_ignoredMessage options:NSCaseInsensitiveSearch].location != NSNotFound);

		if (userRequired) {
			if (!userFound)
				return JVNotIgnored;
			else return JVUserIgnored;
		}

		if (maskRequired) {
			if (!maskFound)
				return JVNotIgnored;
			else return JVUserIgnored;
		}

		if (messageRequired) {
			if (messageFound)
				return JVMessageIgnored;
			else return JVNotIgnored;
		}
	}

	return JVNotIgnored;
}

#pragma mark -

- (NSString *) friendlyName {
	if (!_friendlyName.length) {
		if (_ignoredUser.length && _ignoredMessage.length)
			return [NSString stringWithFormat:@"%@ - %@", _ignoredUser, _ignoredMessage];
		if (_ignoredUser.length)
			return _ignoredUser;
		if ([_ignoredMessage length])
			return _ignoredMessage;
		if ([_ignoreMask length])
			return _ignoreMask;
		return NSLocalizedString (@"Blank Ignore", "blank ignore name");
	}

	return _friendlyName;
}

#pragma mark -

- (void) setMask:(NSString *) mask {
	if (_ignoreMask != mask && mask.isValidIRCMask) {
		_ignoreMask = [mask copy];
	}

	NSRegularExpression *newMessageRegex = nil;
	if (_ignoreMask) {
		// this isn't very fast, efficient or pretty, but, it won't be run that often, so, it doesn't matter too much.
		_ignoreMask = [_ignoreMask stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
		_ignoreMask = [_ignoreMask stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
		_ignoreMask = [_ignoreMask stringByReplacingOccurrencesOfString:@"[" withString:@"\\["];
		_ignoreMask = [_ignoreMask stringByReplacingOccurrencesOfString:@"]" withString:@"\\]"];
		_ignoreMask = [_ignoreMask stringByReplacingOccurrencesOfString:@"^" withString:@"\\^"];
		_ignoreMask = [_ignoreMask stringByReplacingOccurrencesOfString:@"|" withString:@"\\|"];
		NSError *error = nil;
		newMessageRegex = [[NSRegularExpression alloc] initWithPattern:[@"/" stringByAppendingString:_ignoreMask] options:NSRegularExpressionCaseInsensitive error:&error];
	}

	MVSafeAdoptAssign(_maskRegex, newMessageRegex);
}

#pragma mark -

- (void) setMessage:(NSString *) message {
	if (_ignoredMessage != message)
		_ignoredMessage = [message copy];

	NSRegularExpression *newMessageRegex = nil;
	if (message && ([message length] > 2) && [message hasPrefix:@"/"] && [message hasSuffix:@"/"])
		newMessageRegex = [[NSRegularExpression alloc] initWithPattern:[message substringWithRange:NSMakeRange(1, [message length] - 2)] options:NSRegularExpressionCaseInsensitive error:nil];

	MVSafeAdoptAssign(_messageRegex, newMessageRegex);
}

#pragma mark -

- (void) setUser:(NSString *) user {
	if (_ignoredUser != user)
		_ignoredUser = [user copy];

	NSRegularExpression *newMessageRegex = nil;
	if (user && ([user length] > 2) && [user hasPrefix:@"/"] && [user hasSuffix:@"/"])
		newMessageRegex = [[NSRegularExpression alloc] initWithPattern:[user substringWithRange:NSMakeRange (1, [user length] - 2) ] options:NSRegularExpressionCaseInsensitive error:nil];

	MVSafeAdoptAssign(_userRegex, newMessageRegex);
}
@end
