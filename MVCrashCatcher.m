#import "MVCrashCatcher.h"
#import <sys/sysctl.h>

@implementation MVCrashCatcher
+ (void) check {
	NSLog( @"%@", [NSBundle bundleWithIdentifier:@"com.unsanity.smartcrashreports"] );
	if( [[NSBundle bundleWithIdentifier:@"com.unsanity.smartcrashreports"] isLoaded] )
		return; // user has Unsanity Smart Crash Reports installed, don't use our own reporter
	[[MVCrashCatcher alloc] init];
}

#pragma mark -

- (id) init {
	if( ( self = [super init] ) ) {
		NSString *programName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
		logPath = [[[NSString stringWithFormat:@"~/Library/Logs/CrashReporter/%@.crash.log", programName] stringByExpandingTildeInPath] retain];

		if( [[NSFileManager defaultManager] fileExistsAtPath:logPath] ) [NSBundle loadNibNamed:@"MVCrashCatcher" owner:self];
		else [self autorelease];
	}

	return nil;
}

- (void) dealloc {
	[window close];
	window = nil;

	[logPath release];
	logPath = nil;

	[super dealloc];
}

- (void) awakeFromNib {
	NSString *logContent = nil;
	if( floor( NSAppKitVersionNumber ) <= NSAppKitVersionNumber10_3 ) // test for 10.3
		logContent = [NSString stringWithContentsOfFile:logPath];
	else logContent = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:NULL];

	// get only the last crash trace, there is hardly ever more than one since we delete the file. it can still happen
	logContent = [[logContent componentsSeparatedByString:@"**********"] lastObject];
	logContent = [logContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	NSString *programName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	[description setStringValue:[NSString stringWithFormat:NSLocalizedString( @"%@ encountered an unrecoverable error during a previous session. Please enter any details you may recall about what you were doing when the application crashed. This will help us to improve future releases of %@.", "crash message" ), programName, programName]];
	[log setString:logContent];

	[window center];
	[[NSApplication sharedApplication] runModalForWindow:window];
}

#pragma mark -

- (void) connectionDidFinishLoading:(NSURLConnection *) connection {
	[[NSFileManager defaultManager] removeFileAtPath:logPath handler:nil];
	[connection release];
	[self autorelease];
}

- (void) connection:(NSURLConnection *) connection didFailWithError:(NSError *) error {
    [connection release];
	[self autorelease];
}

#pragma mark -

- (IBAction) sendCrashLog:(id) sender {
	NSMutableString *body = [NSMutableString stringWithCapacity:40960];

	NSDictionary *systemVersion = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
	NSDictionary *clientVersion = [[NSBundle mainBundle] infoDictionary];

	[body appendFormat:@"app_version=%@%%20(%@)&", [[clientVersion objectForKey:@"CFBundleShortVersionString"] stringByEncodingIllegalURLCharacters], [[clientVersion objectForKey:@"CFBundleVersion"] stringByEncodingIllegalURLCharacters]];
	[body appendFormat:@"os_version=%@:%@&", [[systemVersion objectForKey:@"ProductUserVisibleVersion"] stringByEncodingIllegalURLCharacters], [[systemVersion objectForKey:@"ProductBuildVersion"] stringByEncodingIllegalURLCharacters]];

	int selector[2] = { CTL_HW, HW_MODEL };
	char model[64] = "";
	size_t length = sizeof( model );
	sysctl( selector, 2, &model, &length, NULL, 0 );

	selector[0] = CTL_HW;
	selector[1] = HW_MEMSIZE;
	uint64_t memory = 0;
	length = sizeof( memory );
	sysctl( selector, 2, &memory, &length, NULL, 0 );

	[body appendFormat:@"machine_config=%s%%20(%d%%20MB)&", model, (int) ( memory / (uint64_t) 1024 / (uint64_t) 1024 )];
	[body appendFormat:@"feedback_comments=%@&", [[[comments string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByEncodingIllegalURLCharacters]];

	NSData *trace = [[log string] dataUsingEncoding:NSUTF8StringEncoding];
	[body appendFormat:@"page_source=%@", ( trace ? [trace base64Encoding] : @"" )];

	NSURL *url = [NSURL URLWithString:@"http://www.colloquy.info/crash.php"];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10.];
	[request setHTTPMethod:@"POST"];
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-type"];
	[request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES]];

	[[NSURLConnection connectionWithRequest:request delegate:self] retain];

	[[NSApplication sharedApplication] stopModal];
	[window orderOut:nil];
}

- (IBAction) dontSend:(id) sender {
	[[NSFileManager defaultManager] removeFileAtPath:logPath handler:nil];

	[[NSApplication sharedApplication] stopModal];
	[window orderOut:nil];

	[self autorelease];
}

- (BOOL) windowShouldClose:(id) sender {
	[self dontSend:nil];
	return NO;
}
@end