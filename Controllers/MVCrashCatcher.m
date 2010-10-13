#import "MVCrashCatcher.h"
#import <sys/sysctl.h>

@implementation MVCrashCatcher
+ (void) check {
	[[MVCrashCatcher alloc] init]; // Released when the window is closed.
}

#pragma mark -

- (id) init {
	if (!(self = [super init]))
		return nil;

	NSString *programName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	NSString *logDirectory = nil;
	if( floor( NSAppKitVersionNumber ) == NSAppKitVersionNumber10_5 ) logDirectory = [@"~/Library/Logs/CrashReporter/" stringByExpandingTildeInPath];
	else logDirectory = [@"~/Library/Logs/DiagnosticReports/" stringByExpandingTildeInPath]; // files in CrashReporter/ are really symlinks to files in this dir in 10.6+

	// If there are multiple crash reports, only get the latest one. Also deletes older crash reports; we don't want to show the error on n launches for an unknown number of n
	for( NSString *file in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:logDirectory error:nil] ) {
		if( [file hasCaseInsensitivePrefix:programName] ) {
			[[NSFileManager defaultManager] removeItemAtPath:logPath error:nil];
			id old = logPath;
			logPath = [[logDirectory stringByAppendingPathComponent:file] retain];
			[old release];
		}
	}

	if( logPath.length ) [NSBundle loadNibNamed:@"MVCrashCatcher" owner:self];
	else [self autorelease];

	return nil;
}

- (void) dealloc {
	[window close];

	[logPath release];

	[super dealloc];
}

- (void) awakeFromNib {
	NSString *logContent = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:NULL];
	logContent = [logContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	NSString *programName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	description.stringValue = [NSString stringWithFormat:NSLocalizedString( @"%@ encountered an unrecoverable error during a previous session. Please enter any details you may recall about what you were doing when the application crashed. This will help us to improve future releases of %@.", "crash message" ), programName, programName];
	log.string = logContent;

	[window center];

	[[NSApplication sharedApplication] runModalForWindow:window];
}

#pragma mark -

- (void) connectionDidFinishLoading:(NSURLConnection *) connection {
	[[NSFileManager defaultManager] removeItemAtPath:logPath error:nil];
	[self autorelease];
}

- (void) connection:(NSURLConnection *) connection didFailWithError:(NSError *) error {
	[self autorelease];
}

#pragma mark -

- (IBAction) sendCrashLog:(id) sender {
	NSMutableString *body = [NSMutableString stringWithCapacity:40960];

	NSDictionary *systemVersion = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/ServerVersion.plist"];
	if( ! systemVersion.count ) systemVersion = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];

	NSDictionary *clientVersion = [NSBundle mainBundle].infoDictionary;

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
	[body appendFormat:@"feedback_comments=%@&", [[comments.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByEncodingIllegalURLCharacters]];

	NSData *trace = [[log string] dataUsingEncoding:NSUTF8StringEncoding];
	[body appendFormat:@"page_source=%@", ( trace ? [trace base64Encoding] : @"" )];

	NSURL *url = [NSURL URLWithString:@"http://colloquy.info/crash.php"];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10.];
	request.HTTPMethod = @"POST";
	[request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-type"];
	[request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES]];

	[NSURLConnection connectionWithRequest:request delegate:self];

	[[NSApplication sharedApplication] stopModal];
	[window orderOut:nil];
}

- (IBAction) dontSend:(id) sender {
	[[NSFileManager defaultManager] removeItemAtPath:logPath error:nil];

	[[NSApplication sharedApplication] stopModal];
	[window orderOut:nil];

	[self autorelease];
}

- (BOOL) windowShouldClose:(id) sender {
	[self dontSend:nil];
	return NO;
}
@end
