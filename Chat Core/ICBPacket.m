/*
 * Chat Core
 * ICB Protocol Support
 *
 * Copyright (c) 2006, 2007 Julio M. Merino Vidal <jmmv@NetBSD.org>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *    1. Redistributions of source code must retain the above
 *       copyright notice, this list of conditions and the following
 *       disclaimer.
 *    2. Redistributions in binary form must reproduce the above
 *       copyright notice, this list of conditions and the following
 *       disclaimer in the documentation and/or other materials
 *       provided with the distribution.
 *    3. The name of the author may not be used to endorse or promote
 *       products derived from this software without specific prior
 *       written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS
 * OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 * GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 * IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
 * IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>

#import "ICBPacket.h"

@implementation ICBPacket

//
// An ICB packet has the following format:
//
// length (1 byte): Specifies the packet length.  Includes the
//                  trailing null character (if present) but does
//                  not include the length byte.
// type (1 byte):   The packet's type.
// contents:        A list of fields, separated by a 0x01 byte, that make
//                  up the packet.  The list may be null terminated (not
//                  required by the protocol but recommended to remain
//                  compatible with several implementations), in which case
//                  the terminator counts as part of the message's length.
//
// This class is provided to painlessly construct and parse such packets.
// We add the null terminator character when creating a packet but do not
// require it on received packets.
//

#pragma mark Constructors and finalizers

- (id) initWithPacketType:(char) t {
	if( ( self = [super init] ) ) {
		_type = t;
		_fields = [[NSMutableArray alloc] initWithCapacity:5];
	}
	return self;
}

- (id) initFromRawData:(NSData *) raw {
	if( ( self = [super init] ) ) {
		NSUInteger length = raw.length;
		const char *bytes = (const char *)[raw bytes];

		// Note that 'raw' does not include the length byte.

		// Trim the null terminator, if present.
		if( length > 0 && bytes[length - 1] == '\0' )
			length--;

		// The packet must contain, at least, the type byte to be valid.
		if( length < 1 )
			return nil;

		// Discount the type byte as part of the length.
		length--;

		_type = bytes[0];
		_fields = [[NSMutableArray alloc] initWithCapacity:5];

		if( length > 0 ) {
			const char *data = bytes + 1;

			NSUInteger last = 0;
			for( NSUInteger i = 0; i < length; i++ ) {
				if( data[i] == '\x01' && last < i ) {
					NSString *f = [[NSString alloc] initWithBytes:&data[last]
											length:i - last
											encoding:NSISOLatin1StringEncoding];
					[_fields addObject:f];
					last = i + 1;
				} else if( data[i] == '\x01' ) {
					NSAssert( last == i, @"invalid invariant" );
					last = i + 1;
				}
			}

			NSString *f = [[NSString alloc] initWithBytes:&data[last]
									length:length - last
									encoding:NSISOLatin1StringEncoding];
			[_fields addObject:f];
		}
	}
	return self;
}

#pragma mark Accessors

- (NSString *) description {
	NSString *s = [NSString stringWithFormat:@"Length: %lu, type: %c, ",
	                                         (unsigned long)self.length, _type];

	if( _fields.count == 0 )
		s = [s stringByAppendingString:@"no fields"];
	else {
		s = [s stringByAppendingString:@"fields: "];
		for( NSUInteger i = 0; i < _fields.count; i++ ) {
			const NSString *f = [_fields objectAtIndex:i];
			if (i < _fields.count - 1)
				s = [s stringByAppendingFormat:@"%@, ", f];
			else
				s = [s stringByAppendingFormat:@"%@", f];
		}
	}

	return s;
}

- (NSArray *) fields {
	return _fields;
}

- (NSUInteger) length {
	NSUInteger l = 2;

	if( _fields.count > 0 ) {
		// Add the separators and null terminator to the packet length.
		l += _fields.count;

		// Add the fields themselves to the packet length.
		for( NSString *f in _fields )
			l += f.length;
	}

	return l;
}

- (NSData *) rawData {
	static const NSUInteger maxRawLength = 256;
	static const NSUInteger maxDataLength = 253;

	char raw[maxRawLength];
	char *data = &raw[2];
	NSUInteger length = 0;

	// Fill the packet data.
	data[0] = '\0';
	for( NSUInteger i = 0; i < _fields.count; i++) {
		const NSString *f = [_fields objectAtIndex:i];

		length = strlcat(data, [f UTF8String], maxDataLength);
		if (i < _fields.count - 1)
			length = strlcat(data, "\x01", maxDataLength);
	}
	NSAssert( length < 255, @"Packet too long" );
	NSAssert( data[length] == '\0', @"Packet without null" );

	// Fill the packet header.
	raw[0] = length + 2; // 1 byte for type, 1 for null character.
	raw[1] = _type;

	NSAssert( self.length == length + 3, @"Length mismatch" );
	return [NSData dataWithBytes:raw length:length + 3];
}

- (char) type {
	return _type;
}

#pragma mark Modifiers

- (void) addFields:(NSString *) first, ... {
	[_fields addObject:first];

	va_list ap;
	va_start(ap, first);
	NSString *f;
	while( ( f = va_arg(ap, NSString *) ) )
		[_fields addObject:f];
	va_end(ap);
}

@end
