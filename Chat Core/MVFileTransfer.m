#import "MVFileTransfer.h"
#import "MVIRCFileTransfer.h"
#import "MVSILCFileTransfer.h"
#import "MVChatConnection.h"
#import "MVIRCChatConnection.h"
#import "MVChatUser.h"
#import "NSNotificationAdditions.h"

NSString *MVDownloadFileTransferOfferNotification = @"MVDownloadFileTransferOfferNotification";
NSString *MVFileTransferStartedNotification = @"MVFileTransferStartedNotification";
NSString *MVFileTransferFinishedNotification = @"MVFileTransferFinishedNotification";
NSString *MVFileTransferErrorOccurredNotification = @"MVFileTransferErrorOccurredNotification";

NSString *MVFileTransferErrorDomain = @"MVFileTransferErrorDomain";

static NSRange portRange;

@implementation MVFileTransfer
+ (void) initialize {
	portRange = NSMakeRange( 1024, 24 );
}

+ (void) setFileTransferPortRange:(NSRange) range {
	portRange = range;
}

+ (NSRange) fileTransferPortRange {
	return portRange;
}

#pragma mark -

- (id) initWithUser:(MVChatUser *) user {
	if( ( self = [super init] ) ) {
		_status = MVFileTransferHoldingStatus;
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

- (unsigned) hash {
	if( ! _hash ) _hash = ( [[self user] hash] ^ _port );
	return _hash;
}

#pragma mark -

- (BOOL) isUpload {
	return NO;
}

- (BOOL) isDownload {
	return NO;
}

- (BOOL) isPassive {
	return _passive;
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

- (void) _setFinalSize:(unsigned long long) finalSize {
	_finalSize = finalSize;
}

- (void) _setTransfered:(unsigned long long) transfered {
	_transfered = transfered;
}

- (void) _setStartOffset:(unsigned long long) startOffset {
	_startOffset = startOffset;
}

- (void) _setStartDate:(NSDate *) startDate {
	id old = _startDate;
	_startDate = [startDate retain];
	[old release];
}

- (void) _setHost:(NSHost *) host {
	id old = _host;
	_host = [host retain];
	[old release];
}

- (void) _setPort:(unsigned short) port {
	_port = port;
}

- (void) _setPassive:(BOOL) passive {
	_passive = passive;
}

- (void) _postError:(NSError *) error {
	[self _setStatus:MVFileTransferErrorStatus];

	id old = _lastError;
	_lastError = [error retain];
	[old release];

	NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:error, @"error", nil];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVFileTransferErrorOccurredNotification object:self userInfo:info];
	[info release];
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

@implementation MVUploadFileTransfer (MVUploadFileTransferPrivate)
- (void) _setSource:(NSString *) source {
	id old = _source;
	_source = [[source stringByStandardizingPath] retain];
	[old release];
}
@end

#pragma mark -

@implementation MVDownloadFileTransfer
- (void) dealloc {
	[_destination release];
	[_originalFileName release];

	_destination = nil;
	_originalFileName = nil;

	[super dealloc];
}

#pragma mark -

- (void) setDestination:(NSString *) path renameIfFileExists:(BOOL) rename {
	// subclass if needed, call super
	id old = _destination;
	_destination = [[path stringByStandardizingPath] copyWithZone:nil];
	[old release];
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

#pragma mark -

@implementation MVDownloadFileTransfer (MVDownloadFileTransferPrivate)
- (void) _setOriginalFileName:(NSString *) originalFileName {
	id old = _originalFileName;
	_originalFileName = [originalFileName copyWithZone:nil];
	[old release];
}
@end
