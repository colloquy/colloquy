#import "NSURLAdditions.h"

@implementation NSURL (NSURLAdditions)
+ (id) URLWithInternetLocationFile:(NSString *) path {
	const char *fileSystemPath = [[NSFileManager defaultManager] fileSystemRepresentationWithPath:path];

	FSRef ref;
	if( FSPathMakeRef( (UInt8 *)fileSystemPath, &ref, NULL ) ) {
		if( NSDebugEnabled ) NSLog( @"Couldn't make FSRef from: %@", path );
		return nil;
	}

	short fileRefNum = 0;
	if( ( fileRefNum = FSOpenResFile( &ref, fsRdPerm ) ) == -1 ) {
		if( NSDebugEnabled ) NSLog(@"Couldn't open inetloc file at: %@", path);
		return nil;
	}

	if( ! Count1Resources('url ') ) {
		if( NSDebugEnabled ) NSLog(@"Inetloc file '%@' contains no 'url ' resources", path);
		CloseResFile( fileRefNum );
		return nil;
	}

	Handle res = Get1IndResource( 'url ', 1 );
	NSString *urlString = [[[NSString alloc] initWithBytes:*res length:GetHandleSize( res ) encoding:NSUTF8StringEncoding] autorelease];
	NSURL *url = [NSURL URLWithString:urlString];
	ReleaseResource( res );
	CloseResFile( fileRefNum );

	return url;
}
@end
