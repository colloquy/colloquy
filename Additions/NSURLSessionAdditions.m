#import "NSURLSessionAdditions.h"

@implementation NSURLSession (Additions)
+ (NSURLSession *) CQ_backgroundSession {
	static NSURLSession *backgroundSession = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"info.colloquy.mobi.backgroundSession"];
		configuration.discretionary = YES;
		configuration.allowsCellularAccess = YES;
		configuration.sessionSendsLaunchEvents = NO;
		configuration.HTTPShouldUsePipelining = NO;
		configuration.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain;
		configuration.HTTPMaximumConnectionsPerHost = 1;
		configuration.shouldUseExtendedBackgroundIdleMode = YES;

		if ([configuration respondsToSelector:@selector(setMultipathServiceType:)])
			configuration.multipathServiceType = NSURLSessionMultipathServiceTypeHandover;

		backgroundSession = [NSURLSession sessionWithConfiguration:configuration];
	});

	return backgroundSession;
}
@end
