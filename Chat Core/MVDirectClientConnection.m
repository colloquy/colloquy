#import "MVDirectClientConnection.h"

#import "AsyncSocket.h"
#import "InterThreadMessaging.h"
#import "MVChatConnectionPrivate.h"
#import "MVFileTransfer.h"
#import "MVUtilities.h"
#import "Transmission.h"

#import <arpa/inet.h>

NSString *MVDCCFriendlyAddress( NSString *address ) {
	NSURL *url = [NSURL URLWithString:@"http://colloquy.info/ip.php"];
	NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:3.];
	NSData *result = [NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:NULL];
	if( [result length] >= 6 && [result length] <= 40 ) // should be a valid IPv4 or IPv6 address
		address = [[[NSString allocWithZone:nil] initWithData:result encoding:NSASCIIStringEncoding] autorelease];
	if( address && [address rangeOfString:@"."].location != NSNotFound )
		return [NSString stringWithFormat:@"%lu", ntohl( inet_addr( [address UTF8String] ) )];
	return address;
}

#if ENABLE(AUTO_PORT_MAPPING)
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
#endif

#pragma mark -

@interface MVDirectClientConnection (MVDirectClientConnectionPrivate)
- (void) _setupThread;
@end

#pragma mark -

@implementation MVDirectClientConnection
- (void) finalize {
	_done = YES;

	[_acceptConnection disconnect];
	[_connection disconnect];

#if ENABLE(AUTO_PORT_MAPPING)
	if( _upnp ) tr_upnpClose( _upnp );
	_upnp = NULL;

	if( _natpmp ) tr_natpmpClose( _natpmp );
	_natpmp = NULL;
#endif

	[super finalize];
}

- (void) dealloc {
	_done = YES;

	[_acceptConnection disconnect];
	[_acceptConnection setDelegate:nil];
	[_acceptConnection release];
	_acceptConnection = nil;

	[_connection disconnect];
	[_connection setDelegate:nil];
	[_connection release];
	_connection = nil;

	[_threadWaitLock release];
	_threadWaitLock = nil;

#if ENABLE(AUTO_PORT_MAPPING)
	if( _upnp ) tr_upnpClose( _upnp );
	_upnp = NULL;

	if( _natpmp ) tr_natpmpClose( _natpmp );
	_natpmp = NULL;
#endif

	_connectionThread = nil;
	_delegate = nil;

	[super dealloc];
}

#pragma mark -

- (void) connectToHost:(NSString *) host onPort:(unsigned short) port {
	if( _acceptConnection || _connection ) return;

	[self _setupThread];

	if( ! _connectionThread ) return;

	NSDictionary *info = [[NSDictionary allocWithZone:NULL] initWithObjectsAndKeys:[NSNumber numberWithUnsignedShort:port], @"port", host, @"host", nil];
	[self performSelector:@selector( _connect: ) withObject:info inThread:_connectionThread];
	[info release];
}

- (void) acceptConnectionOnFirstPortInRange:(NSRange) ports {
	if( _acceptConnection || _connection ) return;

	[self _setupThread];

	if( ! _connectionThread ) return;

	[self performSelector:@selector( _acceptConnectionOnFirstPortInRange: ) withObject:[NSValue valueWithRange:ports] inThread:_connectionThread];
}

- (void) disconnect {
	if( ! _connectionThread ) return;

	[self performSelector:@selector( _finish ) inThread:_connectionThread];
}

- (void) disconnectAfterWriting {
	if( ! _connectionThread ) return;

	[_connection performSelector:@selector( disconnectAfterWriting ) inThread:_connectionThread];
	[_acceptConnection performSelector:@selector( disconnect ) inThread:_connectionThread];
}

#pragma mark -

- (NSThread *) connectionThread {
	return _connectionThread;
}

#pragma mark -

- (void) readDataToLength:(CFIndex) length withTimeout:(NSTimeInterval) timeout withTag:(long) tag {
	MVAssertCorrectThreadRequired( _connectionThread );
	[_connection readDataToLength:length withTimeout:timeout tag:tag];
}

- (void) readDataToData:(NSData *) data withTimeout:(NSTimeInterval) timeout withTag:(long) tag {
	MVAssertCorrectThreadRequired( _connectionThread );
	[_connection readDataToData:data withTimeout:timeout tag:tag];
}

- (void) readDataWithTimeout:(NSTimeInterval) timeout withTag:(long) tag {
	MVAssertCorrectThreadRequired( _connectionThread );
	[_connection readDataWithTimeout:timeout tag:tag];
}

- (void) writeData:(NSData *) data withTimeout:(NSTimeInterval) timeout withTag:(long) tag {
	MVAssertCorrectThreadRequired( _connectionThread );
	[_connection writeData:data withTimeout:timeout tag:tag];
}

#pragma mark -

- (void) setDelegate:(id) delegate {
	_delegate = delegate;
}

- (id) delegate {
	return _delegate;
}

#pragma mark -

- (void) socket:(AsyncSocket *) sock didAcceptNewSocket:(AsyncSocket *) newSocket {
	MVAssertCorrectThreadRequired( _connectionThread );

	if( ! _connection ) _connection = [newSocket retain];
	else [newSocket disconnect];

	id old = _acceptConnection;
	_acceptConnection = nil;
	[old setDelegate:nil];
	[old disconnect];
	[old release];
}

- (void) socket:(AsyncSocket *) sock didConnectToHost:(NSString *) host port:(UInt16) port {
	MVAssertCorrectThreadRequired( _connectionThread );
	if( [_delegate respondsToSelector:@selector( directClientConnection:didConnectToHost:port: )] )
		[_delegate directClientConnection:self didConnectToHost:host port:port];
}

- (void) socket:(AsyncSocket *) sock willDisconnectWithError:(NSError *) error {
	MVAssertCorrectThreadRequired( _connectionThread );
	if( [_delegate respondsToSelector:@selector( directClientConnection:willDisconnectWithError: )] )
		[_delegate directClientConnection:self willDisconnectWithError:error];
}

- (void) socketDidDisconnect:(AsyncSocket *) sock {
	MVAssertCorrectThreadRequired( _connectionThread );
	if( [_delegate respondsToSelector:@selector( directClientConnectionDidDisconnect: )] )
		[_delegate directClientConnectionDidDisconnect:self];
	_done = YES;
}

- (void) socket:(AsyncSocket *) sock didWriteDataWithTag:(long) tag {
	MVAssertCorrectThreadRequired( _connectionThread );
	if( [_delegate respondsToSelector:@selector( directClientConnection:didWriteDataWithTag: )] )
		[_delegate directClientConnection:self didWriteDataWithTag:tag];
}

- (void) socket:(AsyncSocket *) sock didReadData:(NSData *) data withTag:(long) tag {
	MVAssertCorrectThreadRequired( _connectionThread );
	if( [_delegate respondsToSelector:@selector( directClientConnection:didReadData:withTag: )] )
		[_delegate directClientConnection:self didReadData:data withTag:tag];
}
@end

#pragma mark -

@implementation MVDirectClientConnection (MVDirectClientConnectionPrivate)
- (void) _setupThread {
	if( _connectionThread ) return;

	_threadWaitLock = [[NSConditionLock allocWithZone:nil] initWithCondition:0];

	[NSThread detachNewThreadSelector:@selector( _dccRunloop ) toTarget:self withObject:nil];

	[_threadWaitLock lockWhenCondition:1];
	[_threadWaitLock unlockWithCondition:0];
	[_threadWaitLock release];
	_threadWaitLock = nil;
}

- (void) _connect:(NSDictionary *) info {
	MVAssertCorrectThreadRequired( _connectionThread );

	if( _acceptConnection || _connection ) return;

	_connection = [[AsyncSocket allocWithZone:nil] initWithDelegate:self];

	NSString *host = [info objectForKey:@"host"];
	NSNumber *port = [info objectForKey:@"port"];

	if( ! [_connection connectToHost:host onPort:[port unsignedShortValue] error:NULL] ) {
		NSLog(@"can't connect to DCC %@ on port %d", host, [port unsignedShortValue] );
		return;
	}
}

- (void) _acceptConnectionOnFirstPortInRange:(NSValue *) portsObject {
	MVAssertCorrectThreadRequired( _connectionThread );

	if( _acceptConnection || _connection ) return;

	_acceptConnection = [[AsyncSocket allocWithZone:nil] initWithDelegate:self];

	NSRange ports = [portsObject rangeValue];
	unsigned int port = ports.location;
	BOOL success = NO;

	while( ! success ) {
		if( [_acceptConnection acceptOnPort:port error:NULL] ) {
			port = [_acceptConnection localPort];
			success = YES;
			break;
		} else {
			[_acceptConnection disconnect];
			if( port == 0 ) break;
			if( ++port > NSMaxRange( ports ) )
				port = 0; // just use a random port since the user defined range is in use
		}
	}

#if ENABLE(AUTO_PORT_MAPPING)
	if( success && [MVFileTransfer isAutoPortMappingEnabled] ) {
		tr_msgInit();
		tr_fdInit();

		_upnp = tr_upnpInit();
		tr_upnpStart( _upnp );
		tr_upnpForwardPort( _upnp, port );

		_natpmp = tr_natpmpInit();
		tr_natpmpStart( _natpmp );
		tr_natpmpForwardPort( _natpmp, port );

		NSDate *mappingStart = [NSDate date];
		int status = 0;

		do {
			tr_upnpPulse( _upnp );
			tr_natpmpPulse( _natpmp );
			status = natTraversalStatus( _upnp, _natpmp );
		} while( ( status == 1 || status == 3 ) && ABS( [mappingStart timeIntervalSinceNow] ) < 5. ); 
	}
#endif

	if( success && [_delegate respondsToSelector:@selector( directClientConnection:acceptingConnectionsToHost:port: )] )
		[_delegate directClientConnection:self acceptingConnectionsToHost:[_acceptConnection localHost] port:port];
}

- (void) _finish {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector( _finish ) object:nil];	

#if ENABLE(AUTO_PORT_MAPPING)
	if( _upnp ) tr_upnpClose( _upnp );
	_upnp = NULL;

	if( _natpmp ) tr_natpmpClose( _natpmp );
	_natpmp = NULL;
#endif

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
	if( [_connectionThread respondsToSelector:@selector( setName: )] )
		[_connectionThread setName:[self description]];
	[NSThread prepareForInterThreadMessages];
	[NSThread setThreadPriority:0.75];

	[_threadWaitLock unlockWithCondition:1];

	if( [pool respondsToSelector:@selector( drain )] )
		[pool drain];
	else [pool release];
	pool = nil;

	while( ! _done ) {
#if ENABLE(AUTO_PORT_MAPPING)
		if( _upnp ) tr_upnpPulse( _upnp );
		if( _natpmp ) tr_natpmpPulse( _natpmp );
#endif

		pool = [[NSAutoreleasePool allocWithZone:nil] init];

		NSDate *timeout = [[NSDate allocWithZone:nil] initWithTimeIntervalSinceNow:5.];
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:timeout];
		[timeout release];

		if( [pool respondsToSelector:@selector( drain )] )
			[pool drain];
		else [pool release];
	}

	pool = [[NSAutoreleasePool allocWithZone:nil] init];

	// make sure the connection has sent all the delegate calls it has scheduled
	[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.]];

	if( [NSThread currentThread] == _connectionThread )
		_connectionThread = nil;

	[self _finish];
	[self release];

	if( [pool respondsToSelector:@selector( drain )] )
		[pool drain];
	else [pool release];
}
@end
