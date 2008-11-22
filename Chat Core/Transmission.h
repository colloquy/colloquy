/*
Copyright (c) 2006 Transmission authors and contributors

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

void tr_msgInit( void );
void tr_setMessageLevel( int level );

void tr_fdInit( void );

typedef struct tr_natpmp_s tr_natpmp_t;

tr_natpmp_t *tr_natpmpInit( void );
void tr_natpmpStart( tr_natpmp_t * );
void tr_natpmpStop( tr_natpmp_t * );
int tr_natpmpStatus( tr_natpmp_t * );
void tr_natpmpForwardPort( tr_natpmp_t *, int port );
void tr_natpmpPulse( tr_natpmp_t * );
void tr_natpmpClose( tr_natpmp_t * );

typedef struct tr_upnp_s tr_upnp_t;

tr_upnp_t *tr_upnpInit( void );
void tr_upnpStart( tr_upnp_t * );
void tr_upnpStop( tr_upnp_t * );
int tr_upnpStatus( tr_upnp_t * );
void tr_upnpForwardPort( tr_upnp_t *, int port );
void tr_upnpPulse( tr_upnp_t * );
void tr_upnpClose( tr_upnp_t * );

#define TR_NAT_TRAVERSAL_MAPPING 1
#define TR_NAT_TRAVERSAL_MAPPED 2
#define TR_NAT_TRAVERSAL_NOTFOUND 3
#define TR_NAT_TRAVERSAL_ERROR 4
#define TR_NAT_TRAVERSAL_UNMAPPING 5
#define TR_NAT_TRAVERSAL_DISABLED 6
