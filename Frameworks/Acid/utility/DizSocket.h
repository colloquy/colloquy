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
//     Copyright (C) 2002 Dave Smith (dizzyd@jabber.org)
// 
// $Id: DizSocket.h,v 1.1 2004/07/19 03:49:04 jtownsend Exp $
//============================================================================

#import <Foundation/Foundation.h>
#import <openssl/ssl.h>


@protocol DizSocketDelegate
-(void) onSocketConnected;
-(void) onSocketSSLConnected;
-(void) onSocketConnectFailed:(int)errorcode;
-(void) onSocketReadData:(NSData*)d;
-(void) onSocketWroteData:(NSData*)d;
-(void) onSocketDisconnected;
@end

@interface DizSocket : NSObject {
    CFSocketRef    _socket;
    int            _ssl_state;
    SSL_CTX*       _ssl_context;
    SSL*           _ssl_conn;
    BOOL           _connected;
    id             _delegate;
    NSMutableArray* _write_list;
}

-(id) init;
-(id) initWithDelegate:(id)delegate;

-(void) dealloc;

-(void) connectToHost:(NSString*)hostname onPort:(int)port;
-(void) disconnect;

-(BOOL) isConnected;

-(void) startSSL;

-(id)   delegate;
-(void) setDelegate:(id)delegate;

-(void) writeData:(NSData*)data;

@end
