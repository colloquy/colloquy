#import <Cocoa/Cocoa.h>
#import "MVFileTransfer.h"

#define MODULE_NAME "MVFileTransfer"

#import "common.h"
#import "core.h"
#import "signals.h"
#import "settings.h"
#import "servers.h"
#import "irc.h"
#import "dcc.h"
#import "dcc-file.h"

@interface MVFileTransfer (MVFileTransferPrivate)
- (FILE_DCC_REC *) _DCCFileRecord;
@end

@implementation MVFileTransfer
+ (void) setFileTransferPortRange:(NSRange) range {
	unsigned short min = (unsigned short)range.location;
	unsigned short max = (unsigned short)(range.location + range.length);
	settings_set_str( "dcc_port", [[NSString stringWithFormat:@"%uh %uh", min, max] UTF8String] );
}

+ (NSRange) fileTransferPortRange {
	const char *range = settings_get_str( "dcc_port" );
	char *temp = NULL;
	unsigned short min = 1024;
	unsigned short max = 65535;

	min = strtoul( range, NULL, 10 );
	temp = strchr( range, ' ' );
	if( ! temp ) temp = strchr( range, '-' );

	if( ! temp ) max = min;
	else {
		max = strtoul( temp + 1, NULL, 10 );
		if( ! max ) max = min;
	}

	if( max < min ) {
		unsigned int t = min;
		min = max;
		max = t;
	}

	return NSMakeRange( (unsigned int) min, (unsigned int)( max - min ) );
}

- (id) initWithDCCFileRecord:(void *) record {
	NSAssert( [self isMemberOfClass:[MVFileTransfer class]], @"MVFileTransfer can't be used standalone, use the MVUploadFileTransfer or MVDownloadFileTransfer subclasses." );
	if( ( self = [super init] ) ) {
		_dcc = record;
	}
	return self;
}

- (BOOL) isUpload {
	return NO;
}

- (BOOL) isDownload {
	return NO;
}

- (unsigned long) finalSize {
	if( ! [self _DCCFileRecord] ) return 0;
	return [self _DCCFileRecord] -> size;
}

- (unsigned long) transfered {
	if( ! [self _DCCFileRecord] ) return 0;
	return [self _DCCFileRecord] -> transfd;
}

- (NSDate *) startDate {
	if( ! [self _DCCFileRecord] ) return nil;
	return [NSDate dateWithTimeIntervalSince1970:[self _DCCFileRecord] -> starttime];
}

- (unsigned long) startOffset {
	if( ! [self _DCCFileRecord] ) return 0;
	return [self _DCCFileRecord] -> skipped;
}

- (NSHost *) host {
	if( ! [self _DCCFileRecord] ) return nil;
	return [NSHost hostWithAddress:[NSString stringWithUTF8String:[self _DCCFileRecord] -> addrstr]];
}

- (unsigned short) port {
	if( ! [self _DCCFileRecord] ) return 0;
	return [self _DCCFileRecord] -> port;
}
@end

@implementation MVFileTransfer (MVFileTransferPrivate)
- (FILE_DCC_REC *) _DCCFileRecord {
	return _dcc;
}
@end

@implementation MVUploadFileTransfer
- (BOOL) isUpload {
	return YES;
}
@end

@implementation MVDownloadFileTransfer
- (BOOL) isDownload {
	return YES;
}
@end