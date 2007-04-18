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
// $Id: esession.h,v 1.1 2004/07/19 03:49:04 jtownsend Exp $
//============================================================================

#ifndef ESESSION_H_INCLUDE
#define ESESSION_H_INCLUDE

#include <openssl/ssl.h>
#include <zlib.h>

typedef enum
{
    ES_ERR_INVALID_E,
    ES_ERR_INVALID_F,
    ES_ERR_K_CALC_FAILED,
    ES_ERR_RSA_KEY_TOO_SMALL,
    ES_ERR_VERIFY_SIG_FAILED,
    ES_ERR_PUBLIC_KEY_NOT_ACCEPTED,
    ES_ERR_PUBLIC_KEY_CHANGED,
    ES_ERR_INVALID_PERSONAL_KEY,
    ES_ERR_COMPRESS_FAILED
} ESessionError;

typedef enum
{
    ES_MODP_5,
    ES_MODP_14,
    ES_MODP_15,
    ES_MODP_16,
    ES_MODP_17,
    ES_MODP_18
} ESessionMODPGroup;

typedef enum
{
    ES_NEW, 
    ES_HANDSHAKE, 
    ES_READY, 
    ES_ERROR
} ESessionState;

typedef enum
{
    ES_KEY_DSA,
    ES_KEY_RSA
} ESessionKeyType;

typedef enum
{
    ES_RESULT_OK,
    ES_RESULT_ERROR
} ESessionCBResult;

typedef const char* (*ESessionGetPassCallback)(const char* privatekey, void* arg);

typedef int (*ESessionChangedKeyCallback)(ESessionKeyType keytype, const char* id,
                                          const char* old_fingerprint, 
                                          const char* new_fingerprint,
                                          void* arg);

typedef int (*ESessionNewKeyCallback)(ESessionKeyType keytype, const char* id,
                                      const char* key, const char* fingerprint, void* arg);

typedef enum
{
    ES_CIPHER_3DES_CBC,
    ES_CIPHER_BLOWFISH_CBC
} ESessionCipherAlgo;

typedef enum
{
    ES_MAC_HMAC_SHA1,
    ES_MAC_HMAC_SHA1_96
} ESessionMACAlgo;

typedef struct
{
    DH*         _dh;
    EVP_PKEY*   _pkey;
    const char* _id;
    const char* _modp;

    /* Base64 encoded public key */
    unsigned char* _public_key;

    /* Inbound/decryption */
    EVP_CIPHER_CTX _cipher_in;
    unsigned char  _mac_key_in[20]; /* Always SHA1 */
    unsigned int   _counter_in;
    z_streamp      _zlib_decompress;

    /* Outbound/encryption */
    EVP_CIPHER_CTX _cipher_out;
    unsigned char  _mac_key_out[20]; /* Always SHA1 */
    unsigned int   _counter_out;
    z_streamp      _zlib_compress;

    /* Algorithm and key selectors */
    ESessionKeyType    _keyType;
    ESessionCipherAlgo _cipherAlgo;
    ESessionMACAlgo    _macAlgo;

    /* ESession state */
    ESessionState _state;

}  _ESession_st, *ESession;

typedef struct
{
    int type;
    union
    {
        char* e;
    };
    union
    {
        char* f;
        char* sig;
        char* public_key;
    };
}  _ESessionHandshake_st, *ESessionHandshake;

typedef struct
{
    const char* message;
    const char* mac;
} *ESessionMessage;

typedef struct
{
    ESessionKeyType type;
    char* public_key;
    char* private_key;
} _ESessionKeyPair_st, *ESessionKeyPair;

/* 
 * 
 * Global ESession functions 
 *
 */

int es_get_last_error();

const char* es_add_personal_key(const char* private_key);

const char* es_add_public_key(const char* id, ESessionKeyType keytype, 
                              const char* public_key);

void es_set_new_key_cb(ESessionNewKeyCallback* cb, void* arg);

void es_set_get_pass_cb(ESessionGetPassCallback* cb, void* arg);

void es_set_changed_key_cb(ESessionChangedKeyCallback* cb, void* arg);

ESessionKeyPair es_generate_keypair(ESessionKeyType keytype, int bits,
                                    const char* privatepass);

void es_keypair_free(ESessionKeyPair ekp);

/* 
 * 
 * ESession instance functions
 *
 */
ESession esession_new(const char* id);

void esession_set_modp_group(ESession es, ESessionMODPGroup group);

void esession_set_key_type(ESession es, ESessionKeyType keytpe);

void esession_set_cipher_algo(ESession es, ESessionCipherAlgo eca);

void esession_set_mac_algo(ESession es, ESessionMACAlgo ema);

ESessionHandshake esession_handshake_start(ESession es);

ESessionHandshake esession_handshake_load(ESession es, const char* e_str, 
                                          ESessionMODPGroup group);

int esession_handshake_complete(ESession es, const char* f_str,
                                const char* sig_str, const char* key_str);

ESessionMessage esession_encrypt(ESession es, const char* message);

ESessionMessage esession_decrypt(ESession es, const char* message, const char* mac);

void esession_set_signing_key(ESession es, const char* fingerprint);

void esession_free(ESession es);

void esession_handshake_free(ESessionHandshake eh);

void esession_message_free(ESessionMessage em);




#endif


