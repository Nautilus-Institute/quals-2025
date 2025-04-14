#include <stdio.h>
#include <openssl/evp.h>
#include <openssl/sha.h>
#include <openssl/err.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <signal.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <sys/random.h>


#ifdef DEBUG
#define LOGI(...)  printf(__VA_ARGS__)
#else
#define LOGI(...)
#endif

#define TARGHASH "\x8d\x36\x00\xaa\x6c\xb7\x52\xa7\x72\x32\x77\x84\x52\xfd\x77\xe3\xe9\x1c\x60\x7b\x02\xde\x5b\xaa\xd9\x1a\x32\x59\xe6\x52\x69\xbc\xd1\xd6\x89\x02\x03\xb1\x80\x88\xb0\xa5\x37\x68\x41\xa0\x5d\xd5\x94\x53\xc1\xe0\xbd\x0f\x38\x63\xb0\xf6\x6d\x1d\x81\xbc\x21\x6d"
void doServer();


int main(int argc, char **argv)
{

    doServer();
    return 0;
}

#define BUF_SIZ 256
void doChallenge(SSL * ssl)
{
    EVP_CIPHER_CTX * ctx = EVP_CIPHER_CTX_new();;
    EVP_MD_CTX * mdCtx = EVP_MD_CTX_new();;

    uint8_t key[16];
    uint8_t iv[32];
    uint32_t cmd = 0;
    int canAuth = 0;
    int decLen;
    int rLen;

    memset(iv,0,32);
    memset(key,0, 16);
    uint8_t buffer[BUF_SIZ];

    if(getrandom(key, 8,0) != 8)
    {
        return ;
    }
    SSL_write(ssl, key, 8);
    SSL_read(ssl, &key[8], 8);


    EVP_EncryptInit(ctx, EVP_sm4_ctr(), 
        key,
        iv);

    EVP_DigestInit_ex(mdCtx, EVP_sm3(), NULL);

    while(1){
        rLen = SSL_read(ssl, buffer, BUF_SIZ);
        if(rLen != 4)
        {
            LOGI("Gotta read 4\n");

            exit(0);
        }
        EVP_EncryptUpdate(ctx, (uint8_t *)&cmd, &decLen, buffer, 4);

        LOGI("Got cmd %d\n",cmd);
        switch(cmd)
        {
        case 1:
            if(canAuth != 0)
            {
                uint8_t challenge[16];
                uint8_t res[16];
                uint8_t full[32];

                unsigned char * hashRes;
                getrandom( challenge, 16,0);
                SSL_write(ssl, challenge, 16);
                SSL_read(ssl, res, 16);
        
                EVP_EncryptUpdate(ctx, full , &decLen, res, 16);
                memcpy(&full[16], challenge, 16);

                hashRes = SHA512(full, 32, NULL);
                if(strncmp(hashRes, TARGHASH, 64) == 0)
                {
                    LOGI("AUTHED\n");
                    decLen = BUF_SIZ;
                    char targ[decLen];
                    SSL_read(ssl, buffer, BUF_SIZ);
                    EVP_EncryptUpdate(ctx, targ, &decLen, buffer, BUF_SIZ);
                    LOGI("Opening and reading %s\n", targ);
                    int fd = open(targ, O_RDONLY);
                    decLen = read(fd, buffer, BUF_SIZ);
                    LOGI("Sending Flag=%s\n", buffer);
                    SSL_write(ssl,buffer, decLen);
                }
                else
                {
                    LOGI("%02X %02X %02X\n", hashRes[0], hashRes[1], hashRes[2]);
                    LOGI("%02X %02X %02X\n", TARGHASH[0], TARGHASH[1], TARGHASH[2]);
                    exit(0);
                }
            }
            else
            {
                LOGI("Can't auth\n");
                exit(0);
            }
            break;
        case 2:
            {
                uint8_t challenge[16];
                uint8_t res[16];
                uint8_t full[32];
                uint8_t digest[64];
                memset(digest, 0, sizeof(digest));

                unsigned char * hashRes;
                getrandom(challenge, 16,0);
                SSL_write(ssl, challenge, 16);
                memset(res, 0, sizeof(res));
                SSL_read(ssl, res, 16);
        
                memcpy(&full[16], challenge, 16);

                EVP_EncryptUpdate(ctx, full , &decLen, res, 16);
                LOGI("DECLEN=%d\n", decLen);
                EVP_DigestUpdate(mdCtx, full, 32);
                EVP_DigestFinal_ex(mdCtx,digest, NULL);
               
                for(int i =0; i < sizeof(full); i++)
                {
                    LOGI("%02X", full[i]);
                }
                LOGI("\n");

                for(int i = 0 ; i < 3; i++)
                {
                    if(digest[i] != 0)
                    {
                        LOGI("DIGEST[%d]=%02X\n", i, digest[i]);
                        exit(2);
                    }
                }
                canAuth = 1;
            }
            break;
        default:
            exit(0);
            break;
        }
    }



}


int create_socket(int port)
{
    int s;
    struct sockaddr_in addr;
    const int enable = 1;

    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = htonl(INADDR_ANY);

    s = socket(AF_INET, SOCK_STREAM, 0);
    if (s < 0) {
        perror("Unable to create socket");
        exit(EXIT_FAILURE);
    }

    if (setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(int)) < 0){
        LOGI("setsockopt(SO_REUSEADDR) failed: %m");
    }

    if (bind(s, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("Unable to bind");
        exit(EXIT_FAILURE);
    }

    if (listen(s, 1) < 0) {
        perror("Unable to listen");
        exit(EXIT_FAILURE);
    }

    return s;
}

SSL_CTX *create_context()
{
    const SSL_METHOD *method;
    SSL_CTX *ctx;

    method = TLS_server_method();

    ctx = SSL_CTX_new(method);
    if (!ctx) {
        LOGI("Unable to create SSL context");
        ERR_print_errors_fp(stderr);
        exit(5);
    }

    return ctx;
}

void configure_context(SSL_CTX *ctx)
{
    /* Set the key and cert */
    if (SSL_CTX_use_certificate_file(ctx, "example.com.crt", SSL_FILETYPE_PEM) <= 0) {
        ERR_print_errors_fp(stderr);
        exit(6);
    }

    if (SSL_CTX_use_PrivateKey_file(ctx, "example.com.key", SSL_FILETYPE_PEM) <= 0 ) {
        ERR_print_errors_fp(stderr);
        exit(7);
    }
    SSL_CTX_set_ciphersuites(ctx, "TLS_CHACHA20_POLY1305_SHA256");
}
int daemonize(){
    int child= fork();
    if(child == 0)
    {
        pid_t nextChild= fork();
        if(nextChild == 0)
        {
            return 0;           
        }
        else{
            exit(0);
        }
    }
    else
    {
        wait4(-1, NULL, 0, NULL);
    }
    return 1;

}

void doServer()
{
    int sock;
    SSL_CTX *ctx;
    SSL *ssl;

    /* Ignore broken pipe signals */
    signal(SIGPIPE, SIG_IGN);

    ctx = create_context();

    configure_context(ctx);
    alarm(10);

    ssl = SSL_new(ctx);


    SSL_set_rfd(ssl, 0);
    SSL_set_wfd(ssl, 1);
    
    if (SSL_accept(ssl) <= 0) {
        ERR_print_errors_fp(stderr);
    } else {
        doChallenge(ssl);
        LOGI("CHAL COMPLETE\n");
    }
}