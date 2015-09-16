#import "NSURLAdditions.h"

#warning this whole file uses deprecated functions, because there is no replacement!

@implementation NSURL (NSURLAdditions)
+ (instancetype) URLWithInternetLocationFile:(NSString *) path {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	
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
	HLock(res);
	NSString *urlString = [[NSString alloc] initWithBytes:*res length:GetHandleSize( res ) encoding:NSUTF8StringEncoding];
	HUnlock(res);
	NSURL *url = [NSURL URLWithString:urlString];
	[urlString release];
	ReleaseResource( res );
	CloseResFile( fileRefNum );

	return url;

#pragma clang diagnostic pop
}
@end

