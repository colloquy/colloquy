#import <Cocoa/Cocoa.h>
#import <Message/NSMailDelivery.h>
#import "MVCrashCatcher.h"

@implementation MVCrashCatcher
+ (void) check {
	[[MVCrashCatcher alloc] init];
}

#pragma mark -

- (id) init {
	NSDate *modDate = nil, *lastDate = nil;
	self = [super init];
	programName = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"] copy];
	logPath = [[[NSString stringWithFormat:@"~/Library/Logs/CrashReporter/%@.crash.log", programName] stringByExpandingTildeInPath] retain];
	modDate = [[[NSFileManager defaultManager] fileAttributesAtPath:logPath traverseLink:NO] objectForKey:NSFileModificationDate];
	lastDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"MVCrashCatcherLastDate"];
	if( [[NSFileManager defaultManager] fileExistsAtPath:logPath] && ( [modDate timeIntervalSinceDate:lastDate] > 0. || ! lastDate ) ) crashLogExists = YES;
	if( ! crashLogExists || ! [programName length] ) [self autorelease];
	else [NSBundle loadNibNamed:@"MVCrashCatcher" owner:self];
	return self;
}

- (void) dealloc {
	[window close];
	window = nil;

	[programName autorelease];
	[logPath autorelease];

	programName = nil;
	logPath = nil;

	[super dealloc];
}

- (void) awakeFromNib {
	if( crashLogExists ) {
		[description setStringValue:[NSString stringWithFormat:NSLocalizedString( @"%@ encountered an unrecoverable error during a previous session. Please enter any details you may recall about what you were doing when the application crashed. This will help us to improve future releases of %@.", "crash message" ), programName, programName]];
		[log replaceCharactersInRange:NSMakeRange( 0, 0 ) withString:[NSString stringWithContentsOfFile:logPath]];
		[window center];
		[window makeKeyAndOrderFront:nil];
	}
}

#pragma mark -

- (IBAction) sendCrashLog:(id) sender {
	NSDate *modDate = [[[NSFileManager defaultManager] fileAttributesAtPath:logPath traverseLink:NO] objectForKey:NSFileModificationDate];
	NSString *body = [NSString stringWithFormat:@"Comments:   %@\r\r%@", [[comments textStorage] string], [[log textStorage] string]];
	if( [NSMailDelivery deliverMessage:body subject:[NSString stringWithFormat:@"Crash Report for %@", programName] to:@"timothy@javelin.cc"] ) {
		[[NSFileManager defaultManager] removeFileAtPath:logPath handler:nil];
	}
	[[NSUserDefaults standardUserDefaults] setObject:modDate forKey:@"MVCrashCatcherLastDate"];
	[self autorelease];
}

- (IBAction) dontSend:(id) sender {
	NSDate *modDate = [[[NSFileManager defaultManager] fileAttributesAtPath:logPath traverseLink:NO] objectForKey:NSFileModificationDate];
	[[NSUserDefaults standardUserDefaults] setObject:modDate forKey:@"MVCrashCatcherLastDate"];
	[self autorelease];
}

- (BOOL) windowShouldClose:(id) sender {
	[self dontSend:nil];
	return NO;
}
@end
