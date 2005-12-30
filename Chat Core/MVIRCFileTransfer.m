#import <sched.h>
#import <arpa/inet.h>

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

static NSRange portRange;

@implementation MVIRCUploadFileTransfer
+ (void) initialize {
	portRange = NSMakeRange( 1024, 20 );
}

+ (id) transferWithSourceFile:(NSString *) path toUser:(MVChatUser *) user passively:(BOOL) passive {
	static unsigned passiveId = 0;

	MVIRCUploadFileTransfer *ret = [(MVIRCUploadFileTransfer *)[MVIRCUploadFileTransfer allocWithZone:nil] initWithUser:user];
	[(MVIRCChatConnection *)[user connection] _addFileTransfer:ret];
	[ret _setSource:path];
	[ret _setPassive:passive];

	NSNumber *size = [[[NSFileManager defaultManager] fileAttributesAtPath:[ret source] traverseLink:YES] objectForKey:NSFileSize];
	[ret _setFinalSize:[size unsignedLongLongValue]];

	NSString *fileName = [[ret source] lastPathComponent];	
	ret->_fileNameQuoted = ( [fileName rangeOfString:@" "].location != NSNotFound );

	if( passive ) {
		passiveId++;
		if( passiveId > 1000 )
			passiveId = 1;
		ret->_passiveId = passiveId;
	} else {
		[ret _setupAndStart];
	}

	return [ret autorelease];
}

- (void) release {
	if( ( [self retainCount] - 1 ) == 1 )
		[(MVIRCChatConnection *)[[self user] connection] _removeFileTransfer:self];
	[super release];
}

- (void) dealloc {
	id old = _fileHandle;
	_fileHandle = nil;
	[old closeFile];
	[old release];

	_connectionThread = nil;

	[super dealloc];
}

- (void) cancel {
	[self _setStatus:MVFileTransferStoppedStatus];

	[self performSelector:@selector( _finish ) inThread:_connectionThread];

	id old = _fileHandle;
	_fileHandle = nil;
	[old closeFile];
	[old release];

	[(MVIRCChatConnection *)[[self user] connection] _removeFileTransfer:self];
}

#pragma mark -

- (void) socket:(AsyncSocket *) sock didAcceptNewSocket:(AsyncSocket *) newSocket {
	if( ! _clientConnection ) _clientConnection = [newSocket retain];
	else [newSocket disconnect];
}

- (void) socket:(AsyncSocket *) sock willDisconnectWithError:(NSError *) error {
	NSLog(@"upload DCC willDisconnectWithError: %@", error );
	[self _setStatus:MVFileTransferErrorStatus];
}

- (void) socketDidDisconnect:(AsyncSocket *) sock {
	if( [self status] != MVFileTransferDoneStatus && [self status] != MVFileTransferStoppedStatus )
		[self _setStatus:MVFileTransferErrorStatus];

	id old = _fileHandle;
	_fileHandle = nil;
	[old closeFile];
	[old release];

	[self _finish];
}

- (void) socket:(AsyncSocket *) sock didConnectToHost:(NSString *) host port:(UInt16) port {
	[self _setStatus:MVFileTransferNormalStatus];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVFileTransferStartedNotification object:self];
	[self _sendNextPacket];

	// now that we are connected deregister with the connection
	// do this last incase the connection is the last thing retaining us
	[(MVIRCChatConnection *)[[self user] connection] _removeFileTransfer:self];
}

- (void) socket:(AsyncSocket *) sock didWriteDataWithTag:(long) tag {
	unsigned long long progress = [self transfered] + tag;
	[self _setTransfered:progress];

	[_clientConnection readDataToLength:4 withTimeout:-1. tag:( progress == [self finalSize] )];
	if( progress < [self finalSize] ) [self _sendNextPacket];
}

- (void) socket:(AsyncSocket *) sock didReadData:(NSData *) data withTag:(long) tag {
	if( tag ) {
		[self _setStatus:MVFileTransferDoneStatus];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVFileTransferFinishedNotification object:self];
		[self _finish];
	}
}

#pragma mark -

- (void) _setupAndStart {
	BOOL directory = NO;
	BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[self source] isDirectory:&directory];
	if( directory || ! fileExists ) return;

	id old = _fileHandle;
	_fileHandle = [[NSFileHandle fileHandleForReadingAtPath:[self source]] retain];
	[old release];

	if( ! _fileHandle ) return;
	[_fileHandle seekToFileOffset:[self startOffset]];

	old = _connection;
	_connection = [[AsyncSocket allocWithZone:nil] initWithDelegate:self];
	[old release];

	if( ! _connectionThread ) {
		[NSThread prepareForInterThreadMessages];
		[NSThread detachNewThreadSelector:@selector( _dccRunloop ) toTarget:self withObject:nil];
		while( ! _connectionThread ) sched_yield();
	}

	if( ! [self isPassive] ) [self performSelector:@selector( _waitForConnection ) inThread:_connectionThread];	
}

- (void) _waitForConnection {
	unsigned int port = portRange.location;
	BOOL success = NO;
	while( ! success ) {
		if( [_connection acceptOnPort:port error:NULL] ) {
			success = YES;
			break;
		} else {
			[_connection disconnect];
			if( ++port > NSMaxRange( portRange ) )
				port = 0; // just use a random port since the user defined range is in use
		}
	}

	if( success ) {
		id address = [[(MVIRCChatConnection *)[[self user] connection] _chatConnection] localHost];
		if( [address rangeOfString:@"."].location != NSNotFound )
			address = [NSNumber numberWithUnsignedLong:ntohl( inet_addr( [address UTF8String] ) )];
		[self _setPort:[_connection localPort]];

		NSString *fileName = [[self source] lastPathComponent];
		if( _fileNameQuoted ) [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"SEND \"%@\" %@ %hu %llu", fileName, address, [self port], [self finalSize]]];
		else [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"SEND %@ %@ %hu %llu", fileName, address, [self port], [self finalSize]]];
	}
}

- (void) _sendNextPacket {
	NSData *data = [_fileHandle readDataOfLength:DCCPacketSize];

	if( [data length] > 0 ) {
		[_clientConnection writeData:data withTimeout:-1 tag:[data length]];
	} else {
		[self _setStatus:MVFileTransferErrorStatus];
		[self _finish];
	}
}

- (void) _finish {
	id old = _connection;
	_connection = nil;
	[old setDelegate:nil];
	[old release];

	old = _clientConnection;
	_clientConnection = nil;
	[old setDelegate:nil];
	[old release];

	_done = YES;
}

- (oneway void) _dccRunloop {
	NSAutoreleasePool *pool = [[NSAutoreleasePool allocWithZone:nil] init];
	[self retain];

	_connectionThread = [NSThread currentThread];
	[NSThread prepareForInterThreadMessages];
	[NSThread setThreadPriority:0.75];

	BOOL active = YES;
	while( active && ! _done ) {
		NSDate *timeout = [[NSDate allocWithZone:nil] initWithTimeIntervalSinceNow:5.];
		active = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:timeout];
		[timeout release];
	}

	_connectionThread = nil;

	[self _finish];
	[self release];

	[pool release];
}
@end

#pragma mark -

@implementation MVIRCDownloadFileTransfer
- (void) release {
	if( ( [self retainCount] - 1 ) == 1 )
		[(MVIRCChatConnection *)[[self user] connection] _removeFileTransfer:self];
	[super release];
}

- (void) dealloc {
	id old = _fileHandle;
	_fileHandle = nil;
	[old synchronizeFile];
	[old closeFile];
	[old release];

	_connectionThread = nil;

	[super dealloc];
}

- (void) reject {
	if( _fileNameQuoted ) [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"REJECT \"%@\"", [self originalFileName]]];
	else [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"REJECT %@", [self originalFileName]]];
	[self cancel];
}

- (void) cancel {
	[self _setStatus:MVFileTransferStoppedStatus];

	[self performSelector:@selector( _finish ) inThread:_connectionThread];

	id old = _fileHandle;
	_fileHandle = nil;
	[old closeFile];
	[old release];

	[(MVIRCChatConnection *)[[self user] connection] _removeFileTransfer:self];
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
				if( _fileNameQuoted ) [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"RESUME \"%@\" %hu %llu", [self originalFileName], [self port], [size unsignedLongLongValue]]];
				else [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"RESUME %@ %hu %llu", [self originalFileName], [self port], [size unsignedLongLongValue]]];
			}
			return; // we need to wait until we get an ACCEPT reply
		}
	}

	[self _setupAndStart];
}

#pragma mark -

- (void) socket:(AsyncSocket *) sock willDisconnectWithError:(NSError *) error {
	NSLog(@"download DCC willDisconnectWithError: %@", error );
	[self _setStatus:MVFileTransferErrorStatus];
}

- (void) socketDidDisconnect:(AsyncSocket *) sock {
	if( [self status] != MVFileTransferDoneStatus && [self status] != MVFileTransferStoppedStatus )
		[self _setStatus:MVFileTransferErrorStatus];

	id old = _fileHandle;
	_fileHandle = nil;
	[old synchronizeFile];
	[old closeFile];
	[old release];

	_done = YES;
}

- (void) socket:(AsyncSocket *) sock didConnectToHost:(NSString *) host port:(UInt16) port {
	[self _setStatus:MVFileTransferNormalStatus];

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVFileTransferStartedNotification object:self];

	unsigned long long progress = [self transfered];
	unsigned long long packet = DCCPacketSize;
	if( ( progress + packet ) > [self finalSize] )
		packet = [self finalSize] - progress;
	[_connection readDataToLength:packet withTimeout:-1. tag:0];

	// now that we are connected deregister with the connection
	// do this last incase the connection is the last thing retaining us
	[(MVIRCChatConnection *)[[self user] connection] _removeFileTransfer:self];
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
		_done = YES;
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

	id old = _fileHandle;
	_fileHandle = [[NSFileHandle fileHandleForWritingAtPath:[self destination]] retain];
	[old release];

	if( ! _fileHandle ) return;
	[_fileHandle truncateFileAtOffset:[self startOffset]];

	old = _connection;
	_connection = [[AsyncSocket allocWithZone:nil] initWithDelegate:self];
	[old release];

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

- (void) _finish {
	id old = _connection;
	_connection = nil;
	[old setDelegate:nil];
	[old release];

	_done = YES;
}

- (oneway void) _dccRunloop {
	NSAutoreleasePool *pool = [[NSAutoreleasePool allocWithZone:nil] init];
	[self retain];

	_connectionThread = [NSThread currentThread];
	[NSThread prepareForInterThreadMessages];
	[NSThread setThreadPriority:0.75];

	BOOL active = YES;
	while( active && ! _done ) {
		NSDate *timeout = [[NSDate allocWithZone:nil] initWithTimeIntervalSinceNow:5.];
		active = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:timeout];
		[timeout release];
	}

	_connectionThread = nil;

	[self _finish];
	[self release];

	[pool release];
}
@end
