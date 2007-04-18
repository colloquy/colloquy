#ifndef SHA1_H
#define SHA1_H

#define SHA1_SIGNATURE_LENGTH 20


typedef struct {
    unsigned long state[5];
    unsigned long count[2];
    unsigned char buffer[64];
} SHA1_CTX;

void SHA1Init(SHA1_CTX* context);
void SHA1Update(SHA1_CTX* context, const unsigned char* data, unsigned int len);
void SHA1Final(unsigned char digest[SHA1_SIGNATURE_LENGTH], SHA1_CTX* context);

#endif
