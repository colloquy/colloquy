#import "MVFileTransfer.h"
#import "MVIRCFileTransfer.h"
#import "MVSILCFileTransfer.h"
#import "MVChatConnection.h"
#import "MVIRCChatConnection.h"
#import "MVChatUser.h"
#import "MVUtilities.h"
#import "NSNotificationAdditions.h"

NSString *MVDownloadFileTransferOfferNotification = @"MVDownloadFileTransferOfferNotification";
NSString *MVFileTransferStartedNotification = @"MVFileTransferStartedNotification";
NSString *MVFileTransferFinishedNotification = @"MVFileTransferFinishedNotification";
NSString *MVFileTransferErrorOccurredNotification = @"MVFileTransferErrorOccurredNotification";

NSString *MVFileTransferErrorDomain = @"MVFileTransferErrorDomain";

static NSRange portRange = { 1024, 24 };
static BOOL autoPortMapping = YES;

@implementation MVFileTransfer
+ (void) setFileTransferPortRange:(NSRange) range {
	portRange = range;
}

+ (NSRange) fileTransferPortRange {
	return portRange;
}

+ (void) setAutoPortMappingEnabled:(BOOL) enable {
	autoPortMapping = enable;
}

+ (BOOL) isAutoPortMappingEnabled {
	return autoPortMapping;
}

#pragma mark -

- (id) initWithUser:(MVChatUser *) chatUser {
	if( ( self = [super init] ) ) {
		_status = MVFileTransferHoldingStatus;
		_user = [chatUser retain];
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

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5
@property(readonly, getter=isUpload) BOOL upload;
@property(readonly, getter=isDownload) BOOL download;
@property(readonly, getter=isPassive) BOOL passive;
#endif

- (BOOL) isUpload {
	return NO;
}

- (BOOL) isDownload {
	return NO;
}

- (BOOL) isPassive {
	return _passive;
}

#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_4
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

- (MVChatUser *) user {
	return _user;
}
#endif

#pragma mark -

- (void) cancel {
// subclass, don't call super
	[self doesNotRecognizeSelector:_cmd];
}
@end

#pragma mark -

@implementation MVFileTransfer (MVFileTransferPrivate)
- (void) _setStatus:(MVFileTransferStatus) newStatus {
	_status = newStatus;
}

- (void) _setFinalSize:(unsigned long long) newFinalSize {
	_finalSize = newFinalSize;
}

- (void) _setTransfered:(unsigned long long) newTransfered {
	_transfered = newTransfered;
}

- (void) _setStartOffset:(unsigned long long) newStartOffset {
	_startOffset = newStartOffset;
}

- (void) _setStartDate:(NSDate *) newStartDate {
	MVSafeRetainAssign( &_startDate, newStartDate );
}

- (void) _setHost:(NSHost *) newHost {
	MVSafeRetainAssign( &_host, newHost );
}

- (void) _setPort:(unsigned short) newPort {
	_port = newPort;
}

- (void) _setPassive:(BOOL) isPassive {
	_passive = isPassive;
}

- (void) _postError:(NSError *) error {
	[self _setStatus:MVFileTransferErrorStatus];

	MVSafeRetainAssign( &_lastError, error );

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

#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_4
- (NSString *) source {
	return _source;
}
#endif

#pragma mark -

- (BOOL) isUpload {
	return YES;
}
@end

#pragma mark -

@implementation MVUploadFileTransfer (MVUploadFileTransferPrivate)
- (void) _setSource:(NSString *) newSource {
	MVSafeCopyAssign( &_source, [newSource stringByStandardizingPath] );
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
	MVSafeCopyAssign( &_destination, [path stringByStandardizingPath] );
	_rename = rename;
}

- (void) setDestination:(NSString *) path {
	// subclass if needed, call super
	MVSafeCopyAssign( &_destination, [path stringByStandardizingPath] );
}

#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_4
- (NSString *) destination {
	return _destination;
}

#pragma mark -

- (NSString *) originalFileName {
	return _originalFileName;
}
#endif

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
- (void) _setOriginalFileName:(NSString *) newOriginalFileName {
	MVSafeCopyAssign( &_originalFileName, newOriginalFileName );
}
@end
