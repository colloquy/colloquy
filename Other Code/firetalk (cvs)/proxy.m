// ======================================================================== //
//	proxy.m                              								    //
// ======================================================================== //
// Copyright (C) 2003 Andrew Wellington                                     //
// Created Fri May 09 2003 8:30pm +1000UTC                                  //
// ==License Agreement===================================================== //
// This program is free software; you can redistribute it and/or modify it  //
// under the terms of the GNU General Public License as published by the    //
// Free Software Foundation; either version 2 of the License, or (at your   //
// option) any later version.                                               //
//                                                                          //
// This program is distributed in the hope that it will be useful, but      //
// WITHOUT ANY WARRANTY; without even the implied warranty of               //
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU        //
// General Public License for more details.                                 //
//                                                                          //
// You should have received a copy of the GNU General Public License along  //
// with this program; if not, write to the Free Software Foundation, Inc.,  //
// 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.                //
// ======================================================================== //
// A proxy implementation for firetalk                                      //
// ======================================================================== //
// Parts of the SOCKS4 implementation were based on the SSH Proxy Command   //
// (connect.c) by Shun-ichi Goto, available under the GPL from:		        //
// http://www.taiyo.co.jp/~gotoh/ssh/connect.html			                //
// ======================================================================== //

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <string.h>
#include <netdb.h>
#include <fnmatch.h>
#include <fcntl.h>

#include "proxy.h"
#include "firetalk.h"

#include <SystemConfiguration/SystemConfiguration.h>
#import <Foundation/Foundation.h>

#define SOCKS4_SUCCESS 90

#define put(ptr,data) (*(unsigned char*)ptr = data)

enum firetalk_proxy firetalk_use_proxy( const char *host, enum firetalk_proxy proxyType ) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSDictionary *proxyDict = nil;
	NSArray *exceptionList = nil;
	NSEnumerator *enumerator = nil;
	NSString *object = nil;

	/* get proxy information */
	proxyDict = (NSDictionary *)SCDynamicStoreCopyProxies( NULL );
	[proxyDict autorelease];
	if( ! proxyDict ) {
		[pool release];
		return FX_NONE;
	}

	/* check if it's an excepted host */
	exceptionList = [proxyDict objectForKey:(NSString *)kSCPropNetProxiesExceptionsList];
	enumerator = [exceptionList objectEnumerator];
	while( object = [enumerator nextObject] ) {
		if( ! fnmatch( [object UTF8String], host, FNM_PERIOD | FNM_PATHNAME ) ) {
			[pool release];
			return FX_NONE;
		}
	}

	/* now check if it's SOCKS */
	if( proxyType == FX_SOCKS && ! [[NSNumber numberWithInt:0] isEqualToNumber:[proxyDict objectForKey:(NSString *)kSCPropNetProxiesSOCKSEnable]] ) {
		[pool release];
		return FX_SOCKS;
	}

	/* or if we should use HTTPS */
	if( proxyType == FX_HTTPS && ! [[NSNumber numberWithInt:0] isEqualToNumber:[proxyDict objectForKey:(NSString *)kSCPropNetProxiesHTTPSEnable]] ) {
		[pool release];
		return FX_HTTPS;
	}

	[pool release];
	return FX_NONE;
}

int firetalk_connect( int s, const struct sockaddr *name, int namelen, enum firetalk_proxy proxyType ) {
	unsigned char buf[256] = "";
	unsigned char *bufptr = buf;
	unsigned char myChar = 0;
	char *buffer = NULL;
	struct sockaddr_in proxy;
	struct sockaddr_in *dest = NULL;
	struct hostent *host = NULL;
	int returnVal = 0;
	int flag = 0;
	int localProxyType = FX_NONE;
	int sockFlags = 0;
	ssize_t size = 0;
	NSAutoreleasePool *pool = nil;
	NSDictionary *proxyDict = nil;

	/* non-INET, revert to system connect() */
	if( name -> sa_family != AF_INET ) return connect( s, name, namelen );

	/* save flags and disable O_NONBLOCKING */
	sockFlags = fcntl( s, F_GETFL, 0 );
	fcntl( s, F_SETFL, sockFlags & ~O_NONBLOCK );

	dest = (struct sockaddr_in *)name;

	/* do reverse DNS lookup on IP */
	host = gethostbyaddr( (char *)&dest->sin_addr, sizeof( dest -> sin_addr ), AF_INET );
	if( ! host ) localProxyType = firetalk_use_proxy( inet_ntoa( dest -> sin_addr ), proxyType );
	else localProxyType = firetalk_use_proxy( host -> h_name, proxyType );

	if( proxyType == FX_NONE ) {
		fcntl( s, F_SETFL, sockFlags );
		return connect( s, name, namelen );
	} else if( localProxyType == FX_SOCKS ) {
		put( bufptr++, 4 ); /* SOCKS version */
		put( bufptr++, 1 ); /* connect command */
		memcpy( bufptr, &dest -> sin_port, sizeof( dest -> sin_port ) ); /* port */
		bufptr += sizeof( dest -> sin_port );
		memcpy( bufptr, &dest -> sin_addr, sizeof( dest -> sin_addr ) ); /* address */
		bufptr += sizeof( dest -> sin_addr );
		put( bufptr++, NULL ); /* end message */

		bzero( (char *)&proxy, sizeof( proxy ) );
		proxy.sin_family = AF_INET;

		proxyDict = (NSDictionary *)SCDynamicStoreCopyProxies( NULL );
		if( ! proxyDict ) return -1;

		pool = [[NSAutoreleasePool alloc] init];
		[proxyDict autorelease];

		proxy.sin_addr.s_addr = inet_addr( [[[NSHost hostWithName:[proxyDict objectForKey:(NSString *)kSCPropNetProxiesSOCKSProxy]] address] UTF8String] );
		proxy.sin_port = htons( [[proxyDict objectForKey:(NSString *)kSCPropNetProxiesSOCKSPort] shortValue] );

		[pool release];
		proxyDict = nil;
		pool = nil;

		returnVal = connect( s, (struct sockaddr *)&proxy, sizeof( proxy ) );
		if( returnVal ) return returnVal;

		size = send( s, buf, ( bufptr - buf ), 0 );
		if( size != ( bufptr - buf ) ) return -1;
		size = recv( s, buf, 8, 0 );
		if( size != 8 ) return -1;

		if( buf[1] == SOCKS4_SUCCESS ) {
			fcntl( s, F_SETFL, sockFlags );
			return 0;
		} else return -1;
	} else if( localProxyType == FX_HTTPS ) {
		bzero( (char *)&proxy, sizeof( proxy ) );
		proxy.sin_family = AF_INET;

		proxyDict = (NSDictionary *)SCDynamicStoreCopyProxies( NULL );
		if( ! proxyDict ) return -1;

		pool = [[NSAutoreleasePool alloc] init];
		[proxyDict autorelease];

		proxy.sin_addr.s_addr = inet_addr( [[[NSHost hostWithName:[proxyDict objectForKey:(NSString *)kSCPropNetProxiesHTTPSProxy]] address] UTF8String] );
		proxy.sin_port = htons( [[proxyDict objectForKey:(NSString *)kSCPropNetProxiesHTTPSPort] shortValue] );

		[pool release];
		proxyDict = nil;
		pool = nil;

		returnVal = connect( s, (struct sockaddr *)&proxy, sizeof( proxy ) );
		if( returnVal ) return returnVal;

		if( asprintf( &buffer, "CONNECT %s:%hu HTTP/1.1\nHost: %s\nUser-Agent: firetalk/%s\n\n", inet_ntoa( dest -> sin_addr ), dest -> sin_port, inet_ntoa( dest -> sin_addr ), LIBFIRETALK_VERSION ) != 0 ) {
			send( s, buffer, strlen( buffer ), 0 );
			free( buffer );
		}

		while( ! flag ) {
			if( myChar == '\n' ) flag = 1;
			recv( s, &myChar, 1, 0 );
			if( flag == 1 && myChar != '\n' ) flag = 0;
		}

		fcntl( s, F_SETFL, sockFlags );
		return 0;
	}
	return -1;
}