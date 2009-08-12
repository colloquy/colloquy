@class AsyncSocket;
@class TCMPortMapping;

NSString *MVDCCFriendlyAddress( NSString *address );

@interface MVDirectClientConnection : NSObject {
@private
	id _delegate;
	AsyncSocket *_connection;
	AsyncSocket *_acceptConnection;
	TCMPortMapping *_portMapping;
	NSThread *_connectionThread;
	NSConditionLock *_threadWaitLock;
	unsigned short _port;
	BOOL _done;
}
- (void) connectToHost:(NSString *) host onPort:(unsigned short) port;
- (void) acceptConnectionOnFirstPortInRange:(NSRange) ports;
- (void) disconnect;
- (void) disconnectAfterWriting;

- (NSThread *) connectionThread;

- (void) readDataToLength:(size_t) length withTimeout:(NSTimeInterval) timeout withTag:(long) tag;
- (void) readDataToData:(NSData *) data withTimeout:(NSTimeInterval) timeout withTag:(long) tag;
- (void) readDataWithTimeout:(NSTimeInterval) timeout withTag:(long) tag;

- (void) writeData:(NSData *) data withTimeout:(NSTimeInterval) timeout withTag:(long) tag;

- (void) setDelegate:(id) delegate;
- (id) delegate;
@end

@interface NSObject (MVDirectClientConnectionDelegate)
- (void) directClientConnection:(MVDirectClientConnection *) connection didConnectToHost:(NSString *) host port:(unsigned short) port;
- (void) directClientConnection:(MVDirectClientConnection *) connection acceptingConnectionsToHost:(NSString *) host port:(unsigned short) port;
- (void) directClientConnection:(MVDirectClientConnection *) connection willDisconnectWithError:(NSError *) error;
- (void) directClientConnectionDidDisconnect:(MVDirectClientConnection *) connection;
- (void) directClientConnection:(MVDirectClientConnection *) connection didWriteDataWithTag:(long) tag;
- (void) directClientConnection:(MVDirectClientConnection *) connection didReadData:(NSData *) data withTag:(long) tag;
@end
