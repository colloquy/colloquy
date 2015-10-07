#import "CQSettingsController.h"

#import "NSNotificationAdditions.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const CQSettingsDidChangeNotification = @"CQSettingsDidChangeNotification";

@implementation  CQSettingsController
+ (instancetype)  settingsController {
	static CQSettingsController *settingsController;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		settingsController = [[CQSettingsController alloc] init];
	});
	return settingsController;
}

#pragma mark -

- (instancetype) init {
	_mirroringEnabled = YES;

	self.settingsLocation = CQSettingsLocationDevice;

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSUserDefaultsDidChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSUbiquitousKeyValueStoreDidChangeExternallyNotification object:nil];
}

#pragma mark -

- (void) setSettingsLocation:(CQSettingsLocation) settingsLocation {
	_settingsLocation = settingsLocation;

	if (_settingsLocation == CQSettingsLocationCloud) {
		[[self _storeForLocation:_settingsLocation] synchronize];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_defaultsChanged:) name:NSUbiquitousKeyValueStoreDidChangeExternallyNotification object:nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSUserDefaultsDidChangeNotification object:nil];
	} else if (_settingsLocation == CQSettingsLocationDevice) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_defaultsChanged:) name:NSUserDefaultsDidChangeNotification object:nil];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSUbiquitousKeyValueStoreDidChangeExternallyNotification object:nil];
	}
}

#pragma mark -

- (NSMethodSignature *) methodSignatureForSelector:(SEL) selector {
    return [[self _defaultLocation] methodSignatureForSelector:selector];
}

- (void) forwardInvocation:(NSInvocation *) invocation {
	if (_settingsLocation == CQSettingsLocationCloud)
		[invocation invokeWithTarget:[self _storeForLocation:CQSettingsLocationCloud]];

	if (_settingsLocation == CQSettingsLocationDevice || _mirroringEnabled)
		[invocation invokeWithTarget:[self _storeForLocation:CQSettingsLocationDevice]];
}

- (BOOL) respondsToSelector:(SEL) selector {
	return [[self _defaultLocation] respondsToSelector:selector];
}

#pragma mark -

- (void) onLocation:(CQSettingsLocation) location block:(void (^)(id settingsController)) block {
	block([self _storeForLocation:location]);

	if (_settingsLocation == CQSettingsLocationCloud && _mirroringEnabled)
		block([self _storeForLocation:CQSettingsLocationDevice]);
}

- (BOOL) synchronize {
	return [[self _storeForLocation:CQSettingsLocationDevice] synchronize] || [[self _storeForLocation:CQSettingsLocationCloud] synchronize];
}

#pragma mark -

- (void) _defaultsChanged:(NSNotification *) notification {
	CQSettingsLocation changedLocation = 0;
	if ([notification.name isEqualToString:NSUserDefaultsDidChangeNotification])
		changedLocation = CQSettingsLocationDevice;
	else if ([notification.name isEqualToString:NSUbiquitousKeyValueStoreDidChangeExternallyNotification]) {
		changedLocation = CQSettingsLocationCloud;

		NSNumber *changeReasonNumber = notification.userInfo[NSUbiquitousKeyValueStoreChangeReasonKey];
		if (changeReasonNumber) {
			NSInteger changeReason = [changeReasonNumber intValue];

			if (changeReason == NSUbiquitousKeyValueStoreServerChange || changeReason == NSUbiquitousKeyValueStoreInitialSyncChange || changeReason == NSUbiquitousKeyValueStoreAccountChange) {
				id localStore = [self _storeForLocation:CQSettingsLocationDevice];
				id cloudStore = [self _storeForLocation:CQSettingsLocationCloud];

				for (NSString *key in notification.userInfo[NSUbiquitousKeyValueStoreChangedKeysKey])
					localStore[key] = cloudStore[key];
			}
		}
	}

	if (changedLocation == _settingsLocation) {
		[[NSNotificationCenter chatCenter] postNotificationName:CQSettingsDidChangeNotification object:nil userInfo:nil];
	}
}

- (id) _defaultLocation {
	return [self _storeForLocation:_settingsLocation];
}

- (id) _storeForLocation:(CQSettingsLocation) location {
	if (_settingsLocation == CQSettingsLocationCloud) {
		// in cases where +[NSUbiquitousKeyValueStore defaultStore] returns nil, we should use NSUserDefaults instead of not saving prefs at all
		id store = [NSUbiquitousKeyValueStore defaultStore];
		if (store)
			return store;
		return [NSUserDefaults standardUserDefaults];
	}

	if (_settingsLocation == CQSettingsLocationDevice)
		return [NSUserDefaults standardUserDefaults];

	return nil;
}
@end

NS_ASSUME_NONNULL_END
