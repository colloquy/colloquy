#import "MVFileTransferController.h"
#import "MVBuddyListController.h"
#import "JVBuddy.h"
#import "JVDetailCell.h"

static MVFileTransferController *sharedInstance = nil;

#pragma mark -

@implementation MVFileTransferController
+ (NSString *) userPreferredDownloadFolder {
	NSString *preferredDownloadFolder = [[NSUserDefaults standardUserDefaults] stringForKey:@"JVUserPreferredDownloadFolder"];

	if( !preferredDownloadFolder.length )
		return [@"~/Downloads" stringByExpandingTildeInPath];
	return preferredDownloadFolder;
}

+ (void) setUserPreferredDownloadFolder:(NSString *) path {
	if ([[NSFileManager defaultManager] isWritableFileAtPath:path])
		[[NSUserDefaults standardUserDefaults] setObject:path forKey:@"JVUserPreferredDownloadFolder"];
	else {
		// fail, somehow
	}
}

#pragma mark -

+ (MVFileTransferController *) defaultController {
	return (sharedInstance ? sharedInstance : (sharedInstance = [[self alloc] init]));
}

#pragma mark -

- (id) init {
	if (!(self = [super init]))
		return nil;

	_safeFileExtentions = [[NSSet allocWithZone:nil] initWithObjects:@"jpg", @"jpeg", @"gif", @"png", @"tif", @"tiff", @"psd", @"pdf", @"txt", @"rtf", @"html", @"htm", @"swf", @"mp3", @"wma", @"wmv", @"ogg", @"ogm", @"mov", @"mpg", @"mpeg", @"m1v", @"m2v", @"mp4", @"avi", @"vob", @"avi", @"asx", @"asf", @"pls", @"m3u", @"rmp", @"aif", @"aiff", @"aifc", @"wav", @"wave", @"m4a", @"m4p", @"m4b", @"dmg", @"udif", @"ndif", @"dart", @"sparseimage", @"cdr", @"dvdr", @"iso", @"img", @"toast", @"rar", @"sit", @"sitx", @"bin", @"hqx", @"zip", @"gz", @"tgz", @"tar", @"bz", @"bz2", @"tbz", @"z", @"taz", @"uu", @"uue", @"colloquytranscript", @"torrent",nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileTransferDidFinish:) name:MVFileTransferFinishedNotification object:nil];

	[MVFileTransfer setFileTransferPortRange:NSRangeFromString([[NSUserDefaults standardUserDefaults] stringForKey:@"JVFileTransferPortRange"])];
	[MVFileTransfer setAutoPortMappingEnabled:[[NSUserDefaults standardUserDefaults] boolForKey:@"JVAutoOpenTransferPorts"]];

	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[_safeFileExtentions release];

	[super dealloc];
}

#pragma mark -

- (void) fileAtPathDidFinish:(NSString *) path {
	[[NSWorkspace sharedWorkspace] noteFileSystemChanged:path];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"JVOpenSafeFiles"] && [_safeFileExtentions containsObject:[path.pathExtension lowercaseString]])
		[[NSWorkspace sharedWorkspace] openFile:path withApplication:nil andDeactivate:NO];
}
@end
