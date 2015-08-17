#import "NSURLAdditions.h"

@implementation NSURL (NSURLAdditions)
+ (id) URLWithInternetLocationFile:(NSString *) path {
	const char *fileSystemPath = [[NSFileManager defaultManager] fileSystemRepresentationWithPath:path];

	FSRef ref;
	if( FSPathMakeRef( (UInt8 *)fileSystemPath, &ref, NULL ) ) {
		return nil;
	}

	ResFileRefNum fileRefNum = 0;
	if( ( fileRefNum = FSOpenResFile( &ref, fsRdPerm ) ) == -1 ) {
		return nil;
	}

	if( ! Count1Resources('url ') ) {
		CloseResFile( fileRefNum );
		return nil;
	}

	Handle res = Get1IndResource( 'url ', 1 );
	NSString *urlString = [[NSString alloc] initWithBytes:*res length:GetHandleSize( res ) encoding:NSUTF8StringEncoding];
	NSURL *url = [NSURL URLWithString:urlString];
	ReleaseResource( res );
	CloseResFile( fileRefNum );

	return url;
}
@end
