/*
 *
 * Original code taken from OpenSSH project -- Thanks OpenSSH!
 *
 */

/*
 * Author: Tatu Ylonen <ylo@cs.hut.fi>
 * Copyright (c) 1995 Tatu Ylonen <ylo@cs.hut.fi>, Espoo, Finland
 *                    All rights reserved
 * Code for manipulating FIFO buffers.
 *
 * As far as I am concerned, the code I have written for this software
 * can be used freely for any purpose.  Any derived versions of this
 * software must be clearly marked as such, and if the derived work is
 * incompatible with the protocol description in the RFC file, it must be
 * called by a name other than "ssh" or "Secure Shell".
 */

#ifndef BUFFER_H
#define BUFFER_H

#include <openssl/bn.h>

typedef struct {
	u_char	*buf;		/* Buffer for data. */
	u_int	 alloc;		/* Number of bytes allocated for data. */
	u_int	 offset;	/* Offset of first byte containing data. */
	u_int	 end;		/* Offset of last byte containing data. */
}       Buffer;

void	 buffer_init(Buffer *);
void	 buffer_clear(Buffer *);
void	 buffer_free(Buffer *);

void     buffer_init_with_size(Buffer* buffer, u_int len);
void     buffer_init_with_data(Buffer*, u_char*, u_int);

u_int	 buffer_len(Buffer *);
void	*buffer_ptr(Buffer *);

void	 buffer_append(Buffer *, const void *, u_int);
void	*buffer_append_space(Buffer *, u_int);

void	 buffer_get(Buffer *, void *, u_int);

void	 buffer_consume(Buffer *, u_int);
void	 buffer_consume_end(Buffer *, u_int);

void     buffer_dump(Buffer *);

void    buffer_put_bignum2(Buffer *, BIGNUM *);
void	buffer_get_bignum2(Buffer *, BIGNUM *);

u_short	buffer_get_short(Buffer *);
void	buffer_put_short(Buffer *, u_short);

u_int	buffer_get_int(Buffer *);
void    buffer_put_int(Buffer *, u_int);

#ifdef HAVE_U_INT64_T
u_int64_t buffer_get_int64(Buffer *);
void	buffer_put_int64(Buffer *, u_int64_t);
#endif

int     buffer_get_char(Buffer *);
void    buffer_put_char(Buffer *, int);

void   *buffer_get_string(Buffer *, u_int *);
void    buffer_put_string(Buffer *, const void *, u_int);
void	buffer_put_cstring(Buffer *, const char *);

void buffer_init_from_base64(Buffer *buffer, const u_char* b64str);
unsigned char* buffer_base64_encode(Buffer *buffer);

#define buffer_skip_string(b) \
    do { u_int l = buffer_get_int(b); buffer_consume(b, l); } while(0)

#endif /* BUFFER_H */

/*
 * Author: Tatu Ylonen <ylo@cs.hut.fi>
 * Copyright (c) 1995 Tatu Ylonen <ylo@cs.hut.fi>, Espoo, Finland
 *                    All rights reserved
 * Macros for storing and retrieving data in msb first and lsb first order.
 *
 * As far as I am concerned, the code I have written for this software
 * can be used freely for any purpose.  Any derived versions of this
 * software must be clearly marked as such, and if the derived work is
 * incompatible with the protocol description in the RFC file, it must be
 * called by a name other than "ssh" or "Secure Shell".
 */

#ifndef GETPUT_H
#define GETPUT_H

/*------------ macros for storing/extracting msb first words -------------*/

#define GET_64BIT(cp) (((u_int64_t)(u_char)(cp)[0] << 56) | \
		       ((u_int64_t)(u_char)(cp)[1] << 48) | \
		       ((u_int64_t)(u_char)(cp)[2] << 40) | \
		       ((u_int64_t)(u_char)(cp)[3] << 32) | \
		       ((u_int64_t)(u_char)(cp)[4] << 24) | \
		       ((u_int64_t)(u_char)(cp)[5] << 16) | \
		       ((u_int64_t)(u_char)(cp)[6] << 8) | \
		       ((u_int64_t)(u_char)(cp)[7]))

#define GET_32BIT(cp) (((u_long)(u_char)(cp)[0] << 24) | \
		       ((u_long)(u_char)(cp)[1] << 16) | \
		       ((u_long)(u_char)(cp)[2] << 8) | \
		       ((u_long)(u_char)(cp)[3]))

#define GET_16BIT(cp) (((u_long)(u_char)(cp)[0] << 8) | \
		       ((u_long)(u_char)(cp)[1]))

#define PUT_64BIT(cp, value) do { \
  (cp)[0] = (value) >> 56; \
  (cp)[1] = (value) >> 48; \
  (cp)[2] = (value) >> 40; \
  (cp)[3] = (value) >> 32; \
  (cp)[4] = (value) >> 24; \
  (cp)[5] = (value) >> 16; \
  (cp)[6] = (value) >> 8; \
  (cp)[7] = (value); } while (0)

#define PUT_32BIT(cp, value) do { \
  (cp)[0] = (value) >> 24; \
  (cp)[1] = (value) >> 16; \
  (cp)[2] = (value) >> 8; \
  (cp)[3] = (value); } while (0)

#define PUT_16BIT(cp, value) do { \
  (cp)[0] = (value) >> 8; \
  (cp)[1] = (value); } while (0)

#endif				/* GETPUT_H */
