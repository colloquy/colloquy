#import "MVDirectClientConnection.h"

#import "GCDAsyncSocket.h"
#import "InterThreadMessaging.h"
#import "MVChatConnectionPrivate.h"
#import "MVFileTransfer.h"
#import "MVUtilities.h"
#import "NSNotificationAdditions.h"

#undef ENABLE_AUTO_PORT_MAPPING
#if ENABLE(AUTO_PORT_MAPPING)
#import <TCMPortMapper/TCMPortMapper.h>
#endif

#import <arpa/inet.h>

NS_ASSUME_NONNULL_BEGIN

NSString *MVDCCFriendlyAddress( NSString *address ) {
	NSURL *url = [NSURL URLWithString:@"http://colloquy.info/ip.php"];
	NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:3.];
	NSData *result = [NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:NULL];
	if( result.length >= 6 && result.length <= 40 ) // should be a valid IPv4 or IPv6 address
		address = [[NSString alloc] initWithData:result encoding:NSASCIIStringEncoding];
	if( address && [address rangeOfString:@"."].location != NSNotFound )
		return [NSString stringWithFormat:@"%d", ntohl( inet_addr( [address UTF8String] ) )];
	return address;
}

#pragma mark -

@interface MVDirectClientConnection (MVDirectClientConnectionPrivate)
- (void) _setupThread;
- (void) _connect:(NSDictionary *) info;
- (void) _acceptConnectionOnFirstPortInRange:(NSValue *) portsObject;
- (void) _sendDelegateAcceptingConnections;
- (void) _portMappingStatusChanged:(NSNotification *) notification;
- (void) _finish;
- (oneway void) _dccRunloop;
@end

#pragma mark -

@implementation MVDirectClientConnection
- (void) dealloc {
	[[NSNotificationCenter chatCenter] removeObserver:self];

	_done = YES;

	[_acceptConnection disconnect];
	[_acceptConnection setDelegate:nil];

	[_connection disconnect];
	[_connection setDelegate:nil];


#if ENABLE(AUTO_PORT_MAPPING)
	if (_portMapping) {
		[[TCMPortMapper sharedInstance] removePortMapping:_portMapping];
		if (![[[TCMPortMapper sharedInstance] portMappings] count])
			[[TCMPortMapper sharedInstance] stop];
	}

#endif
}

#pragma mark -

- (void) connectToHost:(NSString *) host onPort:(unsigned short) port {
	if( _acceptConnection || _connection ) return;

	[self _setupThread];

	if( ! _connectionThread ) return;

	NSDictionary *info = @{ @"port": @(port), @"host": host };
	[self performSelector:@selector( _connect: ) withObject:info inThread:_connectionThread];
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

- (void) readDataToLength:(size_t) length withTimeout:(NSTimeInterval) timeout withTag:(long) tag {
	[_connection readDataToLength:length withTimeout:timeout tag:tag];
}

- (void) readDataToData:(NSData *) data withTimeout:(NSTimeInterval) timeout withTag:(long) tag {
	[_connection readDataToData:data withTimeout:timeout tag:tag];
}

- (void) readDataWithTimeout:(NSTimeInterval) timeout withTag:(long) tag {
	[_connection readDataWithTimeout:timeout tag:tag];
}

- (void) writeData:(NSData *) data withTimeout:(NSTimeInterval) timeout withTag:(long) tag {
	[_connection writeData:data withTimeout:timeout tag:tag];
}

#pragma mark -

- (void) setDelegate:(id __nullable) delegate {
	_delegate = delegate;
}

- (id) delegate {
	return _delegate;
}

#pragma mark -

- (void) socket:(GCDAsyncSocket *) sock didAcceptNewSocket:(GCDAsyncSocket *) newSocket {
	if( ! _connection ) _connection = newSocket;
	else [newSocket disconnect];

	[_acceptConnection setDelegate:nil];
	[_acceptConnection disconnect];
	_acceptConnection = nil;
}

- (void) socket:(GCDAsyncSocket *) sock didConnectToHost:(NSString *) host port:(UInt16) port {
	SEL selector = @selector( directClientConnection:didConnectToHost:port: );
	if( [_delegate respondsToSelector:selector] ) {
		[self performSelector:@selector(_delegateMethodDidConnectToHostAndPort:) onThread:_connectionThread withObject:@{@"host": host, @"port": @(port)} waitUntilDone:YES];
	}
}

- (void) _delegateMethodDidConnectToHostAndPort:(NSDictionary*)dictionary {
	[_delegate directClientConnection:self didConnectToHost:dictionary[@"host"] port:[dictionary[@"port"] unsignedShortValue]];
}

- (void) socket:(GCDAsyncSocket *) sock willDisconnectWithError:(NSError *) error {
	SEL selector = @selector( directClientConnection:willDisconnectWithError: );
	if( [_delegate respondsToSelector:selector] ) {
		[self performSelector:@selector(_delegateMethodWillDisconnectWithError:) onThread:_connectionThread withObject:error waitUntilDone:YES];
	}
}

- (void) _delegateMethodWillDisconnectWithError:(NSError *)error {
	[_delegate directClientConnection:self willDisconnectWithError:error];
}

- (void) socketDidDisconnect:(GCDAsyncSocket *) sock {
	SEL selector = @selector( directClientConnectionDidDisconnect: );
	if( [_delegate respondsToSelector:selector] ) {
		[_delegate performSelector:selector onThread:_connectionThread withObject:self waitUntilDone:YES];
	}
	_done = YES;
}

- (void) socket:(GCDAsyncSocket *) sock didWriteDataWithTag:(long) tag {
	SEL selector = @selector( directClientConnection:didWriteDataWithTag: );
	if( [_delegate respondsToSelector:selector] ) {
		[self performSelector:@selector(_delegateMethodDidWriteDataWithTag:) onThread:_connectionThread withObject:@(tag) waitUntilDone:YES];
	}
}

- (void) _delegateMethodDidWriteDataWithTag:(NSNumber *)tag {
	[_delegate directClientConnection:self didWriteDataWithTag:[tag longValue]];
}

- (void) socket:(GCDAsyncSocket *) sock didReadData:(NSData *) data withTag:(long) tag {
	SEL selector = @selector( directClientConnection:didReadData:withTag: );
	if( [_delegate respondsToSelector:selector] ) {
		[self performSelector:@selector(_delegateMethodDidReadDataWithTag:) onThread:_connectionThread withObject:@{@"data": data, @"tag": @(tag)} waitUntilDone:YES];
	}
}

- (void) _delegateMethodDidReadDataWithTag:(NSDictionary*)dictionary {
	[_delegate directClientConnection:self didReadData:dictionary[@"data"] withTag:[dictionary[@"tag"] longValue]];
}

@end

#pragma mark -

@implementation MVDirectClientConnection (MVDirectClientConnectionPrivate)
- (void) _setupThread {
	if( _connectionThread ) return;

	_threadWaitLock = [[NSConditionLock alloc] initWithCondition:0];

	[NSThread detachNewThreadSelector:@selector( _dccRunloop ) toTarget:self withObject:nil];

	[_threadWaitLock lockWhenCondition:1];
	[_threadWaitLock unlockWithCondition:0];
	_threadWaitLock = nil;
}

- (void) _connect:(NSDictionary *) info {
	if( _acceptConnection || _connection ) return;

	_connection = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_connectionDelegateQueue socketQueue:_connectionDelegateQueue];

	NSString *host = info[@"host"];
	NSNumber *port = info[@"port"];

	if( ! [_connection connectToHost:host onPort:[port unsignedShortValue] error:NULL] ) {
		NSLog(@"can't connect to DCC %@ on port %d", host, [port unsignedShortValue] );
		return;
	}
}

- (void) _acceptConnectionOnFirstPortInRange:(NSValue *) portsObject {
	if( _acceptConnection || _connection ) return;

	_acceptConnection = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_connectionDelegateQueue socketQueue:_connectionDelegateQueue];

	NSRange ports = [portsObject rangeValue];
	unsigned short port = ports.location;
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

	if( success )
		_port = port;
	else _port = 0;

#if ENABLE(AUTO_PORT_MAPPING)
	if( success && [MVFileTransfer isAutoPortMappingEnabled] ) {
		if (_portMapping) {
			[[TCMPortMapper sharedInstance] removePortMapping:_portMapping];
			if (![[[TCMPortMapper sharedInstance] portMappings] count])
				[[TCMPortMapper sharedInstance] stop];

			[[NSNotificationCenter chatCenter] removeObserver:self name:TCMPortMappingDidChangeMappingStatusNotification object:_portMapping];

			_portMapping = nil;
		}

		_portMapping = [[TCMPortMapping alloc] initWithLocalPort:port desiredExternalPort:port transportProtocol:TCMPortMappingTransportProtocolTCP userInfo:nil];

		[[NSNotificationCenter chatCenter] addObserver:self selector:@selector(_portMappingStatusChanged:) name:TCMPortMappingDidChangeMappingStatusNotification object:_portMapping];

		[[TCMPortMapper sharedInstance] addPortMapping:_portMapping];
		[[TCMPortMapper sharedInstance] start];
	} else
#endif
	if( success )
		[self _sendDelegateAcceptingConnections];
}

- (void) _sendDelegateAcceptingConnections {
	if( [_delegate respondsToSelector:@selector( directClientConnection:acceptingConnectionsToHost:port: )] )
		[_delegate directClientConnection:self acceptingConnectionsToHost:[_acceptConnection localHost] port:_port];
}

- (void) _portMappingStatusChanged:(NSNotification *) notification {
	[self _sendDelegateAcceptingConnections];
}

- (void) _finish {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector( _finish ) object:nil];

#if ENABLE(AUTO_PORT_MAPPING)
	if (_portMapping) {
		[[TCMPortMapper sharedInstance] removePortMapping:_portMapping];
		if (![[[TCMPortMapper sharedInstance] portMappings] count])
			[[TCMPortMapper sharedInstance] stop];

		[[NSNotificationCenter chatCenter] removeObserver:self name:TCMPortMappingDidChangeMappingStatusNotification object:_portMapping];

		_portMapping = nil;
	}
#endif

	[_acceptConnection setDelegate:nil];
	[_acceptConnection disconnect];
	_acceptConnection = nil;

	[_connection setDelegate:nil];
	[_connection disconnect];
	_connection = nil;

	_done = YES;
}

- (oneway void) _dccRunloop {
	@autoreleasepool {
		[_threadWaitLock lockWhenCondition:0];

		NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
		NSString *queueName = [NSString stringWithFormat:@"%@.connection-queue (%@)", bundleIdentifier, [self description]];
		_connectionDelegateQueue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_SERIAL);
		_connectionThread = [NSThread currentThread];
		[_connectionThread setName:[self description]];
		[NSThread prepareForInterThreadMessages];
		[NSThread setThreadPriority:0.75];

		[_threadWaitLock unlockWithCondition:1];
	}

	while( ! _done ) {
		@autoreleasepool {
			NSDate *timeout = [[NSDate alloc] initWithTimeIntervalSinceNow:5.];
			[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:timeout];
		}
	}

	@autoreleasepool {
		// make sure the connection has sent all the delegate calls it has scheduled
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.]];

		if( [NSThread currentThread] == _connectionThread )
			_connectionThread = nil;

		[self _finish];
	}
}
@end

NS_ASSUME_NONNULL_END
