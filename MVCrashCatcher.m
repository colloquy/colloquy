#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>
#import <ChatCore/MVChatConnection.h>
#import "MVCrashCatcher.h"

@implementation MVCrashCatcher
+ (void) check {
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
	NSString *programName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
	[description setStringValue:[NSString stringWithFormat:NSLocalizedString( @"%@ encountered an unrecoverable error during a previous session. Please enter any details you may recall about what you were doing when the application crashed. This will help us to improve future releases of %@.", "crash message" ), programName, programName]];
	[log replaceCharactersInRange:NSMakeRange( 0, 0 ) withString:[NSString stringWithContentsOfFile:logPath]];

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
	NSString *llog = [NSString stringWithContentsOfFile:logPath];
	NSString *shortDesc = @"Colloquy Crash - No Description";
	if( [[[comments textStorage] string] length] > 48 ) {
		shortDesc = [[[[comments textStorage] string] substringToIndex:48] stringByAppendingString:@"..."];
	} else if( [[[comments textStorage] string] length] ) shortDesc = [[comments textStorage] string];

	ABPerson *me = [[ABAddressBook sharedAddressBook] me];
	ABMultiValue *value = [me valueForProperty:kABEmailProperty];
	NSString *email = [value valueAtIndex:[value indexForIdentifier:[value primaryIdentifier]]];
	NSString *name = [NSString stringWithFormat:@"%@ %@", [me valueForProperty:kABFirstNameProperty], [me valueForProperty:kABLastNameProperty]];

	NSString *body = [NSString stringWithFormat:@"build=%@&email=%@&service_name=%@&short_desc=%@&desc=%@&log=%@", MVURLEncodeString( [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] ), MVURLEncodeString( email ), MVURLEncodeString( name ), MVURLEncodeString( shortDesc ), MVURLEncodeString( [[comments textStorage] string] ), MVURLEncodeString( llog )];

	NSURL *url = [NSURL URLWithString:@"http://www.visualdistortion.org/colloquy/post.jsp"];
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