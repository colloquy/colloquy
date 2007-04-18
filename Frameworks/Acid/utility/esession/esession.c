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
// $Id: esession.c,v 1.1 2004/07/19 03:49:04 jtownsend Exp $
//============================================================================

#include "esession.h"
#include <openssl/ssl.h>
#include <assert.h>
#include "buffer.h"
#include <string.h>

/* Pre-decls */
char* b64_encode(char* buf, int len);
void b64_decode(const char* data, char* result, int* result_len);

/* 
 * Internal module variables 
 */

/* Error and state info */
ESessionError _last_error;

/* Callback info */
ESessionNewKeyCallback*     _newkey_cb;
void*                       _newkey_cb_arg;
ESessionChangedKeyCallback* _changedkey_cb;
void*                       _changedkey_cb_arg;
ESessionGetPassCallback*    _getpass_cb;
void*                       _getpass_cb_arg;

/* Public key cache -- see keycache.c */
void init_key_caches();
const char* cache_public_key(const char* id, ESessionKeyType keytype, 
                             const char* fingerprint);
const char* find_public_fingerprint(const char* id, 
                                    ESessionKeyType keytype);
const char* cache_personal_key(ESessionKeyType keytype, EVP_PKEY* pkey,
                               char* fingerprint, char* public_key);

/* MODP groups, as defined in RFC 3526 */
static const char* MODP_5 = "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA237327FFFFFFFFFFFFFFFF";
static const char* MODP_14 = "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3BE39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF6955817183995497CEA956AE515D2261898FA051015728E5A8AACAA68FFFFFFFFFFFFFFFF";
static const char* MODP_15 = "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3BE39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF6955817183995497CEA956AE515D2261898FA051015728E5A8AAAC42DAD33170D04507A33A85521ABDF1CBA64ECFB850458DBEF0A8AEA71575D060C7DB3970F85A6E1E4C7ABF5AE8CDB0933D71E8C94E04A25619DCEE3D2261AD2EE6BF12FFA06D98A0864D87602733EC86A64521F2B18177B200CBBE117577A615D6C770988C0BAD946E208E24FA074E5AB3143DB5BFCE0FD108E4B82D120A93AD2CAFFFFFFFFFFFFFFFF";
static const char* MODP_16 = "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3BE39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF6955817183995497CEA956AE515D2261898FA051015728E5A8AAAC42DAD33170D04507A33A85521ABDF1CBA64ECFB850458DBEF0A8AEA71575D060C7DB3970F85A6E1E4C7ABF5AE8CDB0933D71E8C94E04A25619DCEE3D2261AD2EE6BF12FFA06D98A0864D87602733EC86A64521F2B18177B200CBBE117577A615D6C770988C0BAD946E208E24FA074E5AB3143DB5BFCE0FD108E4B82D120A92108011A723C12A787E6D788719A10BDBA5B2699C327186AF4E23C1A946834B6150BDA2583E9CA2AD44CE8DBBBC2DB04DE8EF92E8EFC141FBECAA6287C59474E6BC05D99B2964FA090C3A2233BA186515BE7ED1F612970CEE2D7AFB81BDD762170481CD0069127D5B05AA993B4EA988D8FDDC186FFB7DC90A6C08F4DF435C934063199FFFFFFFFFFFFFFFF";
static const char* MODP_17 = "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3BE39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF6955817183995497CEA956AE515D2261898FA051015728E5A8AAAC42DAD33170D04507A33A85521ABDF1CBA64ECFB850458DBEF0A8AEA71575D060C7DB3970F85A6E1E4C7ABF5AE8CDB0933D71E8C94E04A25619DCEE3D2261AD2EE6BF12FFA06D98A0864D87602733EC86A64521F2B18177B200CBBE117577A615D6C770988C0BAD946E208E24FA074E5AB3143DB5BFCE0FD108E4B82D120A92108011A723C12A787E6D788719A10BDBA5B2699C327186AF4E23C1A946834B6150BDA2583E9CA2AD44CE8DBBBC2DB04DE8EF92E8EFC141FBECAA6287C59474E6BC05D99B2964FA090C3A2233BA186515BE7ED1F612970CEE2D7AFB81BDD762170481CD0069127D5B05AA993B4EA988D8FDDC186FFB7DC90A6C08F4DF435C93402849236C3FAB4D27C7026C1D4DCB2602646DEC9751E763DBA37BDF8FF9406AD9E530EE5DB382F413001AEB06A53ED9027D831179727B0865A8918DA3EDBEBCF9B14ED44CE6CBACED4BB1BDB7F1447E6CC254B332051512BD7AF426FB8F401378CD2BF5983CA01C64B92ECF032EA15D1721D03F482D7CE6E74FEF6D55E702F46980C82B5A84031900B1C9E59E7C97FBEC7E8F323A97A7E36CC88BE0F1D45B7FF585AC54BD407B22B4154AACC8F6D7EBF48E1D814CC5ED20F8037E0A79715EEF29BE32806A1D58BB7C5DA76F550AA3D8A1FBFF0EB19CCB1A313D55CDA56C9EC2EF29632387FE8D76E3C0468043E8F663F4860EE12BF2D5B0B7474D6E694F91E6DCC4024FFFFFFFFFFFFFFFF";
static const char* MODP_18 = "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3BE39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF6955817183995497CEA956AE515D2261898FA051015728E5A8AAAC42DAD33170D04507A33A85521ABDF1CBA64ECFB850458DBEF0A8AEA71575D060C7DB3970F85A6E1E4C7ABF5AE8CDB0933D71E8C94E04A25619DCEE3D2261AD2EE6BF12FFA06D98A0864D87602733EC86A64521F2B18177B200CBBE117577A615D6C770988C0BAD946E208E24FA074E5AB3143DB5BFCE0FD108E4B82D120A92108011A723C12A787E6D788719A10BDBA5B2699C327186AF4E23C1A946834B6150BDA2583E9CA2AD44CE8DBBBC2DB04DE8EF92E8EFC141FBECAA6287C59474E6BC05D99B2964FA090C3A2233BA186515BE7ED1F612970CEE2D7AFB81BDD762170481CD0069127D5B05AA993B4EA988D8FDDC186FFB7DC90A6C08F4DF435C93402849236C3FAB4D27C7026C1D4DCB2602646DEC9751E763DBA37BDF8FF9406AD9E530EE5DB382F413001AEB06A53ED9027D831179727B0865A8918DA3EDBEBCF9B14ED44CE6CBACED4BB1BDB7F1447E6CC254B332051512BD7AF426FB8F401378CD2BF5983CA01C64B92ECF032EA15D1721D03F482D7CE6E74FEF6D55E702F46980C82B5A84031900B1C9E59E7C97FBEC7E8F323A97A7E36CC88BE0F1D45B7FF585AC54BD407B22B4154AACC8F6D7EBF48E1D814CC5ED20F8037E0A79715EEF29BE32806A1D58BB7C5DA76F550AA3D8A1FBFF0EB19CCB1A313D55CDA56C9EC2EF29632387FE8D76E3C0468043E8F663F4860EE12BF2D5B0B7474D6E694F91E6DBE115974A3926F12FEE5E438777CB6A932DF8CD8BEC4D073B931BA3BC832B68D9DD300741FA7BF8AFC47ED2576F6936BA424663AAB639C5AE4F5683423B4742BF1C978238F16CBE39D652DE3FDB8BEFC848AD922222E04A4037C0713EB57A81A23F0C73473FC646CEA306B4BCBC8862F8385DDFA9D4B7FA2C087E879683303ED5BDD3A062B3CF5B3A278A66D2A13F83F44F82DDF310EE074AB6A364597E899A0255DC164F31CC50846851DF9AB48195DED7EA1B1D510BD7EE74D73FAF36BC31ECFA268359046F4EB879F924009438B481C6CD7889A002ED5EE382BC9190DA6FC026E479558E4475677E9AA9E3050E2765694DFC81F56E880B96E7160C980DD98EDD3DFFFFFFFFFFFFFFFFF";


static void _make_key(BUF_MEM K, char id, Buffer* sid,
                      unsigned char keybuf[EVP_MAX_MD_SIZE],
                      unsigned int* keybuf_len)
{
    EVP_MD_CTX ctx;
    EVP_DigestInit(&ctx, EVP_sha1());
    EVP_DigestUpdate(&ctx, K.data, K.length);
    EVP_DigestUpdate(&ctx, &id, 1);
    EVP_DigestUpdate(&ctx, buffer_ptr(sid), buffer_len(sid));
    EVP_DigestFinal(&ctx, keybuf, keybuf_len);
}

static void _setup_cipher(int encrypt_flag, ESessionCipherAlgo algo, 
                          BUF_MEM K, Buffer* sid, char IV_id, 
                          char Enc_id, EVP_CIPHER_CTX* result)
{
    unsigned char ivbuf[EVP_MAX_MD_SIZE];
    unsigned int ivbuf_len;
    unsigned char keybuf[EVP_MAX_MD_SIZE];
    unsigned int keybuf_len;
    EVP_CIPHER* cipher_type;

    /* Ensure the size of the biggest max digest is bigger
       than the max key length and IV length -- avoid some
       malloc's */
    assert(EVP_MAX_MD_SIZE >= EVP_MAX_KEY_LENGTH);
    assert(EVP_MAX_MD_SIZE >= EVP_MAX_IV_LENGTH);

    /* Setup the keys */
    _make_key(K, IV_id, sid, ivbuf, &ivbuf_len);
    _make_key(K, Enc_id, sid, keybuf, &keybuf_len);

    /* Initialize the cipher structure */
    EVP_CIPHER_CTX_init(result);

    switch(algo)
    {
    case ES_CIPHER_3DES_CBC:
        cipher_type = EVP_des_ede3_cbc();
        break;
    case ES_CIPHER_BLOWFISH_CBC:
        cipher_type = EVP_bf_cbc();
        break;
    };

    EVP_CipherInit(result, cipher_type, keybuf, ivbuf, encrypt_flag);
}

void _compute_sid(const char* key, BIGNUM* e, BIGNUM* f, BUF_MEM K,
                      Buffer* result)
{
    EVP_MD_CTX     ctx;
    Buffer         buf;

    /* Construct buffer w/ all appropriate data */
    buffer_init(&buf);
    buffer_put_cstring(&buf, key); /* Bob's base64 encoded public key */
    buffer_put_bignum2(&buf, e);   /* big-endian binary rep of "e" */
    buffer_put_bignum2(&buf, f);   /* big-endian binary rep of "f" */
    buffer_append(&buf, K.data, K.length); /* big-endian binary rep of
                                              K (which we get in that
                                              format straight out of
                                              DH, as it turns out. */

    /* Init the result */
    buffer_init_with_size(result, EVP_MAX_MD_SIZE);

    /* Generate the hash */
    EVP_DigestInit(&ctx, EVP_sha1());
    EVP_DigestUpdate(&ctx, buffer_ptr(&buf), buffer_len(&buf));
    EVP_DigestFinal(&ctx, result->buf, &result->end);

    /* Cleanup buffer */
    buffer_free(&buf);

}

static char* _key_hex_fingerprint(Buffer* rawkeybuf)
{
    EVP_MD_CTX ctx;
    char keydigest[EVP_MAX_MD_SIZE];
    int keydigest_len;
    char* result;
    int i;

    /* Generate MD5 hash */
    EVP_DigestInit(&ctx, EVP_md5());
    EVP_DigestUpdate(&ctx, buffer_ptr(rawkeybuf), buffer_len(rawkeybuf));
    EVP_DigestFinal(&ctx, keydigest, &keydigest_len);

    /* Turn it into something meaningful... */
    result = (char*)calloc(1, (keydigest_len * 3) + 1);
 
    for(i = 0; i < keydigest_len; i++)
    {
        snprintf(result + (i*4), 4, "%02x:", keydigest[i]);        
    }
    return result;
}

static EVP_PKEY* _process_public_key(const char* id, ESessionKeyType keytype, 
                                     const char* keystr)
{
    Buffer rawkeybuf;
    EVP_PKEY* result;
    char* fingerprint;
    const char* cached_fingerprint;
    ESessionCBResult cb_result;
    
    /* First of all, base64 decode this keystring */
    buffer_init_from_base64(&rawkeybuf, keystr);

    /* Turn the MD5 hash into printed form */
    fingerprint = _key_hex_fingerprint(&rawkeybuf);

    /* Check for a cached fingerprint, given this ID and keytype */
    cached_fingerprint = find_public_fingerprint(id, keytype);
    if (cached_fingerprint != NULL)
    {
        /* We found a cached version -- check to see if the fingerprint
           is changed */
        if (strcmp(fingerprint, cached_fingerprint) != 0)
        {
            /* Something changed -- notify the caller */
            cb_result = (*_changedkey_cb)(keytype, id, cached_fingerprint, 
                                          fingerprint, _changedkey_cb_arg);

            /* Caller said that a changed key is ok -- update
               the cache */
            if (cb_result == ES_RESULT_OK)
            {
                cache_public_key(id, keytype, fingerprint);
            }
            else
            {
                free(fingerprint);
                _last_error = ES_ERR_PUBLIC_KEY_CHANGED;
                return NULL;
            }
        }
    }
    else
    {
        /* No matching key in the cache -- notify the caller */
        cb_result = (*_newkey_cb)(keytype, id, keystr, fingerprint,
                                  _newkey_cb_arg);

        /* Caller indicated the key is OK */
        if (cb_result == ES_RESULT_OK)
        {
            cache_public_key(id, keytype, fingerprint);
        }
        else
        {
            free(fingerprint);
            _last_error = ES_ERR_PUBLIC_KEY_NOT_ACCEPTED;
            return NULL;
        }
    }

    /* We got past the fingerprint checks -- go ahead and construct
       the public key from the data */
    result = EVP_PKEY_new();

    if (keytype == ES_KEY_RSA)
    {
        RSA* rkey = RSA_new();
        buffer_get_bignum2(&rawkeybuf, rkey->e);
        buffer_get_bignum2(&rawkeybuf, rkey->n);
        EVP_PKEY_assign_RSA(result, rkey);        
    }
    else
    {
        DSA* dkey = DSA_new();
        buffer_get_bignum2(&rawkeybuf, dkey->p);
        buffer_get_bignum2(&rawkeybuf, dkey->q);
        buffer_get_bignum2(&rawkeybuf, dkey->g);
        buffer_get_bignum2(&rawkeybuf, dkey->pub_key);
        EVP_PKEY_assign_DSA(result, dkey);
    }

    /* Cleanup */
    free(fingerprint);

    return result;
}    

/* 
 * 
 * Global ESession functions 
 *
 */

int es_get_last_error()
{
    return _last_error;
}

static int _es_get_password(char* buf, int len, int rwflag, void* cbarg)
{
    const char* result;
    result = (*_getpass_cb)((const char*)cbarg, _getpass_cb_arg);
    if (result != NULL)
    {
        strncpy(buf, result, len-1);
        return 0;
    }
    else
    {
        return -1;
    }
}

const char* es_add_personal_key(const char* private_key)
{
    EVP_PKEY* key;
    BIO* membio;
    Buffer b;
    char* fingerprint;
    char* public_key;
    const char* result;
    ESessionKeyType keytype;


    /* Wrap the provided private key with a memory based BIO */
    membio = BIO_new_mem_buf((char*)private_key, strlen(private_key));

    /* Read the result into the key structure */
    key = PEM_read_bio_PrivateKey(membio, NULL, _es_get_password, 
                                  (void*)private_key);

    /* Check for errors */
    if (key == NULL)
    {
        _last_error = ES_ERR_INVALID_PERSONAL_KEY;
        return NULL;
    }

    buffer_init(&b);

    /* Extract the public key values */
    if (EVP_PKEY_type(key->type) == EVP_PKEY_RSA)
    {
        keytype = ES_KEY_RSA;
        buffer_put_bignum2(&b, key->pkey.rsa->e);
        buffer_put_bignum2(&b, key->pkey.rsa->n);        
    }
    else if (EVP_PKEY_type(key->type) == EVP_PKEY_DSA)
    {
        keytype = ES_KEY_DSA;
        buffer_put_bignum2(&b, key->pkey.dsa->p);
        buffer_put_bignum2(&b, key->pkey.dsa->q);
        buffer_put_bignum2(&b, key->pkey.dsa->g);
        buffer_put_bignum2(&b, key->pkey.dsa->pub_key);
    }
    else
    {
        /* Bad things!!! */
        assert(0);
    }

    /* Now generate a fingerprint for the key */
    fingerprint = _key_hex_fingerprint(&b);

    /* Generate a base64 encoded public key */
    public_key = buffer_base64_encode(&b);

    /* Ok, we have enough info to cache this key:
       EVP_PKEY, key type, fingerprint, public_key */
    result = cache_personal_key(keytype, key, fingerprint, public_key);

    /* Cleanup */
    buffer_free(&b);
    free(fingerprint);
    free(public_key);

    return result;
}

const char* es_add_public_key(const char* id, ESessionKeyType keytype, const char* public_key)
{
    Buffer rawkeybuf;
    char* fingerprint;
    const char* result;

    /* First of all, base64 decode the keystring */
    buffer_init_from_base64(&rawkeybuf, public_key);

    /* Turn the MD5 hash into printed form */
    fingerprint = _key_hex_fingerprint(&rawkeybuf);

    /* Cache the fingerprint and identifier in the keycache */
    result = cache_public_key(id, keytype, fingerprint);

    /* Cleanup */
    free(fingerprint);
    
    return result;
}

void es_set_new_key_cb(ESessionNewKeyCallback* cb, void* arg)
{
    _newkey_cb = cb;
    _newkey_cb_arg = arg;
}

void es_set_get_pass_cb(ESessionGetPassCallback* cb, void* arg)
{
    _getpass_cb = cb;
    _getpass_cb_arg = arg;
}

void es_set_changed_key_cb(ESessionChangedKeyCallback* cb, void* arg)
{
    _changedkey_cb = cb;
    _changedkey_cb_arg = arg;
}

ESessionKeyPair es_generate_keypair(ESessionKeyType keytype, int bits,
                                    const char* privatepass)
{
    Buffer b;
    BIO* membio;
    BUF_MEM* membio_buf;

    /* Create a PKEY to hold whatever we generate */
    EVP_PKEY* evpkey = EVP_PKEY_new();

    /* Create result to hold the new key */
    ESessionKeyPair result = (ESessionKeyPair)malloc(sizeof(_ESessionKeyPair_st));
    result->type = keytype;

    /* Generate the appropriate keys */
    if (keytype == ES_KEY_RSA)
    {
        RSA* rkey;
        int keyisgood = 0;

        /* Ensure we have enough bits */
        assert(bits >= 1024);

        /* Generate keys until a good one turns up. */
        while (keyisgood != 1)
        {
            rkey = RSA_generate_key(bits, RSA_3, NULL, NULL);
            keyisgood = (RSA_check_key(rkey) == 1);
        }

        /* Encode the public key, according to SSH spec -- sect. 4.6 */
        buffer_init(&b);
        buffer_put_bignum2(&b, rkey->e);
        buffer_put_bignum2(&b, rkey->n);
        result->public_key = buffer_base64_encode(&b);
        buffer_free(&b);

        /* Store the resulting key into a EVP_PKEY struct */
        EVP_PKEY_assign_RSA(evpkey, rkey);
    }
    else if (keytype == ES_KEY_DSA)
    {
        DSA* dkey;
        dkey = DSA_generate_parameters(1024, NULL, 0, NULL, NULL,
                                       NULL, NULL);
        DSA_generate_key(dkey);

        /* Encode the public key, according to SSH spec -- sect. 4.6 */
        buffer_init(&b);
        buffer_put_bignum2(&b, dkey->p);
        buffer_put_bignum2(&b, dkey->q);
        buffer_put_bignum2(&b, dkey->g);
        buffer_put_bignum2(&b, dkey->pub_key);
        result->public_key = buffer_base64_encode(&b);
        buffer_free(&b);
        
        /* Store the resulting key into a EVP_PKEY struct */
        EVP_PKEY_assign_DSA(evpkey, dkey);
    }

    /* Now, let's encode the private key in standard PEM format */
    membio = BIO_new(BIO_s_mem());
    PEM_write_bio_PrivateKey(membio, evpkey, EVP_des_ede3_cbc(),
                             (char*)privatepass, strlen(privatepass),
                             NULL, NULL);

    /* Write the PEM data into a string... */
    BIO_get_mem_ptr(membio, &membio_buf);
    result->private_key = (char*)malloc(membio_buf->length + 1);
    result->private_key[membio_buf->length] = '\0';
    memcpy(result->private_key, membio_buf->data, membio_buf->length);

    /* Cleanup */
    BIO_free(membio);
    EVP_PKEY_free(evpkey);

    return result;
}


void es_keypair_free(ESessionKeyPair ekp)
{
    /* Just do a simple memory overwrite of the private key */
    int private_len = strlen(ekp->private_key);
    memset(ekp->private_key, '\0', private_len);

    /* Let it all go... */
    free(ekp->private_key);
    free(ekp->public_key);
    free(ekp);
}

ESession esession_new(const char* id)
{
    ESession result = (ESession)calloc(1, sizeof(_ESession_st));
    result->_id = strdup(id);

    return result;
}

void esession_set_modp_group(ESession es, ESessionMODPGroup group)
{
    switch (group)
    {
    case ES_MODP_5:
        es->_modp = MODP_5;
        break;
    case ES_MODP_14:
        es->_modp = MODP_14;
        break;
    case ES_MODP_15:
        es->_modp = MODP_15;
        break;
    case ES_MODP_16:
        es->_modp = MODP_16;
        break;
    case ES_MODP_17:
        es->_modp = MODP_17;
        break;
    case ES_MODP_18:
        es->_modp = MODP_18;
        break;
    }
}


ESessionHandshake esession_handshake_start(ESession es)
{
    ESessionHandshake result;

    /* Ensure state is good */
    assert(es->_state == ES_NEW);
    assert(es->_modp != NULL);

    /* Initialize DH values */
    es->_dh = DH_new();
    BN_dec2bn(&(es->_dh->p), es->_modp);
    BN_set_word(es->_dh->g, 2);

    /* Generate DH key; _dh->pub_key corresponds
       to "e" in the JEP */
    DH_generate_key(es->_dh);

    /* Setup result object */
    result = (ESessionHandshake)calloc(1, sizeof(_ESessionHandshake_st));
    result->type = 0;
    result->e = BN_bn2hex(es->_dh->pub_key);

    /* Update state */
    es->_state = ES_HANDSHAKE;

    return result;
}

ESessionHandshake esession_handshake_load(ESession es, const char* e_str, ESessionMODPGroup group)
{
    BIGNUM* e = NULL;
    BIGNUM* f;
    BUF_MEM K;
    Buffer sid;
    int rc;
    ESessionHandshake result;
    EVP_MD_CTX signctx;
    char* sig;
    int   sig_len;
   

    /* Ensure state is good */
    assert(es->_state == ES_NEW);

    /* Initialize the MODP group */
    esession_set_modp_group(es, group);

    /* Initialize DH values -- dup code right now but we'll fix that
       when we can specify other primes. */
    es->_dh = DH_new();
    BN_dec2bn(&(es->_dh->p), es->_modp);
    BN_set_word(es->_dh->g, 2);


    /* Step 2.5: Generate DH key; _dh->pub_key corresponds to "f" in
       the JEP */
    DH_generate_key(es->_dh);


    /* For clarity, alias es->_dh->pub_key to "f" */
    f = es->_dh->pub_key;


    /* Translate the "e" into a useable BIGNUM */
    rc = BN_hex2bn(&e, e_str);
    if (rc == 0)
    {
        _last_error = ES_ERR_INVALID_E;
        es->_state = ES_ERROR;
        return NULL;
    }


    /* Step 2.7: Calculate K by completing the DH handshake */    
    K.length = DH_size(es->_dh);
    K.data = (unsigned char*)malloc(K.length);
    rc = DH_compute_key(K.data, e, es->_dh);
    if (rc == -1)
    {
        free(K.data);
        _last_error = ES_ERR_K_CALC_FAILED;
        es->_state = ES_ERROR;
        return NULL;
    }

    /* Step 2.8: Compute a SHA1 hash of (Bob's public key, e, f, K) */
    _compute_sid(es->_public_key, e, f, K, &sid);


    /* Setup for results */
    result = (ESessionHandshake)calloc(1, sizeof(_ESessionHandshake_st));
    result->type = 1;
    result->f = BN_bn2hex(f);
    result->public_key = strdup(es->_public_key);


    /* Step 2.9: Create a signed version of the SID hash, then base64
       encode it and store in the result*/
    sig = (char*)calloc(1, EVP_PKEY_size(es->_pkey));
    EVP_SignInit(&signctx, EVP_sha1());
    EVP_SignUpdate(&signctx, buffer_ptr(&sid), buffer_len(&sid));
    EVP_SignFinal(&signctx, sig, &sig_len, es->_pkey);
    result->sig = b64_encode(sig, sig_len);
    free(sig);

    
    /* Setup inbound (Alice -> Bob) cipher & MAC key*/
    _setup_cipher(0, es->_cipherAlgo, K, &sid, 'A', 'C',
                  &(es->_cipher_in));
    _make_key(K, 'E', &sid, es->_mac_key_in, NULL);
    es->_counter_in = 0;


    /* Setup outbound (Bob -> Alice) cipher & MAC key*/
    _setup_cipher(1, es->_cipherAlgo, K, &sid, 'B', 'D',
                  &(es->_cipher_out));    
    _make_key(K, 'F', &sid, es->_mac_key_in, NULL);
    es->_counter_out = 0;

    /* Cleanup */
    free(K.data);
    BN_free(e);
    DH_free(es->_dh);
    es->_dh = NULL;
    buffer_free(&sid);
    
    /* Move into new state */
    es->_state = ES_READY;

    return result;
}

int esession_handshake_complete(ESession es, const char* f_str,
                                const char* sig_str, const char* key_str)
{
    BIGNUM* e;
    BIGNUM* f = NULL;    
    BUF_MEM K;
    EVP_MD_CTX verifyctx;
    EVP_PKEY* bobkey;
    char* sig;
    int   sig_len;
    int   rc;
    Buffer sid;
    
    /* Ensure state is good */
    assert(es->_state == ES_HANDSHAKE);

    
    /* For clarity, alias es->_dh->pub_key to "e" */
    e = es->_dh->pub_key;


    /* Translate the "f" into a useable BIGNUM */
    rc = BN_hex2bn(&f, f_str);
    if (rc == 0)
    {
        _last_error = ES_ERR_INVALID_F;
        es->_state = ES_ERROR;
        return -1;
    }


    /* Step 2.11: Calculate K by completing the DH handshake */
    K.length = DH_size(es->_dh);
    K.data = (unsigned char*)malloc(K.length);
    rc = DH_compute_key(K.data, f, es->_dh);
    if (rc == -1)
    {
        free(K.data);
        _last_error = ES_ERR_K_CALC_FAILED;
        es->_state = ES_ERROR;
        return -1;
    }


    /* Step 2.12: Compute SID */
    _compute_sid(key_str, e, f, K, &sid);


    /* Turn the provided public key into a proper EVP_PKEY.  Note that
       we're assuming the public key is the same type as our key
       algo.. */
    bobkey = _process_public_key(es->_id, es->_keyType, key_str);
    if (bobkey == NULL)
    {
        free(K.data);
        buffer_free(&sid);
        es->_state = ES_ERROR;
        return -1;
    }

    /* Step 2.13: Check the signature against the SID */
    b64_decode(sig_str, sig, &sig_len);
    EVP_VerifyInit(&verifyctx, EVP_sha1());
    EVP_VerifyUpdate(&verifyctx, buffer_ptr(&sid), buffer_len(&sid));
    rc = EVP_VerifyFinal(&verifyctx, sig, sig_len, bobkey);
    if (rc != 1)
    {
        free(sig);
        free(K.data);
        buffer_free(&sid);
        _last_error = ES_ERR_VERIFY_SIG_FAILED;
        es->_state = ES_ERROR;
        return -1;
    }

    return 0;
}



ESessionMessage esession_encrypt(ESession es, const char* message)
{
    /* Compress message w/ zlib */
    /* Add padding -- must be multiple of cipher block size;
       last byte of padding determines how much padding there is */
    /* Calculate MAC */
    /* Encrypt */
    /* Base 64 encode message & MAC */
    return NULL;
}

ESessionMessage esession_decrypt(ESession es, const char* message, 
                                 const char* mac)
{
    return NULL;
}

void esession_free(ESession es)
{
    if (es->_dh != NULL)
    {
        DH_free(es->_dh);
        es->_dh = NULL;
    }

    if (es->_pkey != NULL)
    {
        EVP_PKEY_free(es->_pkey);
        es->_pkey = NULL;
    }

}

void esession_handshake_free(ESessionHandshake eh)
{
    if (eh->type == 0)
    {
        free(eh->e);
    }
    else
    {
        free(eh->f);
        free(eh->public_key);
        free(eh->sig);
    }
    free(eh);
}

void esession_message_free(ESessionMessage em)
{
    free((char*)em->message);
    free((char*)em->mac);
    free(em);
}

