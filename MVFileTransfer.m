#import "MVFileTransfer.h"
#import "MVIRCFileTransfer.h"
#import "MVChatConnection.h"
#import "NSNotificationAdditions.h"

#import "common.h"
#import "settings.h"

NSString *MVDownloadFileTransferOfferNotification = @"MVDownloadFileTransferOfferNotification";
NSString *MVFileTransferStartedNotification = @"MVFileTransferStartedNotification";
NSString *MVFileTransferFinishedNotification = @"MVFileTransferFinishedNotification";
NSString *MVFileTransferErrorOccurredNotification = @"MVFileTransferErrorOccurredNotification";

NSString *MVFileTransferErrorDomain = @"MVFileTransferErrorDomain";

@interface MVFileTransfer (MVFileTransferPrivate)
- (void) _setConnection:(MVChatConnection *) connection;
- (void) _setStatus:(MVFileTransferStatus) status;
- (void) _postError:(NSError *) error;
@end

#pragma mark -

@implementation MVFileTransfer
+ (void) setFileTransferPortRange:(NSRange) range {
	extern NSRecursiveLock *MVIRCChatConnectionThreadLock;
	unsigned short min = (unsigned short)range.location;
	unsigned short max = (unsigned short)(range.location + range.length);
	[MVIRCChatConnectionThreadLock lock];
	settings_set_str( "dcc_port", [[NSString stringWithFormat:@"%uh %uh", min, max] UTF8String] );
	[MVIRCChatConnectionThreadLock unlock];
}

+ (NSRange) fileTransferPortRange {
	extern NSRecursiveLock *MVIRCChatConnectionThreadLock;
	[MVIRCChatConnectionThreadLock lock];
	const char *range = settings_get_str( "dcc_port" );
	[MVIRCChatConnectionThreadLock unlock];

	unsigned short min = 1024;
	unsigned short max = 1048;

	if( range && strlen( range ) ) {
		min = strtoul( range, NULL, 10 );
		char *temp = strchr( range, ' ' );
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
	}

	return NSMakeRange( (unsigned int) min, (unsigned int)( max - min ) );
}

#pragma mark -

- (id) initWithUser:(NSString *) user fromConnection:(MVChatConnection *) connection {
	if( ( self = [super init] ) ) {
		_connection = nil;
		[self _setConnection:connection];
		_status = MVFileTransferHoldingStatus;
		_finalSize = 0;
		_transfered = 0;
		_startDate = nil;
		_host = nil;
		_user = [user copy];
		_port = 0;
		_startOffset = 0;
	}

	return self;
}

- (void) dealloc {
	[_startDate release];
	[_host release];
	[_user release];

	_startDate = nil;
	_host = nil;
	_user = nil;

	[super dealloc];
}

#pragma mark -

- (BOOL) isUpload {
	return NO;
}

- (BOOL) isDownload {
	return NO;
}

- (BOOL) isPassive {
// subclass if needed
	return NO;
}

- (MVFileTransferStatus) status {
	return _status;
}

- (NSError *) lastError {
	return _lastError;
}

#pragma mark -

- (unsigned long long) finalSize {
	return _finalSize;
}

- (unsigned long long) transfered {
	return _transfered;
}

#pragma mark -

- (NSDate *) startDate {
	return _startDate;
}

- (unsigned long long) startOffset {
	return _startOffset;
}

#pragma mark -

- (NSHost *) host {
	return _host;
}

- (unsigned short) port {
	return _port;
}

#pragma mark -

- (MVChatConnection *) connection {
	return _connection;
}

- (NSString *) user {
	return _user;
}

#pragma mark -

- (void) cancel {
// subclass, don't call super
	[self doesNotRecognizeSelector:_cmd];
}
@end

#pragma mark -

@implementation MVFileTransfer (MVFileTransferPrivate)
- (void) _setConnection:(MVChatConnection *) connection {
	[_connection autorelease];
	_connection = [connection retain];
}

- (void) _setStatus:(MVFileTransferStatus) status {
	_status = status;
}

- (void) _postError:(NSError *) error {
	[self _setStatus:MVFileTransferErrorStatus];

	[_lastError autorelease];
	_lastError = [error retain];

	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:error, @"error", nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:MVFileTransferErrorOccurredNotification object:self userInfo:info];
}
@end

#pragma mark -

@implementation MVUploadFileTransfer
+ (id) transferWithSourceFile:(NSString *) path toUser:(NSString *) nickname onConnection:(MVChatConnection *) connection passively:(BOOL) passive {
	if( [connection type] == MVChatConnectionIRCType ) {
		return [MVIRCUploadFileTransfer transferWithSourceFile:path toUser:nickname onConnection:connection passively:passive];
	}

	return nil;
}

#pragma mark -

- (id) initWithUser:(NSString *) user fromConnection:(MVChatConnection *) connection {
	if( ( self = [super initWithUser:user fromConnection:connection] ) ) {
		_source = nil;
	}
	
	return self;
}

- (void) dealloc {
	[_source release];	
	_source = nil;	
	[super dealloc];
}

#pragma mark -

- (NSString *) source {
	return _source;
}

#pragma mark -

- (BOOL) isUpload {
	return YES;
}
@end

#pragma mark -

@implementation MVDownloadFileTransfer
- (id) initWithUser:(NSString *) user fromConnection:(MVChatConnection *) connection {
	if( ( self = [super initWithUser:user fromConnection:connection] ) ) {
		_destination = nil;
		_originalFileName = nil;
	}

	return self;
}

- (void) dealloc {
	[_destination release];
	[_originalFileName release];

	_destination = nil;
	_originalFileName = nil;

	[super dealloc];
}

#pragma mark -

- (void) setDestination:(NSString *) path renameIfFileExists:(BOOL) rename {
	[_destination autorelease];
	_destination = [[path stringByStandardizingPath] copy];
	// subclass if needed, call super
}

- (NSString *) destination {
	return _destination;
}

#pragma mark -

- (NSString *) originalFileName {
	return _originalFileName;
}

#pragma mark -

- (BOOL) isDownload {
	return YES;
}

#pragma mark -

- (void) reject {
// subclass, don't call super
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (void) accept {
	[self acceptByResumingIfPossible:YES];
}

- (void) acceptByResumingIfPossible:(BOOL) resume {
// subclass, don't call super
	[self doesNotRecognizeSelector:_cmd];
}
@end