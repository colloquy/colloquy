
/*
 *
 * Original code taken from OpenSSH project -- Thanks OpenSSH!
 *
 * Modified 9/4/03 to not depend on OpenSSH internal stuff
 *
 */

/*
 * Author: Tatu Ylonen <ylo@cs.hut.fi>
 * Copyright (c) 1995 Tatu Ylonen <ylo@cs.hut.fi>, Espoo, Finland
 *                    All rights reserved
 *
 * Functions for manipulating fifo buffers (that can grow if needed).
 * Auxiliary functions for storing and retrieving various data types to/from
 * Buffers.
 *
 * As far as I am concerned, the code I have written for this software
 * can be used freely for any purpose.  Any derived versions of this
 * software must be clearly marked as such, and if the derived work is
 * incompatible with the protocol description in the RFC file, it must be
 * called by a name other than "ssh" or "Secure Shell".
 *
 *
 * SSH2 packet format added by Markus Friedl
 * Copyright (c) 2000 Markus Friedl.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "buffer.h"
#include <string.h>
#include <stdlib.h>
#include <assert.h>

/* Pre-decls */
char *b64_encode(char *buf, int len);
int ap_base64decode(char *bufplain, const char *bufcoded);
int ap_base64decode_len(const char *bufcoded);

/* Initializes the buffer structure. */

void
buffer_init(Buffer *buffer)
{
    buffer->alloc = 1024;
    buffer->buf = (u_char*)malloc(buffer->alloc);
    buffer->offset = 0;
    buffer->end = 0;
}

void 
buffer_init_with_size(Buffer* buffer, u_int len)
{
    buffer->alloc = len;
    buffer->buf = (u_char*)malloc(buffer->alloc);
    buffer->offset = 0;
    buffer->end = 0;
}

void     
buffer_init_with_data(Buffer* buffer, u_char* data, u_int data_len)
{
    buffer->alloc = data_len;
    buffer->buf = data;
    buffer->offset = 0;
    buffer->end = data_len;
}

/* Frees any memory used for the buffer. */

void
buffer_free(Buffer *buffer)
{
    memset(buffer->buf, 0, buffer->alloc);
    free(buffer->buf);
}

/*
 * Clears any data from the buffer, making it empty.  This does not actually
 * zero the memory.
 */

void
buffer_clear(Buffer *buffer)
{
    buffer->offset = 0;
    buffer->end = 0;
}

/* Appends data to the buffer, expanding it if necessary. */

void
buffer_append(Buffer *buffer, const void *data, u_int len)
{
    void *p;
    p = buffer_append_space(buffer, len);
    memcpy(p, data, len);
}

/*
 * Appends space to the buffer, expanding the buffer if necessary. This does
 * not actually copy the data into the buffer, but instead returns a pointer
 * to the allocated region.
 */

void *
buffer_append_space(Buffer *buffer, u_int len)
{
    void *p;

    assert(len <= 0x100000);

    /* If the buffer is empty, start using it from the beginning. */
    if (buffer->offset == buffer->end) {
        buffer->offset = 0;
        buffer->end = 0;
    }
restart:
    /* If there is enough space to store all data, store it now. */
    if (buffer->end + len < buffer->alloc) {
        p = buffer->buf + buffer->end;
        buffer->end += len;
        return p;
    }
    /*
     * If the buffer is quite empty, but all data is at the end, move the
     * data to the beginning and retry.
     */
    if (buffer->offset > buffer->alloc / 2) {
        memmove(buffer->buf, buffer->buf + buffer->offset,
                buffer->end - buffer->offset);
        buffer->end -= buffer->offset;
        buffer->offset = 0;
        goto restart;
    }
    /* Increase the size of the buffer and retry. */
    buffer->alloc += len + 32768;
    assert(buffer->alloc <= 0xa00000);
    buffer->buf = (u_char*)realloc(buffer->buf, buffer->alloc);
    goto restart;
    /* NOTREACHED */
}

/* Returns the number of bytes of data in the buffer. */

u_int
buffer_len(Buffer *buffer)
{
    return buffer->end - buffer->offset;
}

/* Gets data from the beginning of the buffer. */

void
buffer_get(Buffer *buffer, void *buf, u_int len)
{
    assert(len <= buffer->end - buffer->offset);

    memcpy(buf, buffer->buf + buffer->offset, len);
    buffer->offset += len;
}

/* Consumes the given number of bytes from the beginning of the buffer. */

void
buffer_consume(Buffer *buffer, u_int bytes)
{
    assert(bytes <= buffer->end - buffer->offset);
    buffer->offset += bytes;
}

/* Consumes the given number of bytes from the end of the buffer. */

void
buffer_consume_end(Buffer *buffer, u_int bytes)
{
    assert(bytes <= buffer->end - buffer->offset);
    buffer->end -= bytes;
}

/* Returns a pointer to the first used byte in the buffer. */

void *
buffer_ptr(Buffer *buffer)
{
    return buffer->buf + buffer->offset;
}

/* Dumps the contents of the buffer to stderr. */

void
buffer_dump(Buffer *buffer)
{
    int i;
    u_char *ucp = buffer->buf;

    for (i = buffer->offset; i < buffer->end; i++) {
        fprintf(stderr, "%02x", ucp[i]);
        if ((i-buffer->offset)%16==15)
            fprintf(stderr, "\r\n");
        else if ((i-buffer->offset)%2==1)
            fprintf(stderr, " ");
    }
    fprintf(stderr, "\r\n");
}

/*
 * Stores an BIGNUM in the buffer in SSH2 format.
 */
void
buffer_put_bignum2(Buffer *buffer, BIGNUM *value)
{
    int bytes = BN_num_bytes(value) + 1;
    u_char *buf = (u_char*)malloc(bytes);
    int oi;
    int hasnohigh = 0;

    buf[0] = '\0';
    /* Get the value of in binary */
    oi = BN_bn2bin(value, buf+1);
    assert(oi == bytes-1);
    hasnohigh = (buf[1] & 0x80) ? 0 : 1;
    if (value->neg) {
        /**XXX should be two's-complement */
        int i, carry;
        u_char *uc = buf;

        for (i = bytes-1, carry = 1; i>=0; i--) {
            uc[i] ^= 0xff;
            if (carry)
                carry = !++uc[i];
        }
    }
    buffer_put_string(buffer, buf+hasnohigh, bytes-hasnohigh);
    memset(buf, 0, bytes);
    free(buf);
}

/* XXX does not handle negative BNs */
void
buffer_get_bignum2(Buffer *buffer, BIGNUM *value)
{
    u_int len;
    u_char *bin = buffer_get_string(buffer, &len);

    assert(len <= 8 * 1024);

    BN_bin2bn(bin, len, value);
    free(bin);
}
/*
 * Returns integers from the buffer (msb first).
 */

u_short
buffer_get_short(Buffer *buffer)
{
    u_char buf[2];

    buffer_get(buffer, (char *) buf, 2);
    return GET_16BIT(buf);
}

u_int
buffer_get_int(Buffer *buffer)
{
    u_char buf[4];

    buffer_get(buffer, (char *) buf, 4);
    return GET_32BIT(buf);
}

#ifdef HAVE_U_INT64_T
u_int64_t
buffer_get_int64(Buffer *buffer)
{
    u_char buf[8];

    buffer_get(buffer, (char *) buf, 8);
    return GET_64BIT(buf);
}
#endif

/*
 * Stores integers in the buffer, msb first.
 */
void
buffer_put_short(Buffer *buffer, u_short value)
{
    char buf[2];

    PUT_16BIT(buf, value);
    buffer_append(buffer, buf, 2);
}

void
buffer_put_int(Buffer *buffer, u_int value)
{
    char buf[4];

    PUT_32BIT(buf, value);
    buffer_append(buffer, buf, 4);
}

#ifdef HAVE_U_INT64_T
void
buffer_put_int64(Buffer *buffer, u_int64_t value)
{
    char buf[8];

    PUT_64BIT(buf, value);
    buffer_append(buffer, buf, 8);
}
#endif

/*
 * Returns an arbitrary binary string from the buffer.  The string cannot
 * be longer than 256k.  The returned value points to memory allocated
 * with xmalloc; it is the responsibility of the calling function to free
 * the data.  If length_ptr is non-NULL, the length of the returned data
 * will be stored there.  A null character will be automatically appended
 * to the returned string, and is not counted in length.
 */
void *
buffer_get_string(Buffer *buffer, u_int *length_ptr)
{
    u_char *value;
    u_int len;

    /* Get the length. */
    len = buffer_get_int(buffer);
    assert (len <= 256 * 1024);

    /* Allocate space for the string.  Add one byte for a null character. */
    value = (u_char*)malloc(len + 1);
    /* Get the string. */
    buffer_get(buffer, value, len);
    /* Append a null character to make processing easier. */
    value[len] = 0;
    /* Optionally return the length of the string. */
    if (length_ptr)
        *length_ptr = len;
    return value;
}

/*
 * Stores and arbitrary binary string in the buffer.
 */
void
buffer_put_string(Buffer *buffer, const void *buf, u_int len)
{
    buffer_put_int(buffer, len);
    buffer_append(buffer, buf, len);
}
void
buffer_put_cstring(Buffer *buffer, const char *s)
{
    assert(s != NULL);

    buffer_put_string(buffer, s, strlen(s));
}

/*
 * Returns a character from the buffer (0 - 255).
 */
int
buffer_get_char(Buffer *buffer)
{
    char ch;

    buffer_get(buffer, &ch, 1);
    return (u_char) ch;
}

/*
 * Stores a character in the buffer.
 */
void
buffer_put_char(Buffer *buffer, int value)
{
    char ch = value;

    buffer_append(buffer, &ch, 1);
}

/*
 * Convert a buffer to a base64 encoded string
 */
unsigned char*
buffer_base64_encode(Buffer *buffer)
{
    return b64_encode(buffer->buf + buffer->offset,
                      buffer->end - buffer->offset);
}

/*
 * Create a buffer from a base64 encoded string
 */
void
buffer_init_from_base64(Buffer *buffer, const u_char* b64str)
{
    buffer->alloc = ap_base64decode_len(buffer->buf);
    buffer->buf = (u_char*)malloc(buffer->alloc);
    buffer->offset = 0;
    buffer->end = ap_base64decode(buffer->buf, b64str);
}
