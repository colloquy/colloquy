//============================================================================
// 
//     License:
// 
//     This library is free software; you can redistribute it and/or
//     modify it under the terms of the GNU Lesser General Public
//     License as published by the Free Software Foundation; either
//     version 2.1 of the License, or (at your option) any later version.
// 
//     This library is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//     Lesser General Public License for more details.
// 
//     You should have received a copy of the GNU Lesser General Public
//     License along with this library; if not, write to the Free Software
//     Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  
//     USA
// 
//     Copyright (C) 2002-2003 Dave Smith (dizzyd@jabber.org)
// 
// $Id: DizSocket.m,v 1.5 2004/12/31 20:55:12 alangh Exp $
//============================================================================

#import "DizSocket.h"
#import <sys/types.h>
#import <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include "NetworkController.h"

#import <openssl/err.h>

#define SSTATE_CONNECTED   0
#define SSTATE_HANDSHAKING 1

void socketCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void* data, void* info);

@interface WriteListItem : NSObject
{
    @public
    NSData* data;
    const void* cur_data;
    int   cur_length;
}
@end
@implementation WriteListItem
@end

@implementation DizSocket

-(void) startWriting
{
    int rc;
    size_t buf_cnt;

    // If system is no longer connected, ignore
    if (_connected == NO)
        return;
    
    while ([_write_list count])
    {
        WriteListItem* item = [_write_list objectAtIndex:0];
        buf_cnt = item->cur_length;
        if (_ssl_conn)
        {
            rc = SSL_write(_ssl_conn, item->cur_data, buf_cnt);
            if (rc < 1)
            {
                int sslrc = SSL_get_error(_ssl_conn, rc);
                if ((sslrc != SSL_ERROR_WANT_READ) && (sslrc != SSL_ERROR_WANT_WRITE))
                    NSLog(@"Error occurred on write: %d", sslrc);
                else if (sslrc == SSL_ERROR_WANT_WRITE)
                    CFSocketEnableCallBacks(_socket, kCFSocketWriteCallBack);
                return;
            }
        }
        else
        {
            int fd = CFSocketGetNative(_socket);
            rc = send(fd, item->cur_data, buf_cnt, 0);
            if (rc < 1)
            {
                NSLog(@"Socket write error(%d): %s", errno, strerror(errno));
                return;
            }
        }
        if (rc == buf_cnt)
        {
            [_delegate onSocketWroteData:item->data];
            [item->data release];
            [_write_list removeObjectAtIndex:0];
        }
        else
        {
            item->cur_data = (void*)((int)item->cur_data + buf_cnt);
            CFSocketEnableCallBacks(_socket, kCFSocketWriteCallBack);
            return;
        }
    }
}

-(void) startReading
{
    int rc;
    char buf[4096];
    NSData* data;

    // If system is no longer connected, ignore
    if (_connected == NO)
        return;
    
    
    if (_ssl_conn)
    {
        rc = SSL_read(_ssl_conn, buf, sizeof(buf));
        if (rc < 0)
        {
            int sslrc = SSL_get_error(_ssl_conn, rc);
            if ((sslrc != SSL_ERROR_WANT_READ) && (sslrc != SSL_ERROR_WANT_WRITE))
                NSLog(@"Error occurred on read: %d, %d", rc, sslrc);
            else if (sslrc == SSL_ERROR_WANT_WRITE)
                CFSocketEnableCallBacks(_socket, kCFSocketWriteCallBack);
            return;
        }
    }
    else
    {
        int fd = CFSocketGetNative(_socket);
        rc = recv(fd, buf, sizeof(buf), 0);
        if (rc < 0)
        {
            if (errno != EAGAIN)
                NSLog(@"Socket read error(%d): %s", errno, strerror(errno));
            return;
        }
    }

    if (rc > 0)
    {
        data = [NSData dataWithBytes:buf length:rc];
        [_delegate onSocketReadData:data];
    }
    else if (rc == 0)
    {
        NSLog(@"Socket read error; closing.");
        [self disconnect];
    }
}

-(void) onSocketCallbackType:(CFSocketCallBackType)type withAddress:(CFDataRef)address
                    withData:(const void*)data
{   
    // If still handshaking..continue
    if (_ssl_state == SSTATE_HANDSHAKING)
    {
        // Handshake
        int rc = SSL_connect(_ssl_conn);

        if (rc == 1)
        {
            _ssl_state = SSTATE_CONNECTED;
            [_delegate onSocketSSLConnected];
        }
        else
        {
            int sslrc = SSL_get_error(_ssl_conn, rc);
            if ((sslrc != SSL_ERROR_WANT_READ) && (sslrc != SSL_ERROR_WANT_WRITE))
            {
                NSLog(@"SSL Handshake part 2: error(%d, %d): %s", rc, sslrc,
                      ERR_error_string(sslrc, NULL));
                CFSocketInvalidate(_socket);
                _connected = NO;
                _ssl_context = nil;
                [_delegate onSocketConnectFailed:rc];
                return;
            }
            else if (sslrc == SSL_ERROR_WANT_WRITE)
                CFSocketEnableCallBacks(_socket, kCFSocketWriteCallBack);
        }
    }

    switch (type)
    {
        case kCFSocketReadCallBack:
            [self startReading];
            break;
        case kCFSocketWriteCallBack:
            [self startWriting];
            break;
        default:
            ;
    }
}

void socketCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address,
                    const void* data, void* info)
{
    DizSocket* sock = (DizSocket*)info;
    [sock onSocketCallbackType:type withAddress:address withData:data];
}

-(id) init
{
    [super init];

    _write_list = [[NSMutableArray alloc] initWithCapacity:5];

    _socket = NULL;

    return self;
}

+(void) initialize
{
    SSL_library_init();
    SSL_load_error_strings();
}

-(id) initWithDelegate:(id)delegate
{
    [self init];
    _delegate = delegate;
    return self;
}

-(BOOL) isConnected
{
    return _connected;
}

-(void) dealloc
{
    if (_socket != NULL) {
        if (CFSocketIsValid(_socket))
            CFSocketInvalidate(_socket);
        CFRelease(_socket);
    }
    [_write_list release];
    [super dealloc];
}

-(void) connected:(HostConnectListener *)listener type:(NSNumber *)type
{
    CFSocketContext ctx;
    memset(&ctx, '\0', sizeof(CFSocketContext));
    ctx.info = self;
    
    if([type intValue] == kCFStreamEventOpenCompleted)
    {
        _socket = CFSocketCreateWithNative(kCFAllocatorDefault, [listener fd], kCFSocketReadCallBack, socketCallback, &ctx);
        CFRunLoopSourceRef rls = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopCommonModes);
        
        _connected = YES;
        [_delegate onSocketConnected];
            // Check to see if we're no longer connected, due to some error
            // occurring in the delegate
        if (_connected == NO)
            return;
        if ([_write_list count] > 0)
            [self startWriting];
    }
    else
    {
        int ec = [listener getError].error;
        [_delegate onSocketConnectFailed:ec];
    }
    [listener release];
}

-(void) connectToHost:(NSString*)hostname onPort:(int)port
{
    [[[NetworkController sharedInstance] connectToHost:hostname port:port withPrivateData:NULL callbackObject:self selector:@selector(connected:type:)] retain];
}

-(void) disconnect
{
    if (_connected == YES)
    {
        CFSocketInvalidate(_socket);

        if (_ssl_context)
        {
            SSL_shutdown(_ssl_conn);
            SSL_free(_ssl_conn);
            SSL_CTX_free(_ssl_context);
            _ssl_context = nil;
            _ssl_conn = nil;
        }

        _connected = NO;

        [_delegate onSocketDisconnected];
    }
}

-(void) startSSL
{
    int rc;
    
    assert(_connected == YES);
    assert(_ssl_context == nil);
    assert(_ssl_conn == nil);

    // Setup for SSL
    _ssl_context = SSL_CTX_new(SSLv23_method());

    // XXX: Someday, verify certs
    SSL_CTX_set_verify(_ssl_context, SSL_VERIFY_NONE, nil);
    
    _ssl_conn = SSL_new(_ssl_context);
    SSL_set_connect_state(_ssl_conn);
    SSL_set_fd(_ssl_conn, CFSocketGetNative(_socket));
    

    // Start the SSL connection
    rc = SSL_connect(_ssl_conn);

    if (rc == 1)
    {
            // Generate SSL Connect event
            [_delegate onSocketSSLConnected];
    }
    else
    {
        int sslrc = SSL_get_error(_ssl_conn, rc);
        if ((sslrc != SSL_ERROR_WANT_READ) && (sslrc != SSL_ERROR_WANT_WRITE))
        {
            NSLog(@"SSL Handshake error(%d, %d): %s", rc, sslrc, ERR_error_string(sslrc, NULL));
            CFSocketInvalidate(_socket);
            _connected = NO;
            _ssl_context = nil;            
            [_delegate onSocketConnectFailed:rc];
        }
        else
        {
            _ssl_state = SSTATE_HANDSHAKING;
            if (sslrc == SSL_ERROR_WANT_WRITE)
                CFSocketEnableCallBacks(_socket, kCFSocketWriteCallBack);
        }
    }            
            
}

-(id) delegate
{
    return _delegate;
}

-(void) setDelegate:(id)delegate
{
    _delegate = delegate;
}

-(void) writeData:(NSData*)data
{
    WriteListItem* item = [[WriteListItem new] autorelease];
    item->data = [data retain];
    item->cur_data = [data bytes];
    item->cur_length = [data length];
    [_write_list addObject:item];
    [self startWriting];
}

@end
