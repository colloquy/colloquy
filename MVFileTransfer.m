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
#import "dcc-get.h"
#import "dcc-file.h"

#import "config.h"

NSString *MVFileTransferOfferNotification = @"MVFileTransferOfferNotification";

void dcc_send_resume( GET_DCC_REC *dcc );

typedef struct {
	MVFileTransfer *transfer;
} MVFileTransferModuleData;

#pragma mark -

@interface MVFileTransfer (MVFileTransferPrivate)
+ (MVFileTransfer *) _transferForDCCFileRecord:(FILE_DCC_REC *) record;
- (FILE_DCC_REC *) _DCCFileRecord;
- (void) _setDCCFileRecord:(FILE_DCC_REC *) record;
@end

#pragma mark -

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

#pragma mark -

- (id) initWithDCCFileRecord:(void *) record {
//	NSAssert( [self isMemberOfClass:[MVFileTransfer class]], @"MVFileTransfer can't be used standalone, use the MVUploadFileTransfer or MVDownloadFileTransfer subclasses." );
	if( ( self = [super init] ) ) {
		[self _setDCCFileRecord:record];
	}
	return self;
}

#pragma mark -

- (BOOL) isUpload {
	return NO;
}

- (BOOL) isDownload {
	return NO;
}

#pragma mark -

- (unsigned long) finalSize {
	if( ! [self _DCCFileRecord] ) return 0;
	return [self _DCCFileRecord] -> size;
}

- (unsigned long) transfered {
	if( ! [self _DCCFileRecord] ) return 0;
	return [self _DCCFileRecord] -> transfd;
}

#pragma mark -

- (NSDate *) startDate {
	if( ! [self _DCCFileRecord] ) return nil;
	return [NSDate dateWithTimeIntervalSince1970:[self _DCCFileRecord] -> starttime];
}

- (unsigned long) startOffset {
	if( ! [self _DCCFileRecord] ) return 0;
	return [self _DCCFileRecord] -> skipped;
}

#pragma mark -

- (NSHost *) host {
	if( ! [self _DCCFileRecord] ) return nil;
	return [NSHost hostWithAddress:[NSString stringWithUTF8String:[self _DCCFileRecord] -> addrstr]];
}

- (unsigned short) port {
	if( ! [self _DCCFileRecord] ) return 0;
	return [self _DCCFileRecord] -> port;
}

#pragma mark -

- (void) cancel {
	
}
@end

#pragma mark -

@implementation MVFileTransfer (MVFileTransferPrivate)
+ (MVFileTransfer *) _transferForDCCFileRecord:(FILE_DCC_REC *) record {
	MVFileTransferModuleData *data = MODULE_DATA( record );
	if( data && data -> transfer ) return data -> transfer;
	return nil;
}

- (FILE_DCC_REC *) _DCCFileRecord {
	return _dcc;
}

- (void) _setDCCFileRecord:(FILE_DCC_REC *) record {
	_dcc = record;

	if( record ) {
		MVFileTransferModuleData *data = g_new0( MVFileTransferModuleData, 1 );
		data -> transfer = self;
		NSLog( @"%s %s %s %d", record -> nick, record -> target, record -> arg, record -> destroyed );
		NSLog( @"data: %x %x %x", ((GET_DCC_REC *)record) -> module_data, ((FILE_DCC_REC *)record) -> module_data, ((DCC_REC *)record) -> module_data );
//		MODULE_DATA_SET( ((DCC_REC *)record), data );
	}
}
@end

#pragma mark -

@implementation MVUploadFileTransfer
- (BOOL) isUpload {
	return YES;
}
@end

#pragma mark -

@implementation MVDownloadFileTransfer
- (BOOL) isDownload {
	return YES;
}

- (void) setDestination:(NSString *) path allowOverwriteOrResume:(BOOL) allow {
	[_destination autorelease];
	_destination = [path copy];

	((GET_DCC_REC *)[self _DCCFileRecord]) -> get_type = ( allow ? DCC_GET_OVERWRITE : DCC_GET_RENAME );
}

- (void) accept {
	[self acceptByResumingIfPossible:YES];
}

- (void) acceptByResumingIfPossible:(BOOL) resume {
	settings_set_str( "dcc_download_path", [[_destination stringByDeletingLastPathComponent] fileSystemRepresentation] );

	NSLog( @"incoming file: %s", [self _DCCFileRecord] -> arg );

	g_free_not_null( [self _DCCFileRecord] -> arg );
	[self _DCCFileRecord] -> arg = g_strdup( [[_destination lastPathComponent] fileSystemRepresentation] );

	if( resume ) dcc_send_resume( (GET_DCC_REC *)[self _DCCFileRecord] );
	else if( ! dcc_is_passive( [self _DCCFileRecord] ) ) dcc_get_passive( (GET_DCC_REC *)[self _DCCFileRecord] );
	else dcc_get_connect( (GET_DCC_REC *)[self _DCCFileRecord] );
}
@end