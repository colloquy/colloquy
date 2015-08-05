#import "UIApplicationAdditions.h"

#import "NSNotificationAdditions.h"

#import <SystemConfiguration/SystemConfiguration.h>

NSString *const CQReachabilityStateDidChangeNotification = @"CQReachabilityStateDidChangeNotification";
NSString *const CQReachabilityNewStateKey = @"CQReachabilityNewStateKey";
NSString *const CQReachabilityOldStateKey = @"CQReachabilityOldStateKey";

@interface UIApplication (Private)
- (void) cq_setReachabilityState:(CQReachabilityState) reachabilityState;
@end

static void reachabilityStatusChangedCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *context) {
	UIApplication *application = (__bridge UIApplication *)context;

	CQReachabilityState reachabilityState = CQReachabilityStateNotReachable;
	if (flags & kSCNetworkReachabilityFlagsReachable) {
		if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0 || ((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) || (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)))
			reachabilityState = CQReachabilityStateWiFi;

		if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
			reachabilityState = CQReachabilityStateWWAN;
	}

	[application cq_setReachabilityState:reachabilityState];
}

@implementation UIApplication (Additions)
- (CQReachabilityState) cq_reachabilityState {
	return [[self associatedObjectForKey:@"reachabilityState"] intValue];
}

- (void) cq_setReachabilityState:(CQReachabilityState) reachabilityState {
	CQReachabilityState oldState = self.cq_reachabilityState;

	[self willChangeValueForKey:@"cq_reachabilityState"];
	[self associateObject:@(reachabilityState) forKey:@"reachabilityState"];
	[self didChangeValueForKey:@"cq_reachabilityState"];

    [[NSNotificationCenter chatCenter] postNotificationName:CQReachabilityStateDidChangeNotification object:self userInfo:@{
		CQReachabilityNewStateKey: @(reachabilityState),
		CQReachabilityOldStateKey: @(oldState)
	}];
}

#pragma mark -

- (void) cq_beginReachabilityMonitoring {
	SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, "apple.com");
	SCNetworkReachabilityContext context = {0, (__bridge void *)self, NULL, NULL, NULL};

	SCNetworkReachabilitySetCallback(reachability, reachabilityStatusChangedCallback, &context);
	SCNetworkReachabilityScheduleWithRunLoop(reachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

	[self associateObject:(__bridge id)reachability forKey:@"reachability"];

	CFRelease(reachability);
}

- (void) cq_endReachabilityMonitoring {
	SCNetworkReachabilityRef reachability = (__bridge SCNetworkReachabilityRef)[self associatedObjectForKey:@"reachability"];
	if (reachability) {
		SCNetworkReachabilityUnscheduleFromRunLoop(reachability, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
		[self associateObject:nil forKey:@"reachability"];
	}
}
@end
