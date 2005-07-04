#import "MVFileTransfer.h"
#import "MVIRCFileTransfer.h"
#import "MVSILCFileTransfer.h"
#import "MVChatConnection.h"
#import "MVIRCChatConnection.h"
#import "MVChatUser.h"
#import "NSNotificationAdditions.h"

#import "common.h"
#import "settings.h"

NSString *MVDownloadFileTransferOfferNotification = @"MVDownloadFileTransferOfferNotification";
NSString *MVFileTransferStartedNotification = @"MVFileTransferStartedNotification";
NSString *MVFileTransferFinishedNotification = @"MVFileTransferFinishedNotification";
NSString *MVFileTransferErrorOccurredNotification = @"MVFileTransferErrorOccurredNotification";

NSString *MVFileTransferErrorDomain = @"MVFileTransferErrorDomain";

@implementation MVFileTransfer
+ (void) setFileTransferPortRange:(NSRange) range {
	unsigned short min = (unsigned short)range.location;
	unsigned short max = (unsigned short)(range.location + range.length);
	IrssiLock();
	settings_set_str( "dcc_port", [[NSString stringWithFormat:@"%uh %uh", min, max] UTF8String] );
	IrssiUnlock();
}

+ (NSRange) fileTransferPortRange {
	IrssiLock();
	const char *range = settings_get_str( "dcc_port" );
	IrssiUnlock();

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

- (id) initWithUser:(MVChatUser *) user {
	if( ( self = [super init] ) ) {
		_status = MVFileTransferHoldingStatus;
		_port = 0;
		_startOffset = 0;
		_finalSize = 0;
		_transfered = 0;
		_startDate = nil;
		_host = nil;
		_user = [user retain];
	}

	return self;
}

- (void) dealloc {
	[_startDate release];
	[_host release];
	[_user release];
	[_lastError release];

	_startDate = nil;
	_host = nil;
	_user = nil;
	_lastError = nil;

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
	return [[_lastError retain] autorelease];
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
	return [[_startDate retain] autorelease];
}

- (unsigned long long) startOffset {
	return _startOffset;
}

#pragma mark -

- (NSHost *) host {
	return [[_host retain] autorelease];
}

- (unsigned short) port {
	return _port;
}

#pragma mark -

- (void) setFinalSize:(unsigned long long) finalSize {
	_finalSize = finalSize;
}

- (void) setTransfered:(unsigned long long) transfered {
	_transfered = transfered;
}

- (void) setStartDate:(NSDate *) startDate {
	if ( _startDate ) 
		[_startDate release];
	
	_startDate = [startDate retain];
}

#pragma mark -

- (MVChatUser *) user {
	return [[_user retain] autorelease];
}

#pragma mark -

- (void) cancel {
// subclass, don't call super
	[self doesNotRecognizeSelector:_cmd];
}
@end

#pragma mark -

@implementation MVFileTransfer (MVFileTransferPrivate)
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
+ (id) transferWithSourceFile:(NSString *) path toUser:(MVChatUser *) user passively:(BOOL) passive {
	if( [[user connection] type] == MVChatConnectionIRCType ) {
		return [MVIRCUploadFileTransfer transferWithSourceFile:path toUser:user passively:passive];
	} else if ( [[user connection] type] == MVChatConnectionSILCType ) {
		return [MVSILCUploadFileTransfer transferWithSourceFile:path toUser:user passively:passive];
	}

	return nil;
}

#pragma mark -

- (id) initWithUser:(MVChatUser *) user {
	if( ( self = [super initWithUser:user] ) ) {
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
	return [[_source retain] autorelease];
}

#pragma mark -

- (BOOL) isUpload {
	return YES;
}
@end

#pragma mark -

@implementation MVDownloadFileTransfer
- (id) initWithUser:(MVChatUser *) user {
	if( ( self = [super initWithUser:user] ) ) {
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
	return [[_destination retain] autorelease];
}

#pragma mark -

- (NSString *) originalFileName {
	return [[_originalFileName retain] autorelease];
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