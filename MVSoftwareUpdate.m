#import <Cocoa/Cocoa.h>
#import <unistd.h>
#import "MVSoftwareUpdate.h"

#define MVSoftwareUpdateURLFormat @"http://www.javelin.cc/global/update.php?MVApplicationBuild=%@&MVApplicationName=%@"

#pragma mark -

static jmp_buf timeoutJump;
static sig_t oldTimeoutHandler;

static void MVSoftwareUpdateTimeoutHandler( int signal ) {
	extern jmp_buf timeoutJump;
	longjmp( timeoutJump, 1 );
}

static void MVSoftwareUpdateSetTimeout( unsigned int seconds ) {
	extern sig_t oldTimeoutHandler;
	alarm( 0 );
	oldTimeoutHandler = signal( SIGALRM, MVSoftwareUpdateTimeoutHandler );
	alarm( seconds );
}

static void MVSoftwareUpdateClearTimeout() {
	extern sig_t oldTimeoutHandler;
	alarm( 0 );
	signal( SIGALRM, oldTimeoutHandler );
}

@implementation MVSoftwareUpdate
+ (void) checkAutomatically:(BOOL) flag {
	[[MVSoftwareUpdate alloc] initAutomatically:flag];
}

#pragma mark -

- (id) initAutomatically:(BOOL) flag {
	extern jmp_buf timeoutJump;
	BOOL retain = NO;
	self = [super init];

	updateInfo = nil;

	if( setjmp( timeoutJump ) ) goto error;

	MVSoftwareUpdateSetTimeout( 5 );
	updateInfo = [[NSMutableDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:MVSoftwareUpdateURLFormat, [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"], [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]]]] retain];
	MVSoftwareUpdateClearTimeout();

	if( ! updateInfo ) {
		error:
		if( ! flag ) NSRunCriticalAlertPanel( NSLocalizedString( @"Connection to the Update server failed.", "connection failed to the update server" ), NSLocalizedString( @"The server may be down for maintenance, or the connection was broken between your computer and the server. Check your connection and try again.", "connection dropped" ), nil, nil, nil );
	} else if( [[updateInfo objectForKey:@"MVNeedsUpdate"] boolValue] ) {
		if( flag ) {
			if( NSRunInformationalAlertPanel( [NSString stringWithFormat:NSLocalizedString( @"There is a new version of %@ currently available.", "new version available" ), [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]], NSLocalizedString( @"A newer version of this software has just been detected, would you like to see what's new?", "the software needs updated question" ), NSLocalizedString( @"Yes", "yes answer" ), NSLocalizedString( @"Never", "never answer" ), NSLocalizedString( @"No", "no answer" ) ) != NSOKButton ) {
				goto end;
			}
		}
		retain = YES;
		[NSBundle loadNibNamed:@"MVSoftwareUpdate" owner:self];
	} else if( ! flag ) {
		NSRunInformationalAlertPanel( [NSString stringWithFormat:NSLocalizedString( @"There are no new versions of %@ currently available.", "no new version" ), [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"]], NSLocalizedString( @"Your software is all up-to-date with the latest version released. Check back at a later date.", "the software is all up-to-date" ), nil, nil, nil );
	}

	end:
	if( ! retain ) [self autorelease];

	return self;
}

- (void) dealloc {
	[window close];
	window = nil;

	[updateInfo autorelease];
	updateInfo = nil;

	[super dealloc];
}

- (void) awakeFromNib {
	if( [[updateInfo objectForKey:@"MVNeedsUpdate"] boolValue] ) {
		NSString *label = [[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:@"CFBundleName"];
		[program setStringValue:[NSString stringWithFormat:NSLocalizedString( @"%@ Update", "program update" ), label]];
		[version setStringValue:[NSString stringWithFormat:NSLocalizedString( @"currently using %@ (v%@)", "current version" ), [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"], [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]]];
		[[about textStorage] replaceCharactersInRange:NSMakeRange( 0, 0 ) withAttributedString:[[[NSAttributedString alloc] initWithHTML:[[updateInfo objectForKey:@"MVInformation"] dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES] documentAttributes:nil] autorelease]];
		[window center];
		[window makeKeyAndOrderFront:nil];
	}
}

#pragma mark -

- (IBAction) download:(id) sender {
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[updateInfo objectForKey:@"MVLatestDownloadURL"]]];
	[self autorelease];
}

- (IBAction) dontDownload:(id) sender {
	[self autorelease];
}

- (BOOL) windowShouldClose:(id) sender {
	[self dontDownload:nil];
	return NO;
}
@end
