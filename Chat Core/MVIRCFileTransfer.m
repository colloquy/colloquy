#import <arpa/inet.h>

#import "MVIRCFileTransfer.h"
#import "MVIRCChatConnection.h"
#import "MVChatUser.h"
#import "NSNotificationAdditions.h"
#import "AsyncSocket.h"
#import "InterThreadMessaging.h"
#import "Transmission.h"

#define DCCPacketSize 4096

static int natTraversalStatus( tr_upnp_t *upnp, tr_natpmp_t *natpmp ) {
	int statuses[] = {
		TR_NAT_TRAVERSAL_MAPPED,
		TR_NAT_TRAVERSAL_MAPPING,
		TR_NAT_TRAVERSAL_UNMAPPING,
		TR_NAT_TRAVERSAL_ERROR,
		TR_NAT_TRAVERSAL_NOTFOUND,
		TR_NAT_TRAVERSAL_DISABLED,
		-1
	};

	int upnpStatus = TR_NAT_TRAVERSAL_DISABLED;
	int natpmpStatus = TR_NAT_TRAVERSAL_DISABLED;

	if( upnp ) upnpStatus = tr_upnpStatus( upnp );
	if( natpmp ) natpmpStatus = tr_natpmpStatus( natpmp );

	for( unsigned i = 0; statuses[i] >= 0; i++ )
		if( statuses[i] == upnpStatus || statuses[i] == natpmpStatus )
			return statuses[i];

	return TR_NAT_TRAVERSAL_ERROR;
}

static BOOL acceptConnectionOnFirstPortInRange( id transfer, AsyncSocket *connection, NSRange ports ) {
	unsigned int port = ports.location;
	BOOL success = NO;
	while( ! success ) {
		if( [connection acceptOnPort:port error:NULL] ) {
			success = YES;
			break;
		} else {
			[connection disconnect];
			if( port == 0 ) break;
			if( ++port > NSMaxRange( ports ) )
				port = 0; // just use a random port since the user defined range is in use
		}
	}

	if( success && [[transfer class] isAutoPortMappingEnabled] ) {
		tr_msgInit();

		static tr_fd_t *fd = NULL;
		if( ! fd ) fd = tr_fdInit();
		if( fd ) {
			tr_upnp_t *upnp = tr_upnpInit( fd );
			tr_upnpStart( upnp );
			tr_upnpForwardPort( upnp, port );
			[transfer _setUPnP:upnp];

			tr_natpmp_t *natpmp = tr_natpmpInit( fd );
			tr_natpmpStart( natpmp );
			tr_natpmpForwardPort( natpmp, port );
			[transfer _setNATPMP:natpmp];

			NSDate *mappingStart = [NSDate date];
			int status = 0;
			do {
				tr_upnpPulse( upnp );
				tr_natpmpPulse( natpmp );
				status = natTraversalStatus( upnp, natpmp );
			} while( ( status == TR_NAT_TRAVERSAL_MAPPING || status == TR_NAT_TRAVERSAL_NOTFOUND )
					   && ABS( [mappingStart timeIntervalSinceNow] ) < 5. ); 
		}
	}

	return success;
}

static NSString *dccFriendlyAddress( AsyncSocket *connection ) {
	NSString *address = [connection localHost];

	NSURL *url = [NSURL URLWithString:@"http://colloquy.info/ip.php"];
	NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:3.];
	NSData *result = [NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:NULL];
	if( [result length] >= 6 && [result length] <= 40 ) // should be a valid IPv4 or IPv6 address
		address = [[[NSString allocWithZone:nil] initWithData:result encoding:NSASCIIStringEncoding] autorelease];

	if( [address rangeOfString:@"."].location != NSNotFound )
		return [NSString stringWithFormat:@"%lu", ntohl( inet_addr( [address UTF8String] ) )];
	return address;
}

@implementation MVIRCUploadFileTransfer
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

		if( ret->_fileNameQuoted ) [user sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"SEND \"%@\" 16843009 0 %llu %luT", fileName, [ret finalSize], passiveId]];
		else [user sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"SEND %@ 16843009 0 %llu %luT", fileName, [ret finalSize], passiveId]];
	} else {
		[ret _setupAndStart];
	}

	return [ret autorelease];
}

- (void) finalize {
	[_connection disconnect];
	[_fileHandle closeFile];

	if( _upnp ) tr_upnpClose( _upnp );
	_upnp = NULL;

	if( _natpmp ) tr_natpmpClose( _natpmp );
	_natpmp = NULL;

	[super finalize];
}

- (void) release {
	if( ! _releasing && ( [self retainCount] - 1 ) == 1 ) {
		_releasing = YES;
		[(MVIRCChatConnection *)[[self user] connection] _removeFileTransfer:self];
	}

	[super release];
}

- (void) dealloc {
	[_connection disconnect];
	[_connection setDelegate:nil];

	id old = _fileHandle;
	_fileHandle = nil;
	[old closeFile];
	[old release];

	if( _upnp ) tr_upnpClose( _upnp );
	_upnp = NULL;

	if( _natpmp ) tr_natpmpClose( _natpmp );
	_natpmp = NULL;

	_connectionThread = nil;

	[super dealloc];
}

- (void) cancel {
	[self _setStatus:MVFileTransferStoppedStatus];

	_done = YES; // the thread will disconnect when it ends

	id old = _fileHandle;
	_fileHandle = nil;
	[old closeFile];
	[old release];

	[(MVIRCChatConnection *)[[self user] connection] _removeFileTransfer:self];
}

#pragma mark -

- (void) socket:(AsyncSocket *) sock didAcceptNewSocket:(AsyncSocket *) newSocket {
	if( ! _connection ) _connection = [newSocket retain];
	else [newSocket disconnect];
}

- (void) socket:(AsyncSocket *) sock willDisconnectWithError:(NSError *) error {
	NSLog(@"upload DCC willDisconnectWithError: %@", error );
	if( [self status] != MVFileTransferDoneStatus && [self status] != MVFileTransferStoppedStatus )
		[self _setStatus:MVFileTransferErrorStatus];
}

- (void) socketDidDisconnect:(AsyncSocket *) sock {
	if( [self status] != MVFileTransferDoneStatus && [self transfered] == [self finalSize] ) {
		[self _setStatus:MVFileTransferDoneStatus];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVFileTransferFinishedNotification object:self];
	}

	if( [self status] != MVFileTransferDoneStatus && [self status] != MVFileTransferStoppedStatus )
		[self _setStatus:MVFileTransferErrorStatus];

	id old = _fileHandle;
	_fileHandle = nil;
	[old closeFile];
	[old release];

	_done = YES;
}

- (void) socket:(AsyncSocket *) sock didConnectToHost:(NSString *) host port:(UInt16) port {
	[self _setStatus:MVFileTransferNormalStatus];
	[self _setStartDate:[NSDate date]];

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVFileTransferStartedNotification object:self];

	[self _sendNextPacket];
	[_connection readDataToLength:4 withTimeout:-1. tag:0];

	// now that we are connected deregister with the connection
	// do this last incase the connection is the last thing retaining us
	[(MVIRCChatConnection *)[[self user] connection] _removeFileTransfer:self];
}

- (void) socket:(AsyncSocket *) sock didWriteDataWithTag:(long) tag {
	if( ! _readData || [_fileHandle offsetInFile] > 0xffffffff ) {
		unsigned long long progress = [self transfered] + tag;
		[self _setTransfered:progress];
	}

	if( ! _doneSending ) [self _sendNextPacket];
}

- (void) socket:(AsyncSocket *) sock didReadData:(NSData *) data withTag:(long) tag {
	unsigned long bytes = ntohl( *( (unsigned long *) [data bytes] ) );
	if( bytes > [self transfered] ) [self _setTransfered:bytes];

	[_connection readDataToLength:4 withTimeout:-1. tag:0];

	if( bytes == ( [self finalSize] & 0xffffffff ) ) {
		[self _setStatus:MVFileTransferDoneStatus];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVFileTransferFinishedNotification object:self];
		[_connection disconnectAfterWriting];
		_done = YES;
	}

	_readData = YES;
}

#pragma mark -

- (void) _setupAndStart {
	if( _connectionThread ) return;

	BOOL directory = NO;
	BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[self source] isDirectory:&directory];
	if( directory || ! fileExists ) return;

	_fileHandle = [[NSFileHandle fileHandleForReadingAtPath:[self source]] retain];
	if( ! _fileHandle ) return;
	[_fileHandle seekToFileOffset:[self startOffset]];

	_threadWaitLock = [[NSConditionLock allocWithZone:nil] initWithCondition:0];

	[NSThread detachNewThreadSelector:@selector( _dccRunloop ) toTarget:self withObject:nil];

	[_threadWaitLock lockWhenCondition:1];
	[_threadWaitLock unlockWithCondition:0];

	if( ! _connectionThread ) return;

	if( ! [self isPassive] ) [self performSelector:@selector( _waitForConnection ) inThread:_connectionThread];
	else [self performSelector:@selector( _connect ) inThread:_connectionThread];
}

- (void) _waitForConnection {
	_acceptConnection = [[AsyncSocket allocWithZone:nil] initWithDelegate:self];

	BOOL success = acceptConnectionOnFirstPortInRange( self, _acceptConnection, [[self class] fileTransferPortRange] );

	if( success ) {
		NSString *address = dccFriendlyAddress( _acceptConnection );
		[self _setPort:[_acceptConnection localPort]];

		NSString *fileName = [[self source] lastPathComponent];
		if( _fileNameQuoted ) [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"SEND \"%@\" %@ %hu %llu T", fileName, address, [self port], [self finalSize]]];
		else [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"SEND %@ %@ %hu %llu T", fileName, address, [self port], [self finalSize]]];
	} else _done = YES;
}

- (void) _connect {
	_connection = [[AsyncSocket allocWithZone:nil] initWithDelegate:self];

	if( ! [_connection connectToHost:[[self host] address] onPort:[self port] error:NULL] ) {
		NSLog(@"can't connect to DCC" );
		return;
	}
}

- (void) _sendNextPacket {
	NSData *data = [_fileHandle readDataOfLength:DCCPacketSize];
	if( [data length] > 0 ) [_connection writeData:data withTimeout:-1 tag:[data length]];
	else _doneSending = YES;
}

- (void) _finish {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector( _finish ) object:nil];	

	if( _upnp ) tr_upnpClose( _upnp );
	if( _natpmp ) tr_natpmpClose( _natpmp );

	id old = _acceptConnection;
	_acceptConnection = nil;
	[old setDelegate:nil];
	[old disconnect];
	[old release];

	old = _connection;
	_connection = nil;
	[old setDelegate:nil];
	[old disconnect];
	[old release];

	_done = YES;
}

- (oneway void) _dccRunloop {
	NSAutoreleasePool *pool = [[NSAutoreleasePool allocWithZone:nil] init];
	[self retain];

	[_threadWaitLock lockWhenCondition:0];

	_connectionThread = [NSThread currentThread];
	[NSThread prepareForInterThreadMessages];
	[NSThread setThreadPriority:0.75];

	[_threadWaitLock unlockWithCondition:1];

	BOOL active = YES;
	while( active && ! _done ) {
		if( _upnp ) tr_upnpPulse( _upnp );
		if( _natpmp ) tr_natpmpPulse( _natpmp );

		NSDate *timeout = [[NSDate allocWithZone:nil] initWithTimeIntervalSinceNow:5.];
		active = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:timeout];
		[timeout release];
	}

	[self _finish];
	[self release];

	if( [NSThread currentThread] == _connectionThread )
		_connectionThread = nil;

	if( [pool respondsToSelector:@selector( drain )] )
		[pool drain];
	[pool release];
}

- (unsigned int) _passiveIdentifier {
	return _passiveId;
}

- (void) _setStartOffset:(unsigned long long) newStartOffset {
	[_fileHandle seekToFileOffset:newStartOffset];
	[super _setStartOffset:newStartOffset];
}

- (void) _setUPnP:(tr_upnp_t *) upnp {
	_upnp = upnp;
}

- (void) _setNATPMP:(tr_natpmp_t *) natpmp {
	_natpmp = natpmp;
}
@end

#pragma mark -

@implementation MVIRCDownloadFileTransfer
- (void) finalize {
	[_connection disconnect];

	[_fileHandle closeFile];
	[_fileHandle synchronizeFile];

	if( _upnp ) tr_upnpClose( _upnp );
	_upnp = NULL;

	if( _natpmp ) tr_natpmpClose( _natpmp );
	_natpmp = NULL;

	[super finalize];
}

- (void) release {
	if( ! _releasing && ( [self retainCount] - 1 ) == 1 ) {
		_releasing = YES;
		[(MVIRCChatConnection *)[[self user] connection] _removeFileTransfer:self];
	}

	[super release];
}

- (void) dealloc {
	[_connection disconnect];
	[_connection setDelegate:nil];

	id old = _fileHandle;
	_fileHandle = nil;
	[old synchronizeFile];
	[old closeFile];
	[old release];

	if( _upnp ) tr_upnpClose( _upnp );
	_upnp = NULL;

	if( _natpmp ) tr_natpmpClose( _natpmp );
	_natpmp = NULL;

	_connectionThread = nil;

	[super dealloc];
}

- (void) reject {
	if( _fileNameQuoted ) [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"REJECT SEND \"%@\"", [self originalFileName]]];
	else [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"REJECT SEND %@", [self originalFileName]]];
	[self cancel];
}

- (void) cancel {
	[self _setStatus:MVFileTransferStoppedStatus];

	_done = YES; // the thread will disconnect when it ends

	id old = _fileHandle;
	_fileHandle = nil;
	[old synchronizeFile];
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

- (void) socket:(AsyncSocket *) sock didAcceptNewSocket:(AsyncSocket *) newSocket {
	if( ! _connection ) _connection = [newSocket retain];
	else [newSocket disconnect];
}

- (void) socket:(AsyncSocket *) sock willDisconnectWithError:(NSError *) error {
	NSLog(@"download DCC willDisconnectWithError: %@", error );
	if( [self status] != MVFileTransferDoneStatus && [self status] != MVFileTransferStoppedStatus )
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
	[self _setStartDate:[NSDate date]];

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVFileTransferStartedNotification object:self];

	[_connection readDataWithTimeout:-1. tag:0];

	// now that we are connected deregister with the connection
	// do this last incase the connection is the last thing retaining us
	[(MVIRCChatConnection *)[[self user] connection] _removeFileTransfer:self];
}

- (void) socket:(AsyncSocket *) sock didReadData:(NSData *) data withTag:(long) tag {
	unsigned long long progress = [self transfered] + [data length];
	[self _setTransfered:progress];

	[_fileHandle writeData:data];

	if( ! _turbo ) {
		// dcc only supports a 4 GB limit with these acknowledgment packets, we will acknowledge
		// that we have all the bytes but keep reading if the file is over 4 GB
		unsigned long progressToSend = htonl( progress & 0xffffffff );
		NSData *length = [[NSData allocWithZone:nil] initWithBytes:&progressToSend length:4];
		[_connection writeData:length withTimeout:-1 tag:0];
		[length release];
	}

	if( progress == [self finalSize] ) {
		[self _setStatus:MVFileTransferDoneStatus];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVFileTransferFinishedNotification object:self];
		[_connection disconnectAfterWriting];
		_done = YES;
	} else [_connection readDataWithTimeout:-1. tag:0];
}

#pragma mark -

- (void) _setupAndStart {
	if( _connectionThread ) return;

	BOOL directory = NO;
	BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[self destination] isDirectory:&directory];
	if( directory ) return;
	if( ! fileExists ) [[NSData data] writeToFile:[self destination] atomically:NO];
	fileExists = [[NSFileManager defaultManager] isWritableFileAtPath:[self destination]];
	if( ! fileExists ) return;

	_fileHandle = [[NSFileHandle fileHandleForWritingAtPath:[self destination]] retain];
	if( ! _fileHandle ) return;
	[_fileHandle truncateFileAtOffset:[self startOffset]];

	_threadWaitLock = [[NSConditionLock allocWithZone:nil] initWithCondition:0];

	[NSThread detachNewThreadSelector:@selector( _dccRunloop ) toTarget:self withObject:nil];

	[_threadWaitLock lockWhenCondition:1];
	[_threadWaitLock unlockWithCondition:0];

	if( ! _connectionThread ) return;

	if( ! [self isPassive] ) [self performSelector:@selector( _connect ) inThread:_connectionThread];
	else [self performSelector:@selector( _waitForConnection ) inThread:_connectionThread];
}

- (void) _connect {
	_connection = [[AsyncSocket allocWithZone:nil] initWithDelegate:self];

	if( ! [_connection connectToHost:[[self host] address] onPort:[self port] error:NULL] ) {
		NSLog(@"can't connect to DCC" );
		return;
	}
}

- (void) _waitForConnection {
	_acceptConnection = [[AsyncSocket allocWithZone:nil] initWithDelegate:self];

	BOOL success = acceptConnectionOnFirstPortInRange( self, _acceptConnection, [[self class] fileTransferPortRange] );

	if( success ) {
		NSString *address = dccFriendlyAddress( _acceptConnection );
		[self _setPort:[_acceptConnection localPort]];

		if( _fileNameQuoted ) [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"SEND \"%@\" %@ %hu %llu %lu", [self originalFileName], address, [self port], [self finalSize], [self _passiveIdentifier]]];
		else [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"SEND %@ %@ %hu %llu %lu", [self originalFileName], address, [self port], [self finalSize], [self _passiveIdentifier]]];
	} else _done = YES;
}

- (void) _finish {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector( _finish ) object:nil];	

	if( _upnp ) tr_upnpClose( _upnp );
	if( _natpmp ) tr_natpmpClose( _natpmp );

	id old = _connection;
	_connection = nil;
	[old setDelegate:nil];
	[old disconnect];
	[old release];

	old = _acceptConnection;
	_acceptConnection = nil;
	[old setDelegate:nil];
	[old disconnect];
	[old release];

	_done = YES;
}

- (oneway void) _dccRunloop {
	NSAutoreleasePool *pool = [[NSAutoreleasePool allocWithZone:nil] init];
	[self retain];

	[_threadWaitLock lockWhenCondition:0];

	_connectionThread = [NSThread currentThread];
	[NSThread prepareForInterThreadMessages];
	[NSThread setThreadPriority:0.75];

	[_threadWaitLock unlockWithCondition:1];

	BOOL active = YES;
	while( active && ! _done ) {
		if( _upnp ) tr_upnpPulse( _upnp );
		if( _natpmp ) tr_natpmpPulse( _natpmp );

		NSDate *timeout = [[NSDate allocWithZone:nil] initWithTimeIntervalSinceNow:5.];
		active = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:timeout];
		[timeout release];
	}

	[self _finish];
	[self release];

	if( [NSThread currentThread] == _connectionThread )
		_connectionThread = nil;

	if( [pool respondsToSelector:@selector( drain )] )
		[pool drain];
	[pool release];
}

- (void) _setTurbo:(BOOL) turbo {
	_turbo = turbo;
}

- (void) _setPassiveIdentifier:(unsigned int) identifier {
	_passiveId = identifier;
}

- (unsigned int) _passiveIdentifier {
	return _passiveId;
}

- (void) _setFileNameQuoted:(unsigned int) quoted {
	_fileNameQuoted = quoted;
}

- (void) _setUPnP:(tr_upnp_t *) upnp {
	_upnp = upnp;
}

- (void) _setNATPMP:(tr_natpmp_t *) natpmp {
	_natpmp = natpmp;
}
@end
