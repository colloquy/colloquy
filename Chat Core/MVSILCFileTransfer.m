#import "MVSILCFileTransfer.h"
#import "MVSILCChatConnection.h"
#import "MVChatUser.h"
#import "NSNotificationAdditions.h"

NS_ASSUME_NONNULL_BEGIN

@interface MVFileTransfer (MVFileTransferSilcPrivate)
- (void) _silcPostError:(SilcClientFileError) error;
@end

#pragma mark -

static void silc_client_file_monitor( SilcClient client, SilcClientConnection conn, SilcClientMonitorStatus status, SilcClientFileError error, SilcUInt64 offset, SilcUInt64 filesize, SilcClientEntry client_entry, SilcUInt32 session_id, const char *filepath, void *context ) {
	MVFileTransfer *transfer = (__bridge MVFileTransfer *)(context);

	switch ( status ) {
		case SILC_CLIENT_FILE_MONITOR_KEY_AGREEMENT:
			[transfer _setStatus:MVFileTransferNormalStatus];

			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVFileTransferStartedNotification object:transfer];

			[transfer _setStartDate:[NSDate date]];
			break;

		case SILC_CLIENT_FILE_MONITOR_SEND:
		case SILC_CLIENT_FILE_MONITOR_RECEIVE:
			[transfer _setFinalSize:filesize];
			[transfer _setTransferred:offset];

			if( filesize == offset ) {
				 [transfer _setStatus:MVFileTransferDoneStatus];
				 [[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVFileTransferFinishedNotification object:transfer];
			}

			break;

		case SILC_CLIENT_FILE_MONITOR_CLOSED:
			break;

		case SILC_CLIENT_FILE_MONITOR_ERROR:
			[transfer _silcPostError:error];
			break;

		case SILC_CLIENT_FILE_MONITOR_GET:
		case SILC_CLIENT_FILE_MONITOR_PUT:
			[[NSNotificationCenter chatCenter] postNotificationOnMainThreadWithName:MVFileTransferDataTransferredNotification object:transfer];
			break;
	}
}

#pragma mark -

@implementation MVFileTransfer (MVFileTransferSilcPrivate)
- (void) _silcPostError:(SilcClientFileError) silcClientFileError {
	switch ( silcClientFileError ) {
		case SILC_CLIENT_FILE_UNKNOWN_SESSION:
		case SILC_CLIENT_FILE_ERROR: {
			NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:@"The file transfer terminated unexpectedly.", NSLocalizedDescriptionKey, nil];
			NSError *error = [[NSError allocWithZone:nil] initWithDomain:MVFileTransferErrorDomain code:MVFileTransferUnexpectedlyEndedError userInfo:info];
			[self performSelectorOnMainThread:@selector( _postError: ) withObject:error waitUntilDone:NO];
		}	break;

		case SILC_CLIENT_FILE_ALREADY_STARTED: {
			NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:@"The file %@ is already being offerend to %@.", NSLocalizedDescriptionKey, nil];
			NSError *error = [[NSError allocWithZone:nil] initWithDomain:MVFileTransferErrorDomain code:MVFileTransferAlreadyExistsError userInfo:info];
			[self performSelectorOnMainThread:@selector( _postError: ) withObject:error waitUntilDone:NO];
		}	break;

		case SILC_CLIENT_FILE_NO_SUCH_FILE:
		case SILC_CLIENT_FILE_PERMISSION_DENIED: {
			NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:@"The file %@ could not be created, please make sure you have write permissions in the %@ folder.", NSLocalizedDescriptionKey, nil];
			NSError *error = [[NSError allocWithZone:nil] initWithDomain:MVFileTransferErrorDomain code:MVFileTransferFileCreationError userInfo:info];
			[self performSelectorOnMainThread:@selector( _postError: ) withObject:error waitUntilDone:NO];
		}	break;

		case SILC_CLIENT_FILE_KEY_AGREEMENT_FAILED: {
			NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:@"Key agreement failed. Either your key was rejected by the other user or some other error happend during key negotiation.", NSLocalizedDescriptionKey, nil];
			NSError *error = [[NSError allocWithZone:nil] initWithDomain:MVFileTransferErrorDomain code:MVFileTransferKeyAgreementError userInfo:info];
			[self performSelectorOnMainThread:@selector( _postError: ) withObject:error waitUntilDone:NO];
		}	break;

		case SILC_CLIENT_FILE_OK:
			break;
	}
}
@end

#pragma mark -

@implementation MVSILCUploadFileTransfer
+ (void) initialize {
	[super initialize];
}

+ (id) transferWithSourceFile:(NSString *) path toUser:(MVChatUser *) user passively:(BOOL) passive {
	NSURL *url = [NSURL URLWithString:@"http://colloquy.info/ip.php"];
	NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:3.];
	NSMutableData *result = [[NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:NULL] mutableCopy];
	[result appendBytes:"\0" length:1];

	MVSILCUploadFileTransfer *transfer = [[MVSILCUploadFileTransfer allocWithZone:nil] initWithSessionID:0 toUser:user];
	transfer -> _source = [[path stringByStandardizingPath] copyWithZone:nil];

	SilcClientID *clientID = silc_id_str2id( [(NSData *)[user uniqueIdentifier] bytes], [(NSData *)[user uniqueIdentifier] length], SILC_ID_CLIENT );
	if( clientID ) {
		SilcLock( [[user connection] _silcClient] );

		SilcClientEntry client = silc_client_get_client_by_id( [[user connection] _silcClient], [[user connection] _silcConn], clientID );
		if( client ) {
			SilcUInt32 sessionid;
			SilcClientFileError error = silc_client_file_send( [[user connection] _silcClient], [[user connection] _silcConn], silc_client_file_monitor, (__bridge void *)transfer, [result bytes], 0, passive, client, [path fileSystemRepresentation], &sessionid);
			if( error != SILC_CLIENT_FILE_OK ) {
				[transfer _silcPostError:error];
				SilcUnlock( [[user connection] _silcClient] );
				return nil;
			}

			[transfer _setSessionID:sessionid];
		}

		SilcUnlock( [[user connection] _silcClient] );
	} else {

		return nil;
	}

	return transfer;
}

#pragma mark -

- (id) initWithSessionID:(SilcUInt32) sessionID toUser:(MVChatUser *) chatUser {
	if( ( self = [self initWithUser:chatUser] ) )
		[self _setSessionID:sessionID];
	return self;
}

#pragma mark -

- (void) cancel {
	[self _setStatus:MVFileTransferStoppedStatus];

	SilcLock( [[[self user] connection] _silcClient] );
	silc_client_file_close( [[[self user] connection] _silcClient], [[[self user] connection] _silcConn], [self _sessionID] );
	SilcUnlock( [[[self user] connection] _silcClient] );
}
@end

#pragma mark -

@implementation MVSILCUploadFileTransfer (MVSILCUploadFileTransferPrivate)
- (SilcUInt32) _sessionID {
	return _sessionID;
}

- (void) _setSessionID:(SilcUInt32) sessionID {
	_sessionID = sessionID;
}

@end

#pragma mark -

@implementation MVSILCDownloadFileTransfer
+ (void) initialize {
	[super initialize];
}

#pragma mark -

- (id) initWithSessionID:(SilcUInt32) sessionID toUser:(MVChatUser *) chatUser {
	if( ( self = [self initWithUser:chatUser] ) )
		[self _setSessionID:sessionID];
	return self;
}

#pragma mark -

- (void) reject {
	SilcLock( [[[self user] connection] _silcClient] );
	silc_client_file_close( [[[self user] connection] _silcClient], [[[self user] connection] _silcConn], [self _sessionID] );
	SilcUnlock( [[[self user] connection] _silcClient] );
}

- (void) cancel {
	SilcLock( [[[self user] connection] _silcClient] );
	silc_client_file_close( [[[self user] connection] _silcClient], [[[self user] connection] _silcConn], [self _sessionID] );
	SilcUnlock( [[[self user] connection] _silcClient] );
}

#pragma mark -

- (void) accept {
	[self acceptByResumingIfPossible:YES];
}

- (void) acceptByResumingIfPossible:(BOOL) resume {
	if( ! [[NSFileManager defaultManager] isReadableFileAtPath:[self destination]] )
		resume = NO;
}
@end

#pragma mark -

@implementation MVSILCDownloadFileTransfer (MVSILCDownloadFileTransferPrivate)
- (SilcUInt32) _sessionID {
	return _sessionID;
}

- (void) _setSessionID:(SilcUInt32) sessionID {
	_sessionID = sessionID;
}
@end

NS_ASSUME_NONNULL_END
