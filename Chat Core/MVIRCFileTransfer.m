#import <sched.h>

#import "MVIRCFileTransfer.h"
#import "MVIRCChatConnection.h"
#import "MVChatUser.h"
#import "NSNotificationAdditions.h"
#import "AsyncSocket.h"
#import "InterThreadMessaging.h"

#define DCCPacketSize 4096

/*static void MVFileTransferClosed( FILE_DCC_REC *dcc ) {
	MVFileTransfer *self = [MVFileTransfer _transferForDCCFileRecord:dcc];
	if( ! self ) return;

	if( [self status] == MVFileTransferStoppedStatus ) {
		// nothing to do
	} else if( [self finalSize] != [self transfered] ) {
		NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:@"The file transfer terminated unexpectedly.", NSLocalizedDescriptionKey, nil];
		NSError *error = [[NSError allocWithZone:nil] initWithDomain:MVFileTransferErrorDomain code:MVFileTransferUnexpectedlyEndedError userInfo:info];
		[self performSelectorOnMainThread:@selector( _postError: ) withObject:error waitUntilDone:NO];
		[error release];
		[info release];
	} else {
		[self _setStatus:MVFileTransferDoneStatus];
		NSNotification *note = [NSNotification notificationWithName:MVFileTransferFinishedNotification object:self];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThread:note];
	}
}

static void MVFileTransferErrorConnect( FILE_DCC_REC *dcc ) {
	MVFileTransfer *self = [MVFileTransfer _transferForDCCFileRecord:dcc];
	if( ! self ) return;

	[self performSelector:@selector( _destroying )];

	NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:@"The file transfer connection could not be made.", NSLocalizedDescriptionKey, nil];
	NSError *error = [[NSError allocWithZone:nil] initWithDomain:MVFileTransferErrorDomain code:MVFileTransferConnectionError userInfo:info];
	[self performSelectorOnMainThread:@selector( _postError: ) withObject:error waitUntilDone:NO];
	[error release];
	[info release];
}

static void MVFileTransferErrorFileCreate( FILE_DCC_REC *dcc, char *filename ) {
	MVFileTransfer *self = [MVFileTransfer _transferForDCCFileRecord:dcc];
	if( ! self ) return;

	[self performSelector:@selector( _destroying )];

	NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:@"The file %@ could not be created, please make sure you have write permissions in the %@ folder.", NSLocalizedDescriptionKey, nil];
	NSError *error = [[NSError allocWithZone:nil] initWithDomain:MVFileTransferErrorDomain code:MVFileTransferFileCreationError userInfo:info];
	[self performSelectorOnMainThread:@selector( _postError: ) withObject:error waitUntilDone:NO];
	[error release];
	[info release];
}

static void MVFileTransferErrorFileOpen( FILE_DCC_REC *dcc, char *filename, int errno ) {
	MVFileTransfer *self = [MVFileTransfer _transferForDCCFileRecord:dcc];
	if( ! self ) return;

	[self performSelector:@selector( _destroying )];

	NSError *ferror = [[NSError allocWithZone:nil] initWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
	NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:@"The file %@ could not be opened, please make sure you have read permissions for this file.", NSLocalizedDescriptionKey, ferror, @"NSUnderlyingErrorKey", nil];
	NSError *error = [[NSError allocWithZone:nil] initWithDomain:MVFileTransferErrorDomain code:MVFileTransferFileOpenError userInfo:info];
	[self performSelectorOnMainThread:@selector( _postError: ) withObject:error waitUntilDone:NO];
	[error release];
	[ferror release];
	[info release];
}

static void MVFileTransferErrorSendExists( FILE_DCC_REC *dcc, char *nick, char *filename ) {
	MVFileTransfer *self = [MVFileTransfer _transferForDCCFileRecord:dcc];
	if( ! self ) return;

	[self performSelector:@selector( _destroying )];

	NSDictionary *info = [[NSDictionary allocWithZone:nil] initWithObjectsAndKeys:@"The file %@ is already being offerend to %@.", NSLocalizedDescriptionKey, nil];
	NSError *error = [[NSError allocWithZone:nil] initWithDomain:MVFileTransferErrorDomain code:MVFileTransferAlreadyExistsError userInfo:info];
	[self performSelectorOnMainThread:@selector( _postError: ) withObject:error waitUntilDone:NO];
	[error release];
	[info release];
} */

#pragma mark -

@implementation MVIRCUploadFileTransfer
+ (id) transferWithSourceFile:(NSString *) path toUser:(MVChatUser *) user passively:(BOOL) passive {
	NSURL *url = [NSURL URLWithString:@"http://colloquy.info/ip.php"];
	NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:3.];
	NSMutableData *result = [[NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:NULL] mutableCopyWithZone:nil];
	[result appendBytes:"\0" length:1];
	
	[result release];

	MVIRCUploadFileTransfer *ret = [[MVIRCUploadFileTransfer allocWithZone:nil] initWithUser:user];
	[ret _setSource:path];

	return [ret autorelease];
}

- (void) cancel {
	[self _setStatus:MVFileTransferStoppedStatus];
	[_connection release];
	_connection = nil;
}
@end

#pragma mark -

@implementation MVIRCDownloadFileTransfer
- (void) dealloc {
	[(MVIRCChatConnection *)[[self user] connection] _removeFileTransfer:self];

	[_fileHandle synchronizeFile];
	[_fileHandle closeFile];

	[_connection release];
	[_fileHandle release];

	_connection = nil;
	_connectionThread = nil;
	_fileHandle = nil;

	[super dealloc];
}

- (void) reject {
	if( _fileNameQuoted ) [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"REJECT \"%@\"", [self originalFileName]]];
	else [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"REJECT %@", [self originalFileName]]];
}

- (void) cancel {
	[self _setStatus:MVFileTransferStoppedStatus];
	[_connection release];
	_connection = nil;
}

- (void) acceptByResumingIfPossible:(BOOL) resume {
	if( resume ) {
		NSNumber *size = [[[NSFileManager defaultManager] fileAttributesAtPath:[self destination] traverseLink:YES] objectForKey:NSFileSize];
		BOOL fileExists = [[NSFileManager defaultManager] isWritableFileAtPath:[self destination]];

		if( fileExists && [size unsignedLongLongValue] < [self finalSize] ) {
			if( [self isPassive] ) {
				if( _fileNameQuoted ) [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"RESUME \"%@\" 0 %llu %lu", [self originalFileName], [size unsignedLongLongValue], _passiveId]];
				else [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"RESUME %@ 0 %llu %lu", [self originalFileName], [size unsignedLongLongValue], _passiveId]];
			} else {
				if( _fileNameQuoted ) [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"RESUME \"%@\" %lu %llu", [self originalFileName], [self port], [size unsignedLongLongValue]]];
				else [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"RESUME %@ %lu %llu", [self originalFileName], [self port], [size unsignedLongLongValue]]];
			}
			return; // we need to wait until we get an ACCEPT reply
		}
	}

	[self _setupAndStart];
}

#pragma mark -

- (void) socket:(AsyncSocket *) sock willDisconnectWithError:(NSError *) error {
	NSLog(@"DCC willDisconnectWithError: %@", error );
	[self _setStatus:MVFileTransferErrorStatus];
}

- (void) socketDidDisconnect:(AsyncSocket *) sock {
	if( [self status] != MVFileTransferDoneStatus )
		[self _setStatus:MVFileTransferErrorStatus];

	[_fileHandle synchronizeFile];
	[_fileHandle closeFile];
	[_fileHandle release];
	_fileHandle = nil;
}

- (void) socket:(AsyncSocket *) sock didConnectToHost:(NSString *) host port:(UInt16) port {
	[self _setStatus:MVFileTransferNormalStatus];

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVFileTransferStartedNotification object:self];

	unsigned long long progress = [self transfered];
	unsigned long long packet = DCCPacketSize;
	if( ( progress + packet ) > [self finalSize] )
		packet = [self finalSize] - progress;
	[_connection readDataToLength:packet withTimeout:-1. tag:0];
}

- (void) socket:(AsyncSocket *) sock didReadData:(NSData *) data withTag:(long) tag {
	unsigned long long progress = [self transfered] + [data length];
	[self _setTransfered:progress];

	// dcc only supports a 2 GB limit with these acknowledgment packets, we will acknowledge
	// that we have all the bytes but keep reading if the file is over 2 GB
	unsigned long progressToSend = htonl( progress & 0xffffffff );
	NSData *length = [[NSData allocWithZone:nil] initWithBytes:&progressToSend length:4];
	[_connection writeData:length withTimeout:-1 tag:0];
	[length release];

	[_fileHandle writeData:data];

	if( progress < [self finalSize] ) {
		unsigned long long packet = DCCPacketSize;
		if( ( progress + packet ) > [self finalSize] )
			packet = [self finalSize] - progress;
		[_connection readDataToLength:packet withTimeout:-1. tag:0];
	} else {
		[self _setStatus:MVFileTransferDoneStatus];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVFileTransferFinishedNotification object:self];
		[_connection disconnect];
	}
}

#pragma mark -

- (void) _setupAndStart {
	BOOL directory = NO;
	BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[self destination] isDirectory:&directory];
	if( directory ) return;
	if( ! fileExists ) [[NSData data] writeToFile:[self destination] atomically:NO];
	fileExists = [[NSFileManager defaultManager] isWritableFileAtPath:[self destination]];
	if( ! fileExists ) return;

	[_fileHandle release];
	_fileHandle = [[NSFileHandle fileHandleForWritingAtPath:[self destination]] retain];
	if( ! _fileHandle ) return;
	[_fileHandle truncateFileAtOffset:[self startOffset]];

	[_connection release];
	_connection = [[AsyncSocket allocWithZone:nil] initWithDelegate:self];

	if( ! _connectionThread ) {
		[NSThread prepareForInterThreadMessages];
		[NSThread detachNewThreadSelector:@selector( _dccRunloop ) toTarget:self withObject:nil];
		while( ! _connectionThread ) sched_yield();
	}

	[self performSelector:@selector( _connect ) inThread:_connectionThread];	
}

- (void) _connect {
	if( ! [_connection connectToHost:[[self host] address] onPort:[self port] error:NULL] ) {
		NSLog(@"can't connect to DCC" );
		return;
	}
}

- (oneway void) _dccRunloop {
	NSAutoreleasePool *pool = [[NSAutoreleasePool allocWithZone:nil] init];

	_connectionThread = [NSThread currentThread];
	[NSThread prepareForInterThreadMessages];
	[NSThread setThreadPriority:0.75];

	BOOL active = YES;
	while( active && ( [self status] == MVFileTransferNormalStatus || [self status] == MVFileTransferHoldingStatus ) )
		active = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];

	if( [NSThread currentThread] == _connectionThread )
		_connectionThread = nil;

	[pool release];
}
@end
