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
// $Id: keycache.c,v 1.1 2004/07/19 03:49:04 jtownsend Exp $
//============================================================================

#include <openssl/lhash.h>
#include <string.h>
#include <assert.h>
#include "buffer.h"
#include "esession.h"

typedef struct
{
    ESessionKeyType keytype;
    const char* id;
    const char* fingerprint;
} PUBKEY;

typedef struct
{
    ESessionKeyType keytype;
    const char* fingerprint;
    const char* public_key;
    EVP_PKEY*   pkey;
} PRIVKEY;

LHASH* _public_key_cache;
LHASH* _private_key_cache;

static unsigned long _hashkey(ESessionKeyType keytype, const char* keyid)
{
    Buffer b;
    unsigned int result;
    
    buffer_init(&b);
    buffer_put_cstring(&b, keyid);
    if (keytype == ES_KEY_RSA)
        buffer_put_cstring(&b, "rsakey");
    else
        buffer_put_cstring(&b, "dsakey");
    b.buf[b.end] = '\0';
    result = lh_strhash(b.buf);
    buffer_free(&b);
    return result;
}

static unsigned long PUBKEY_hash(const PUBKEY* k)
{
    return _hashkey(k->keytype, k->id);
}

static int PUBKEY_cmp(const PUBKEY* lhs, const PUBKEY* rhs)
{
    int rc;
    rc = !(lhs->keytype == rhs->keytype);
    rc = rc || strcmp(lhs->id, rhs->id);
    return rc;
}

static unsigned long PRIVKEY_hash(const PRIVKEY* k)
{
    return _hashkey(k->keytype, k->fingerprint);
}

static int PRIVKEY_cmp(const PRIVKEY* lhs, const PRIVKEY* rhs)
{
    int rc;
    rc = !(lhs->keytype == rhs->keytype);
    rc = rc || strcmp(lhs->fingerprint, rhs->fingerprint);
    return rc;
}

void init_key_caches()
{
    _public_key_cache = lh_new(PUBKEY_hash, PUBKEY_cmp);
    _private_key_cache = lh_new(PRIVKEY_hash, PRIVKEY_cmp);
}

const char* cache_public_key(const char* id, ESessionKeyType keytype, 
                             const char* fingerprint)
{
    PUBKEY* oldpk;
    PUBKEY* pk = (PUBKEY*)malloc(sizeof(PUBKEY));
    pk->id = strdup(id);
    pk->keytype = keytype;
    pk->fingerprint = strdup(fingerprint);

    /* Cleanup any old instances of this key */
    oldpk = lh_retrieve(_public_key_cache, pk);
    if (oldpk != NULL)
    {
        free((char*)oldpk->id);
        free((char*)oldpk->fingerprint);
        free(oldpk);
    }

    lh_insert(_public_key_cache, pk);

    return pk->fingerprint;
}

const char* find_public_fingerprint(const char* id, ESessionKeyType keytype)
{
    PUBKEY* result;
    PUBKEY pk;
    pk.id = id;
    pk.keytype = keytype;

    result = lh_retrieve(_public_key_cache, &pk);
    if (result == NULL)
        return NULL;
    else
        return result->fingerprint;
    
}

const char* cache_personal_key(ESessionKeyType keytype, EVP_PKEY* pkey,
                               char* fingerprint, char* public_key)
{
    PRIVKEY* newkey = (PRIVKEY*)malloc(sizeof(PRIVKEY));
    newkey->keytype = keytype;
    newkey->pkey = pkey;
    newkey->fingerprint = strdup(fingerprint);
    newkey->public_key = strdup(public_key);

    lh_insert(_private_key_cache, newkey);

    return newkey->fingerprint;
}







