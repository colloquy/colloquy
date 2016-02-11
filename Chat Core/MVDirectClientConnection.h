#import <Foundation/Foundation.h>

#import <ChatCore/MVAvailability.h>


NS_ASSUME_NONNULL_BEGIN

@class MVDirectClientConnection;

@protocol MVDirectClientConnectionDelegate <NSObject>
@optional
- (void) directClientConnection:(MVDirectClientConnection *) connection didConnectToHost:(NSString *) host port:(unsigned short) port;
- (void) directClientConnection:(MVDirectClientConnection *) connection acceptingConnectionsToHost:(NSString *) host port:(unsigned short) port;
- (void) directClientConnection:(MVDirectClientConnection *) connection willDisconnectWithError:(NSError *) error;
- (void) directClientConnectionDidDisconnect:(MVDirectClientConnection *) connection;
- (void) directClientConnection:(MVDirectClientConnection *) connection didWriteDataWithTag:(long) tag;
- (void) directClientConnection:(MVDirectClientConnection *) connection didReadData:(NSData *) data withTag:(long) tag;
@end

typedef void (^MVStringParameterBlock)(NSString *);
void MVFindDCCFriendlyAddress( NSString *address, MVStringParameterBlock completion );

@interface MVDirectClientConnection : NSObject
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
