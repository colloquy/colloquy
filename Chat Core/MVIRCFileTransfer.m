#import "MVIRCFileTransfer.h"

#import "AsyncSocket.h"
#import "InterThreadMessaging.h"
#import "MVChatUser.h"
#import "MVDirectClientConnection.h"
#import "MVIRCChatConnection.h"
#import "MVUtilities.h"
#import "NSNotificationAdditions.h"
#import "Transmission.h"

#import <arpa/inet.h>

#define DCCPacketSize 4096

@implementation MVIRCUploadFileTransfer
+ (id) transferWithSourceFile:(NSString *) path toUser:(MVChatUser *) user passively:(BOOL) passive {
	static NSUInteger passiveId = 0;

	MVIRCUploadFileTransfer *ret = [(MVIRCUploadFileTransfer *)[MVIRCUploadFileTransfer allocWithZone:nil] initWithUser:user];
	[ret _setSource:path];
	[ret _setPassive:passive];

	NSNumber *size = [[[NSFileManager defaultManager] attributesOfItemAtPath:[ret source] error:NULL] objectForKey:NSFileSize];
	[ret _setFinalSize:[size unsignedLongLongValue]];

	NSString *fileName = [[ret source] lastPathComponent];
	[ret _setFileNameQuoted:( [fileName rangeOfString:@" "].location != NSNotFound )];

	[(MVIRCChatConnection *)[user connection] _addDirectClientConnection:ret];

	if( passive ) {
		if( ++passiveId > 999 ) passiveId = 1;
		[ret _setPassiveIdentifier:passiveId];

		if( [ret _fileNameQuoted] ) [user sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"SEND \"%@\" 16843009 0 %llu %lu T", fileName, [ret finalSize], passiveId]];
		else [user sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"SEND %@ 16843009 0 %llu %lu T", fileName, [ret finalSize], passiveId]];
	} else {
		[ret _setupAndStart];
	}

	return [ret autorelease];
}

#pragma mark -

- (oneway void) release {
	if( ! _releasing && ( [self retainCount] - 1 ) == 1 ) {
		_releasing = YES;
		[(MVIRCChatConnection *)[[self user] connection] _removeDirectClientConnection:self];
	}

	[super release];
}

- (void) dealloc {
	[_directClientConnection disconnect];
	[_directClientConnection setDelegate:nil];
	[_directClientConnection release];

	[_fileHandle closeFile];
	[_fileHandle release];

	[super dealloc];
}

- (void) finalize {
	[_directClientConnection disconnect];
	[_fileHandle closeFile];

	[super finalize];
}

#pragma mark -

- (void) cancel {
	[self _setStatus:MVFileTransferStoppedStatus];

	[_directClientConnection disconnect];

	id old = _fileHandle;
	_fileHandle = nil;
	[old closeFile];
	[old release];

	// do this last incase the connection is the last thing retaining us
	[(MVIRCChatConnection *)[[self user] connection] _removeDirectClientConnection:self];
}

#pragma mark -

- (void) directClientConnection:(MVDirectClientConnection *) connection didConnectToHost:(NSString *) host port:(unsigned short) port {
	[self _setStatus:MVFileTransferNormalStatus];
	[self _setStartDate:[NSDate date]];

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVFileTransferStartedNotification object:self];

	[self _sendNextPacket];

	// read for the bytes received acknowledgment packet
	[_directClientConnection readDataToLength:4 withTimeout:-1. withTag:0];

	// now that we are connected deregister with the connection
	// do this last incase the connection is the last thing retaining us
	[(MVIRCChatConnection *)[[self user] connection] _removeDirectClientConnection:self];
}

- (void) directClientConnection:(MVDirectClientConnection *) connection acceptingConnectionsToHost:(NSString *) host port:(unsigned short) port {
	NSString *address = MVDCCFriendlyAddress( host );
	[self _setPort:port];

	NSString *fileName = [[self source] lastPathComponent];
	if( _fileNameQuoted ) [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"SEND \"%@\" %@ %hu %llu T", fileName, address, [self port], [self finalSize]]];
	else [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"SEND %@ %@ %hu %llu T", fileName, address, [self port], [self finalSize]]];
}

- (void) directClientConnection:(MVDirectClientConnection *) connection willDisconnectWithError:(NSError *) error {
	NSLog(@"upload DCC willDisconnectWithError: %@", error );
	if( [self status] != MVFileTransferDoneStatus && [self status] != MVFileTransferStoppedStatus )
		[self _setStatus:MVFileTransferErrorStatus];
}

- (void) directClientConnectionDidDisconnect:(MVDirectClientConnection *) connection {
	if( [self status] != MVFileTransferDoneStatus && [self transferred] == [self finalSize] && _doneSending ) {
		[self _setStatus:MVFileTransferDoneStatus];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVFileTransferFinishedNotification object:self];
	}

	if( [self status] != MVFileTransferDoneStatus && [self status] != MVFileTransferStoppedStatus )
		[self _setStatus:MVFileTransferErrorStatus];

	id old = _fileHandle;
	_fileHandle = nil;
	[old closeFile];
	[old release];
}

- (void) directClientConnection:(MVDirectClientConnection *) connection didWriteDataWithTag:(long) tag {
	if( ! _readData || [_fileHandle offsetInFile] > 0xffffffff ) {
		// the transfer is in turbo mode or the file offset is larger than 4GB, so update the progress here
		unsigned long long progress = [self transferred] + (unsigned long)tag;
		[self _setTransferred:progress];
	}

	[self _sendNextPacket];
}

- (void) directClientConnection:(MVDirectClientConnection *) connection didReadData:(NSData *) data withTag:(long) tag {
	// data is a bytes received acknowledgment packet, only gotten when the transfer is not in turbo mode
	_readData = YES;

	unsigned long bytes = ntohl( *( (unsigned long *) [data bytes] ) );
	if( bytes > [self transferred] ) [self _setTransferred:bytes];

	if( _doneSending && bytes == ( [self finalSize] & 0xffffffff ) ) {
		[self _setStatus:MVFileTransferDoneStatus];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVFileTransferFinishedNotification object:self];
		[_directClientConnection disconnectAfterWriting];
	} else {
		// not finished, read for the next bytes received acknowledgment packet
		[_directClientConnection readDataToLength:4 withTimeout:-1. withTag:0];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVFileTransferDataTransferredNotification object:self];
	}
}

#pragma mark -

- (void) _setupAndStart {
	if( [_directClientConnection connectionThread] ) return;

	BOOL directory = NO;
	BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[self source] isDirectory:&directory];
	if( directory || ! fileExists ) return;

	MVSafeRetainAssign( _fileHandle, [NSFileHandle fileHandleForReadingAtPath:[self source]] );
	if( ! _fileHandle ) return;

	[_fileHandle seekToFileOffset:[self startOffset]];

	MVSafeAdoptAssign( _directClientConnection, [[MVDirectClientConnection allocWithZone:nil] init] );
	[_directClientConnection setDelegate:self];

	if( ! [self isPassive] ) [_directClientConnection acceptConnectionOnFirstPortInRange:[[self class] fileTransferPortRange]];
	else [_directClientConnection connectToHost:[self host] onPort:[self port]];
}

- (void) _sendNextPacket {
	MVAssertCorrectThreadRequired( [_directClientConnection connectionThread] );

	NSData *data = [_fileHandle readDataOfLength:DCCPacketSize];
	if( data.length > 0 ) [_directClientConnection writeData:data withTimeout:-1 withTag:data.length];
	else _doneSending = YES;
}

#pragma mark -

- (void) _setPassiveIdentifier:(long long) identifier {
	_passiveId = identifier;
}

- (long long) _passiveIdentifier {
	return _passiveId;
}

#pragma mark -

- (void) _setFileNameQuoted:(BOOL) quoted {
	_fileNameQuoted = quoted;
}

- (BOOL) _fileNameQuoted {
	return _fileNameQuoted;
}

#pragma mark -

- (void) _setStartOffset:(unsigned long long) newStartOffset {
	[_fileHandle seekToFileOffset:newStartOffset];
	[super _setStartOffset:newStartOffset];
}
@end

#pragma mark -

@implementation MVIRCDownloadFileTransfer
- (oneway void) release {
	if( ! _releasing && ( [self retainCount] - 1 ) == 1 ) {
		_releasing = YES;
		[(MVIRCChatConnection *)[[self user] connection] _removeDirectClientConnection:self];
	}

	[super release];
}

- (void) dealloc {
	[_directClientConnection disconnect];
	[_directClientConnection setDelegate:nil];
	[_directClientConnection release];

	[_fileHandle synchronizeFile];
	[_fileHandle closeFile];
	[_fileHandle release];

	[super dealloc];
}

- (void) finalize {
	[_directClientConnection disconnect];
	[_fileHandle synchronizeFile];
	[_fileHandle closeFile];

	[super finalize];
}

#pragma mark -

- (void) reject {
	if( [self isPassive] ) {
		if( _fileNameQuoted ) [[self user] sendSubcodeReply:@"DCC" withArguments:[NSString stringWithFormat:@"REJECT SEND \"%@\" 16843009 0 %llu %lu T", [self originalFileName], [self finalSize], [self _passiveIdentifier]]];
		else [[self user] sendSubcodeReply:@"DCC" withArguments:[NSString stringWithFormat:@"REJECT SEND %@ 16843009 0 %llu %lu T", [self originalFileName], [self finalSize], [self _passiveIdentifier]]];
	} else {
		NSString *address = [self host];
		if( ! address ) address = @"16843009";
		if( address && [address rangeOfString:@"."].location != NSNotFound )
			address = [NSString stringWithFormat:@"%lu", ntohl( inet_addr( [address UTF8String] ) )];
		if( _fileNameQuoted ) [[self user] sendSubcodeReply:@"DCC" withArguments:[NSString stringWithFormat:@"REJECT SEND \"%@\" %@ %hu %llu T", [self originalFileName], address, [self port], [self finalSize]]];
		else [[self user] sendSubcodeReply:@"DCC" withArguments:[NSString stringWithFormat:@"REJECT SEND %@ %@ %hu %llu T", [self originalFileName], address, [self port], [self finalSize]]];
	}

	[self cancel];
}

- (void) cancel {
	[self _setStatus:MVFileTransferStoppedStatus];

	[_directClientConnection disconnect];

	id old = _fileHandle;
	_fileHandle = nil;
	[old synchronizeFile];
	[old closeFile];
	[old release];

	// do this last incase the connection is the last thing retaining us
	[(MVIRCChatConnection *)[[self user] connection] _removeDirectClientConnection:self];
}

- (void) acceptByResumingIfPossible:(BOOL) resume {
	if( resume ) {
		NSNumber *size = [[[NSFileManager defaultManager] attributesOfItemAtPath:[self destination] error:NULL] objectForKey:NSFileSize];
		BOOL fileExists = [[NSFileManager defaultManager] isWritableFileAtPath:[self destination]];

		if( fileExists && [size unsignedLongLongValue] < [self finalSize] ) {
			if( [self isPassive] ) {
				if( _fileNameQuoted ) [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"RESUME \"%@\" 0 %llu %lu", [self originalFileName], [size unsignedLongLongValue], _passiveId]];
				else [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"RESUME %@ 0 %llu %lu", [self originalFileName], [size unsignedLongLongValue], _passiveId]];
			} else {
				if( _fileNameQuoted ) [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"RESUME \"%@\" %hu %llu", [self originalFileName], [self port], [size unsignedLongLongValue]]];
				else [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"RESUME %@ %hu %llu", [self originalFileName], [self port], [size unsignedLongLongValue]]];
			}

			return; // we need to wait until we get a DCC ACCEPT reply
		}
	}

	[self _setupAndStart];
}

#pragma mark -

- (void) directClientConnection:(MVDirectClientConnection *) connection didConnectToHost:(NSString *) host port:(unsigned short) port {
	[self _setStatus:MVFileTransferNormalStatus];
	[self _setStartDate:[NSDate date]];

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVFileTransferStartedNotification object:self];

	[_directClientConnection readDataWithTimeout:-1. withTag:0];

	// now that we are connected deregister with the connection
	// do this last incase the connection is the last thing retaining us
	[(MVIRCChatConnection *)[[self user] connection] _removeDirectClientConnection:self];
}

- (void) directClientConnection:(MVDirectClientConnection *) connection acceptingConnectionsToHost:(NSString *) host port:(unsigned short) port {
	NSString *address = MVDCCFriendlyAddress( host );
	[self _setPort:port];

	NSString *fileName = [self originalFileName];
	if( _fileNameQuoted ) [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"SEND \"%@\" %@ %hu %llu %lu", fileName, address, [self port], [self finalSize], [self _passiveIdentifier]]];
	else [[self user] sendSubcodeRequest:@"DCC" withArguments:[NSString stringWithFormat:@"SEND %@ %@ %hu %llu %lu", fileName, address, [self port], [self finalSize], [self _passiveIdentifier]]];
}

- (void) directClientConnection:(MVDirectClientConnection *) connection willDisconnectWithError:(NSError *) error {
	NSLog(@"download DCC willDisconnectWithError: %@", error );
	if( [self status] != MVFileTransferDoneStatus && [self status] != MVFileTransferStoppedStatus )
		[self _setStatus:MVFileTransferErrorStatus];
}

- (void) directClientConnectionDidDisconnect:(MVDirectClientConnection *) connection {
	if( [self status] != MVFileTransferDoneStatus && [self status] != MVFileTransferStoppedStatus )
		[self _setStatus:MVFileTransferErrorStatus];

	id old = _fileHandle;
	_fileHandle = nil;
	[old synchronizeFile];
	[old closeFile];
	[old release];
}

- (void) directClientConnection:(MVDirectClientConnection *) connection didReadData:(NSData *) data withTag:(long) tag {
	unsigned long long progress = [self transferred] + data.length;
	[self _setTransferred:progress];

	[_fileHandle writeData:data];

	if( ! _turbo ) {
		// dcc only supports a 4 GB limit with these acknowledgment packets, we will acknowledge
		// that we have all the bytes but keep reading if the file is over 4 GB
		unsigned long progressToSend = htonl( progress & 0xffffffff );
		NSData *length = [[NSData allocWithZone:nil] initWithBytes:&progressToSend length:4];
		[_directClientConnection writeData:length withTimeout:-1 withTag:0];
		[length release];
	}

	if( progress == [self finalSize] ) {
		[self _setStatus:MVFileTransferDoneStatus];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVFileTransferFinishedNotification object:self];
		[_directClientConnection disconnectAfterWriting];
	} else {
		[_directClientConnection readDataWithTimeout:-1. withTag:0];
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:MVFileTransferDataTransferredNotification object:self];
	}
}

#pragma mark -

- (void) _setupAndStart {
	if( [_directClientConnection connectionThread] ) return;

	BOOL directory = NO;
	BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[self destination] isDirectory:&directory];
	if( directory ) return;
	if( ! fileExists ) [[NSData data] writeToFile:[self destination] atomically:NO];
	fileExists = [[NSFileManager defaultManager] isWritableFileAtPath:[self destination]];
	if( ! fileExists ) return;

	MVSafeRetainAssign( _fileHandle, [NSFileHandle fileHandleForWritingAtPath:[self destination]] );
	if( ! _fileHandle ) return;

	[_fileHandle truncateFileAtOffset:[self startOffset]];

	MVSafeAdoptAssign( _directClientConnection, [[MVDirectClientConnection allocWithZone:nil] init] );
	[_directClientConnection setDelegate:self];

	if( [self isPassive] ) [_directClientConnection acceptConnectionOnFirstPortInRange:[[self class] fileTransferPortRange]];
	else [_directClientConnection connectToHost:[self host] onPort:[self port]];
}

#pragma mark -

- (void) _setTurbo:(BOOL) turbo {
	_turbo = turbo;
}

- (BOOL) _turbo {
	return _turbo;
}

#pragma mark -

- (void) _setPassiveIdentifier:(long long) identifier {
	_passiveId = identifier;
}

- (long long) _passiveIdentifier {
	return _passiveId;
}

#pragma mark -

- (void) _setFileNameQuoted:(BOOL) quoted {
	_fileNameQuoted = quoted;
}

- (BOOL) _fileNameQuoted {
	return _fileNameQuoted;
}
@end
