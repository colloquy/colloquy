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
// $Id: JabberSocket.m,v 1.1 2004/07/19 03:49:03 jtownsend Exp $
//============================================================================

#import "acid.h"
#import "GCDAsyncSocket.h"

@interface JabberSocket ()
-(void) onKeepAliveTick:(NSTimer*)t;
@end

@implementation JabberSocket
{
    dispatch_queue_t  _connectionDelegateQueue;
    GCDAsyncSocket*   _socket;
    XMLElementStream* _parser;
    JabberSession*    _session;
    NSTimer*          _timer;
}
@synthesize useSSL = _useSSL;

-(instancetype) initWithJabberSession:(JabberSession*)session
{
    if (!(self = [super init]))
		return nil;

	_connectionDelegateQueue = dispatch_queue_create([[self description] UTF8String], 0);
    _socket = [[NSClassFromString(@"GCDAsyncSocket") alloc] initWithDelegate:self delegateQueue:_connectionDelegateQueue];
    _session = session;    

    return self;
}

-(void) dealloc
{
    [_timer invalidate];
    _session = nil;
	dispatch_release(_connectionDelegateQueue);
}

-(void) onKeepAliveTick:(NSTimer*)t
{
    if ([_socket isConnected])
    {
        [self sendString:@" "]; 
    }
    else
    {
        [_timer invalidate];
        _timer = nil;
    }
}

-(void) connectToHost:(NSString*)host onPort:(unsigned short)port
{
    assert(![_socket isConnected]);

    [_socket connectToHost:host onPort:port error:NULL];
}

-(void) disconnect
{
    [_socket disconnect];
}

-(void) onDocumentStart:(XMLElement*)element
{
    [_session postNotificationName:JSESSION_ROOT_PACKET object:element];

    // Setup keep alive
    _timer =  [NSTimer scheduledTimerWithTimeInterval: 60
                                               target: self
                                             selector: @selector(onKeepAliveTick:)
                                             userInfo: nil
                                              repeats: YES];
    
}

-(void) onElement:(XMLElement*)element
{
    [_session postNotificationName:JSESSION_PACKET_IN object:element];
    [_session postNotificationForElement:element];
}

-(void) onCData:(XMLCData*)cdata
{}

-(void) onDocumentEnd
{}

- (void) socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
	if (_useSSL) {
        NSDictionary *settings = @{(NSString *)kCFStreamSSLAllowsAnyRoot: @YES,
                                   (id)kCFStreamPropertySocketSecurityLevel: (id)kCFStreamSocketSecurityLevelNegotiatedSSL};

		[_socket startTLS:settings];
	}

	[_session postNotificationName:JSESSION_CONNECTED object:self];
	_parser = [[XMLElementStream alloc] initWithListener:self];
	[_socket readDataWithTimeout:-1. tag:0];
}

- (void) socket:(GCDAsyncSocket *)sock didReadData:(NSData*)data withTag:(long)tag
{
    [_session postNotificationName:JSESSION_RAWDATA_IN object:data];
    [_parser pushData:[data bytes] ofSize:[data length]];
	[_socket readDataWithTimeout:-1. tag:0];
}

- (void) socketDidDisconnect:(GCDAsyncSocket *)sock
{
    [_timer invalidate];
    _timer = nil;
    [_session postNotificationName:JSESSION_ENDED object:self];
}

- (void) socket:(GCDAsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
    [_session postNotificationName:JSESSION_ERROR_CONNECT_FAILED object:nil];
}

-(void) sendString:(NSString*)data
{
    NSData* d = [data dataUsingEncoding:NSUTF8StringEncoding];
    [_socket writeData:d withTimeout:-1. tag:0];
    [_session postNotificationName:JSESSION_RAWDATA_OUT object:d];
}

-(void) setUseSSL:(BOOL)useSSL
{
    assert(![_socket isConnected]);
    _useSSL = useSSL;
}

@end
