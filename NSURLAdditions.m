#import <Cocoa/Cocoa.h>

#import "NSURLAdditions.h"

@implementation NSURL (NSURLAdditions)
+ (id) URLWithInternetLocationFile:(NSString *) path {
	NSAppleScript *script = [[NSAppleScript alloc] initWithSource:[NSString stringWithFormat:@"tell application \"Finder\" to return location of internet location file (POSIX file \"%@\")", path]]; 
	NSAppleEventDescriptor *result = [script executeAndReturnError:NULL];
	NSURL *ret = [NSURL URLWithString:[result stringValue]];
	return [[ret retain] autorelease];
}

- (void) writeToInternetLocationFile:(NSString *) path {
	NSString *folderPath = [[path stringByExpandingTildeInPath] stringByDeletingLastPathComponent];
	NSString *fileName = [path lastPathComponent];

	[[NSFileManager defaultManager] removeFileAtPath:path handler:nil];

	if( [[path pathExtension] isEqualToString:@"inetloc"] || [[path pathExtension] isEqualToString:@"webloc"] || [[path pathExtension] isEqualToString:@"ftploc"] || [[path pathExtension] isEqualToString:@"mailloc"] || [[path pathExtension] isEqualToString:@"afploc"] ) fileName = [fileName stringByDeletingPathExtension];

	NSAppleScript *script = [[NSAppleScript alloc] initWithSource:[NSString stringWithFormat:@"tell application \"Finder\" to make new internet location file to \"%@\" at (POSIX file \"%@\") with properties {name:\"%@\", comment:\"%@\"}", [self absoluteString], folderPath, fileName, [self absoluteString]]];
	[script executeAndReturnError:NULL];
}
@end
