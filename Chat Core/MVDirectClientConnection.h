#import <ChatCore/MVAvailability.h>

NS_ASSUME_NONNULL_BEGIN

@class GCDAsyncSocket;
@class MVDirectClientConnection;
@class TCMPortMapping;

@protocol MVDirectClientConnectionDelegate <NSObject>
@optional
- (void) directClientConnection:(MVDirectClientConnection *) connection didConnectToHost:(NSString *) host port:(unsigned short) port;
- (void) directClientConnection:(MVDirectClientConnection *) connection acceptingConnectionsToHost:(NSString *) host port:(unsigned short) port;
- (void) directClientConnection:(MVDirectClientConnection *) connection willDisconnectWithError:(NSError *) error;
- (void) directClientConnectionDidDisconnect:(MVDirectClientConnection *) connection;
- (void) directClientConnection:(MVDirectClientConnection *) connection didWriteDataWithTag:(long) tag;
- (void) directClientConnection:(MVDirectClientConnection *) connection didReadData:(NSData *) data withTag:(long) tag;
@end

NSString *MVDCCFriendlyAddress( NSString *address );

@interface MVDirectClientConnection : NSObject {
@private
	NSObject <MVDirectClientConnectionDelegate> *_delegate;
	GCDAsyncSocket *_connection;
	GCDAsyncSocket *_acceptConnection;
#if ENABLE(AUTO_PORT_MAPPING)
	TCMPortMapping *_portMapping;
#endif
	NSThread *_connectionThread;
	dispatch_queue_t _connectionDelegateQueue;
	NSConditionLock *_threadWaitLock;
	unsigned short _port;
	BOOL _done;
}
- (void) connectToHost:(NSString *) host onPort:(unsigned short) port;
- (void) acceptConnectionOnFirstPortInRange:(NSRange) ports;
- (void) disconnect;
- (void) disconnectAfterWriting;

@property (readonly, strong) NSThread *connectionThread;

- (void) readDataToLength:(size_t) length withTimeout:(NSTimeInterval) timeout withTag:(long) tag;
- (void) readDataToData:(NSData *) data withTimeout:(NSTimeInterval) timeout withTag:(long) tag;
- (void) readDataWithTimeout:(NSTimeInterval) timeout withTag:(long) tag;

- (void) writeData:(NSData *) data withTimeout:(NSTimeInterval) timeout withTag:(long) tag;

@property (weak, null_resettable) id <MVDirectClientConnectionDelegate> delegate;
@end

NS_ASSUME_NONNULL_END
