#import <Cocoa/Cocoa.h>
#import "MVFileTransfer.h"
#import "MVChatConnection.h"
#import "NSNotificationAdditions.h"

#define MODULE_NAME "MVFileTransfer"

#import "common.h"
#import "core.h"
#import "signals.h"
#import "settings.h"
#import "servers.h"
#import "irc.h"
#import "config.h"
#import "dcc.h"
#import "dcc-get.h"
#import "dcc-file.h"

NSString *MVDownloadFileTransferOfferNotification = @"MVDownloadFileTransferOfferNotification";
NSString *MVFileTransferStartedNotification = @"MVFileTransferStartedNotification";
NSString *MVFileTransferFinishedNotification = @"MVFileTransferFinishedNotification";

void dcc_send_resume( GET_DCC_REC *dcc );

typedef struct {
	MVFileTransfer *transfer;
} MVFileTransferModuleData;

#pragma mark -

@interface MVFileTransfer (MVFileTransferPrivate)
+ (id) _transferForDCCFileRecord:(FILE_DCC_REC *) record;
- (FILE_DCC_REC *) _DCCFileRecord;
- (void) _setDCCFileRecord:(FILE_DCC_REC *) record;
- (void) _setConnection:(MVChatConnection *) connection;
- (void) _setStatus:(MVFileTransferStatus) status;
- (void) _destroying;
@end

#pragma mark -

static void MVFileTransferConnected( FILE_DCC_REC *dcc ) {
	MVFileTransfer *self = [MVFileTransfer _transferForDCCFileRecord:(FILE_DCC_REC *)dcc];
	if( ! self ) return;

	[self _setStatus:MVFileTransferNormalStatus];

	NSNotification *note = [NSNotification notificationWithName:MVFileTransferStartedNotification object:self];		
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
}

static void MVFileTransferDestroyed( FILE_DCC_REC *dcc ) {
	MVFileTransfer *self = [MVFileTransfer _transferForDCCFileRecord:(FILE_DCC_REC *)dcc];
	if( ! self ) return;

	if( [self status] == MVFileTransferNormalStatus ) {
		[self _setStatus:MVFileTransferDoneStatus];
		NSNotification *note = [NSNotification notificationWithName:MVFileTransferFinishedNotification object:self];		
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
	}

	[self _destroying];
}

static void MVFileTransferClosed( FILE_DCC_REC *dcc ) {
	MVFileTransfer *self = [MVFileTransfer _transferForDCCFileRecord:(FILE_DCC_REC *)dcc];
	if( ! self ) return;

	if( dcc -> size != dcc -> transfd ) {
		[self _setStatus:MVFileTransferErrorStatus];
	} else {
		[self _setStatus:MVFileTransferDoneStatus];
		NSNotification *note = [NSNotification notificationWithName:MVFileTransferFinishedNotification object:self];		
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
	}
}

#pragma mark -

@implementation MVFileTransfer
+ (void) initialize {
	[super initialize];
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		signal_add_last( "dcc connected", (SIGNAL_FUNC) MVFileTransferConnected );
		signal_add_last( "dcc destroyed", (SIGNAL_FUNC) MVFileTransferDestroyed );
		signal_add_last( "dcc closed", (SIGNAL_FUNC) MVFileTransferClosed );
		tooLate = YES;
	}
}

#pragma mark -

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

- (id) initWithDCCFileRecord:(void *) record fromConnection:(MVChatConnection *) connection {
	if( ( self = [super init] ) ) {
		_dcc = NULL;
		_connection = nil;
		[self _setDCCFileRecord:record];
		[self _setConnection:connection];
		_status = MVFileTransferHoldingStatus;
		_finalSize = 0;
		_transfered = 0;
		_startDate = nil;
		_host = nil;
		_port = 0;
		_startOffset = 0;
	}

	return self;
}

- (void) dealloc {
	[self _setDCCFileRecord:NULL];

	[_startDate release];
	[_host release];

	_startDate = nil;
	_host = nil;

	[super dealloc];
}

#pragma mark -

- (BOOL) isUpload {
	return NO;
}

- (BOOL) isDownload {
	return NO;
}

- (MVFileTransferStatus) status {
	return _status;
}

- (NSError *) lastError {
	return nil;
}

#pragma mark -

- (unsigned long long) finalSize {
	if( ! [self _DCCFileRecord] ) return _finalSize;
	return [self _DCCFileRecord] -> size;
}

- (unsigned long long) transfered {
	if( ! [self _DCCFileRecord] ) return _transfered;
	return [self _DCCFileRecord] -> transfd;
}

#pragma mark -

- (NSDate *) startDate {
	if( ! [self _DCCFileRecord] ) return _startDate;
	if( [self _DCCFileRecord] -> starttime ) return [NSDate dateWithTimeIntervalSince1970:[self _DCCFileRecord] -> starttime];
	return nil;
}

- (unsigned long long) startOffset {
	if( ! [self _DCCFileRecord] ) return _startOffset;
	return [self _DCCFileRecord] -> skipped;
}

#pragma mark -

- (NSHost *) host {
	if( ! [self _DCCFileRecord] ) return _host;
	return [NSHost hostWithAddress:[NSString stringWithUTF8String:[self _DCCFileRecord] -> addrstr]];
}

- (unsigned short) port {
	if( ! [self _DCCFileRecord] ) return _port;
	return [self _DCCFileRecord] -> port;
}

#pragma mark -

- (MVChatConnection *) connection {
	return _connection;
}

#pragma mark -

- (void) cancel {
	if( ! [self _DCCFileRecord] ) return;
	dcc_close( (DCC_REC *)[self _DCCFileRecord] );
	[self _setStatus:MVFileTransferStoppedStatus];
}
@end

#pragma mark -

@implementation MVFileTransfer (MVFileTransferPrivate)
+ (id) _transferForDCCFileRecord:(FILE_DCC_REC *) record {
	MVFileTransferModuleData *data = MODULE_DATA( record );
	if( data && data -> transfer ) return data -> transfer;
	return nil;
}

- (FILE_DCC_REC *) _DCCFileRecord {
	return _dcc;
}

- (void) _setDCCFileRecord:(FILE_DCC_REC *) record {
	if( _dcc ) {
		MVFileTransferModuleData *data = MODULE_DATA( (FILE_DCC_REC *)_dcc );
		if( data ) data -> transfer = nil;
		g_free_not_null( data );
	}

	_dcc = record;

	if( record ) {
		MVFileTransferModuleData *data = g_new0( MVFileTransferModuleData, 1 );
		data -> transfer = self;
		MODULE_DATA_SET( ((DCC_REC *)record), data );
	}
}

- (void) _setConnection:(MVChatConnection *) connection {
	[_connection autorelease];
	_connection = [connection retain];
}

- (void) _setStatus:(MVFileTransferStatus) status {
	_status = status;
}

- (void) _destroying {
	_finalSize = [self finalSize];
	_transfered = [self transfered];
	_startDate = [[self startDate] retain];
	_host = [[self host] retain];
	_port = [self port];
	_startOffset = [self startOffset];

	[self _setDCCFileRecord:NULL];
}
@end

#pragma mark -

@implementation MVUploadFileTransfer
- (BOOL) isUpload {
	return YES;
}
@end

#pragma mark -

static void MVDownloadFileTransferSpecifyPath( GET_DCC_REC *dcc ) {
	MVDownloadFileTransfer *self = [MVDownloadFileTransfer _transferForDCCFileRecord:(FILE_DCC_REC *)dcc];
	if( ! self ) return;
	g_free_not_null( dcc -> file );
	dcc -> file = g_strdup( [[self destination] fileSystemRepresentation] );
}

#pragma mark -

@interface MVDownloadFileTransfer (MVDownloadFileTransferPrivate)
- (GET_DCC_REC *) _DCCFileRecord;
@end

#pragma mark -

@implementation MVDownloadFileTransfer
+ (void) initialize {
	[super initialize];
	static BOOL tooLate = NO;
	if( ! tooLate ) {
		signal_add_last( "dcc get receive", (SIGNAL_FUNC) MVDownloadFileTransferSpecifyPath );
		tooLate = YES;
	}
}

#pragma mark -

- (BOOL) isDownload {
	return YES;
}

#pragma mark -

- (id) initWithDCCFileRecord:(void *) record fromConnection:(MVChatConnection *) connection {
	if( ( self = [super initWithDCCFileRecord:record fromConnection:connection] ) ) {
		_destination = nil;
		_fromNickname = nil;
		_originalFileName = nil;
	}

	return self;
}

- (void) dealloc {
	[self reject];

	[_destination release];
	[_fromNickname release];
	[_originalFileName release];

	_destination = nil;
	_fromNickname = nil;
	_originalFileName = nil;

	[super dealloc];
}

#pragma mark -

- (void) setDestination:(NSString *) path renameIfFileExists:(BOOL) rename {
	[_destination autorelease];
	_destination = [[path stringByStandardizingPath] copy];

	if( ! [self _DCCFileRecord] ) return;
	[self _DCCFileRecord] -> get_type = ( rename ? DCC_GET_RENAME : DCC_GET_OVERWRITE );
}

- (NSString *) destination {
	return _destination;
}

#pragma mark -

- (NSString *) fromNickname {
	if( ! [self _DCCFileRecord] ) return _fromNickname;
	return [NSString stringWithCString:[self _DCCFileRecord] -> nick];
}

- (NSString *) originalFileName {
	if( ! [self _DCCFileRecord] ) return _originalFileName;
	return [NSString stringWithCString:[self _DCCFileRecord] -> arg];
}

#pragma mark -

- (void) reject {
	if( ! [self _DCCFileRecord] ) return;
	dcc_reject( (DCC_REC *)[self _DCCFileRecord], [self _DCCFileRecord] -> server );
}

#pragma mark -

- (void) accept {
	[self acceptByResumingIfPossible:YES];
}

- (void) acceptByResumingIfPossible:(BOOL) resume {
	if( ! [self _DCCFileRecord] ) return;

	if( ! [[NSFileManager defaultManager] isReadableFileAtPath:[self destination]] )
		resume = NO;

	if( resume ) dcc_send_resume( [self _DCCFileRecord] );
	else if( dcc_is_passive( [self _DCCFileRecord] ) ) dcc_get_passive( [self _DCCFileRecord] );
	else dcc_get_connect( [self _DCCFileRecord] );
}
@end

#pragma mark -

@implementation MVDownloadFileTransfer (MVDownloadFileTransferPrivate)
- (GET_DCC_REC *) _DCCFileRecord {
	return (GET_DCC_REC *)[super _DCCFileRecord];
}

- (void) _destroying {
	_fromNickname = [[self fromNickname] retain];
	_originalFileName = [[self originalFileName] retain];
	[super _destroying];
}
@end