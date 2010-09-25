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

- (void) writeToInternetLocationFile:(NSString *) path {
	if( ! ( [[path pathExtension] isEqualToString:@"inetloc"] || [[path pathExtension] isEqualToString:@"webloc"] || [[path pathExtension] isEqualToString:@"ftploc"] || [[path pathExtension] isEqualToString:@"mailloc"] || [[path pathExtension] isEqualToString:@"afploc"] ) )
		path = [path stringByAppendingPathExtension:@"inetloc"];

	[[NSFileManager defaultManager] removeItemAtPath:path error:nil];

	NSString *parentPath = [path stringByDeletingLastPathComponent];
	NSString *pathName = [path lastPathComponent];
	const char *fileSystemPath = [[NSFileManager defaultManager] fileSystemRepresentationWithPath:parentPath];

	FSRef ref, parentRef;
	if( FSPathMakeRef( (unsigned char *) fileSystemPath, &parentRef, FALSE ) ) {
		if( NSDebugEnabled ) NSLog( @"Couldn't make FSRef from: %@", parentPath );
		return;
	}

	short fileRefNum = 0;
	unichar *buffer = (unichar *)calloc( [pathName length], sizeof( unichar ) );
	[pathName getCharacters:buffer];
	FSCreateResFile( &parentRef, [pathName length], buffer, 0, NULL, &ref, NULL );
	free( buffer );

	if( ( fileRefNum = FSOpenResFile( &ref, fsWrPerm ) ) == -1 ) {
		if( NSDebugEnabled ) NSLog( @"Couldn't open inetloc at: %@", path );
		[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
		return;
	}

	// Create the 'drag' resource first
	Handle res = NewHandle( 48 );
	Byte dragBuffer[48] = {
		0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02,
		0x54, 0x45, 0x58, 0x54, 0x00, 0x00, 0x01, 0x00,
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
		0x75, 0x72, 0x6C, 0x20, 0x00, 0x00, 0x01, 0x00,
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	};

	memcpy( *res, &dragBuffer, sizeof( dragBuffer ) );
	AddResource( res, 'drag', 128, (unsigned char *) "" );

	// Create the 'TEXT' and 'url ' resources
	NSString *urlString = [self absoluteString];
	const char *utf8string = [urlString UTF8String];

	res = NewHandle( strlen( utf8string ) );
	memcpy( *res, utf8string, strlen( utf8string ) );
	AddResource( res, 'TEXT', 256, (unsigned char *) "" ); // This takes over the Handle - don't dispose it

	res = NewHandle( strlen( utf8string ) );
	memcpy( *res, utf8string, strlen( utf8string ) );
	AddResource( res, 'url ', 256, (unsigned char *) "" ); // This takes over the Handle - don't dispose it

	CloseResFile( fileRefNum );

	// Set the file type/creator
	[[NSFileManager defaultManager] setAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedLong:'ilge'], NSFileHFSTypeCode, [NSNumber numberWithUnsignedLong:'MACS'], NSFileHFSCreatorCode, nil] ofItemAtPath:path error:nil];
}
@end
