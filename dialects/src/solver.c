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
#include <pthread.h>




#define TARGHASH "\x8d\x36\x00\xaa\x6c\xb7\x52\xa7\x72\x32\x77\x84\x52\xfd\x77\xe3\xe9\x1c\x60\x7b\x02\xde\x5b\xaa\xd9\x1a\x32\x59\xe6\x52\x69\xbc\xd1\xd6\x89\x02\x03\xb1\x80\x88\xb0\xa5\x37\x68\x41\xa0\x5d\xd5\x94\x53\xc1\xe0\xbd\x0f\x38\x63\xb0\xf6\x6d\x1d\x81\xbc\x21\x6d"
uint8_t initialParam[32];
uint64_t found1 = 0;
uint64_t found2 = 0;
#define NUM_THREADS 20
void doServer();


int main(int argc, char **argv)
{

    doServer(argv);
    return 0;
}

void * brute1(void* start)
{
    EVP_MD_CTX * mdCtx = EVP_MD_CTX_new();
    uint8_t full[32];
    memcpy(full, initialParam, 32);
    uint8_t digest[64];

    uint64_t * pushPtr = (uint64_t*) full;
    *pushPtr = (uint64_t) start;
    printf("Starting at %16llx\n", *pushPtr);
    int winner =0;
    while(found1 == 0)
    {
        int found = 1;
        unsigned int hashLen = 64;
        EVP_DigestInit_ex(mdCtx, EVP_sm3(), NULL);
        EVP_DigestUpdate(mdCtx, full, 32);
        EVP_DigestFinal_ex(mdCtx,digest, &hashLen);
        for(int i = 0 ; i < 3; i++)
        {
            if(digest[i] != 0)
            {
                found=0;
                break;
            }
        }
        if(found)
        {
            winner = 1;
            break;
        }
        pushPtr[0]++;

    }
    if(winner){
        printf("WINNER\n");
        for(int i =0; i < sizeof(full); i++)
        {
            printf("%02X", full[i]);
        }
        printf("\n");
        memcpy(initialParam, full, 32);
        found1 = *pushPtr;
    }

    
}

void * brute2(void* start)
{
    uint8_t full[32];
    memcpy(full, initialParam, 32);
    uint8_t digest[128];

    uint64_t * pushPtr = (uint64_t*) full;
    int winner = 0;
    *pushPtr = (uint64_t) start;
    printf("Starting at %16llx\n", *pushPtr);
    EVP_MD_CTX * mdCtx = EVP_MD_CTX_new();
    while(found2 == 0)
    {
        unsigned int hashLen = 64;
        EVP_DigestInit_ex(mdCtx, EVP_sha512(), NULL);
        EVP_DigestUpdate(mdCtx, full, 32);
        EVP_DigestFinal_ex(mdCtx,digest, &hashLen);
        if(strcmp(digest, TARGHASH) == 0)
        {
            winner = 1;
            break;
        }
        pushPtr[0]++;
    }
    if(winner){
        printf("WINNER\n");
        for(int i =0; i < sizeof(full); i++)
        {
            printf("%02X", full[i]);
        }
        printf("\n");
        memcpy(initialParam, full, 32);
        found2 = *pushPtr;
    }

}


#define BUF_SIZ 256
void doSolve(SSL * ssl)
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

    int fd = open("/dev/urandom", O_RDONLY);
    if(read(fd, key, 8) != 8)
    {
        close(fd);
        return ;
    }
    SSL_write(ssl, &key[8], 8);
    SSL_read(ssl, key, 8);


    EVP_EncryptInit(ctx, EVP_sm4_ctr(), 
        key,
        iv);



    cmd = 2;
    EVP_EncryptUpdate(ctx, buffer, &decLen,(uint8_t*) &cmd, 4);


    rLen = SSL_write(ssl, buffer, 4);
    if(rLen != 4)
        {
            printf("Gotta read 4\n");

            exit(0);
        }

    {
        uint8_t challenge[16];
        uint8_t res[16];
        uint8_t full[32];
        uint8_t digest[64];
        memset(digest, 0, sizeof(digest));

        SSL_read(ssl, res, 16);

        unsigned char * hashRes;
        memset(challenge, 0, 16);
        memset(full, 0, sizeof(full));
        memcpy(&full[16], res, 16);
        memcpy(initialParam, full, 32);
        uint64_t param = 0;
        for(int i = 0; i < NUM_THREADS; i++)
        {
            pthread_t cThread;
            if(pthread_create(&cThread, NULL, brute1, (void*) param)){
                perror("ERROR creating thread.");
            }
            param += 0x200000000;
        }
        while(found1 == 0)
        {
            sleep(.1);
        }

        printf("Found answer = %08x\n",found1);
        memcpy(full, initialParam, 32);
        sleep(.1);
        for(int i =0; i < sizeof(full); i++)
        {
            printf("%02X", full[i]);
        }
        printf("\n");

        EVP_EncryptUpdate(ctx, buffer, &decLen, full, 16);
        SSL_write(ssl, buffer, 16);
    }
    printf("Starting Command One\n");

    cmd = 1;
    EVP_EncryptUpdate(ctx, buffer, &decLen, (uint8_t*)&cmd, 4);


    rLen = SSL_write(ssl, buffer, 4);
    if(rLen != 4)
        {
            printf("Gotta read 4\n");

            exit(0);
        }
    else
    {
        uint8_t challenge[16];
        uint8_t res[16];
        uint8_t full[32];

        unsigned char * hashRes;
        memset(full,0, 32);

        SSL_read(ssl, challenge, 16);
        memcpy(&full[16], challenge, 16);
        memcpy(initialParam, full, 32);

        uint64_t param = 0;
        printf("Starting Bruteforce\n");
        for(int i = 0; i < NUM_THREADS; i++)
        {
            pthread_t cThread;
            if(pthread_create(&cThread, NULL, brute2, (void*) param)){
                perror("ERROR creating thread.");
            }
            param += 0x200000000;
        }
        while(found2 == 0)
        {
            sleep(.1);
        }
        memcpy(full, initialParam, 32);

        printf("Found answer = %08x\n",found2 );
        for(int i =0; i < sizeof(full); i++)
        {
            printf("%02X", full[i]);
        }
        printf("\n");

        EVP_EncryptUpdate(ctx, res , &decLen, full, 16);

        SSL_write(ssl, res, 16);
        char * ans = "/flag\x00";
        EVP_EncryptUpdate(ctx,buffer, &decLen, ans, 7);
        SSL_write(ssl, buffer, 7);
        printf("Getting flag\n");

        SSL_read(ssl, buffer, BUF_SIZ);
        sleep(.2);
        printf("FLAG=%s\n", buffer);
        

    }
}




SSL_CTX *create_context()
{
    SSL_CTX *ctx;

    ctx = SSL_CTX_new(TLS_client_method());
    if (!ctx) {
        return NULL;
    }
    SSL_CTX_set_min_proto_version(ctx, TLS1_3_VERSION);
    
    return ctx;
}

static void configure_client_context(SSL_CTX *ctx)
{
    /*
     * Configure the client to abort the handshake if certificate verification
     * fails
     */
    SSL_CTX_set_verify(ctx, SSL_VERIFY_NONE, NULL);
}


void doServer(char ** argv)
{
    int sock;
    SSL_CTX *ctx;
    SSL * ssl;
    char * host = "127.0.0.1";
    int port = 4433;

    if(argv[1] == NULL || argv[2] == NULL)
    {
        printf("usage ip port ticket\n");
        exit(1);
    }

    /* Ignore broken pipe signals */
    signal(SIGPIPE, SIG_IGN);

      int sockfd = socket(AF_INET, SOCK_STREAM, 0);

      if (sockfd < 0){
        printf("socket() :%m");
        exit(1);
    }

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(atoi(argv[2]));

    if (inet_pton(AF_INET, argv[1], &(addr.sin_addr)) <= 0){
        printf("inet_pton(): %m");
        exit(0);
    }

    if (connect(sockfd, (struct sockaddr*) &addr, sizeof(addr)) < 0){
        printf("connect() :%m");
        exit(0);
    }

    printf("Connected\n");

    if(argv[3] != NULL)
    {
        char tempbuf2[256];
        printf("SENDING TICKET %s\n", argv[3]);
        uint8_t tempbuf[1024];
        sleep(.5);
        snprintf(tempbuf2, sizeof(tempbuf2), "%s\n", argv[3]);
        read(sockfd, tempbuf, sizeof(tempbuf));
        write(sockfd, tempbuf2, strlen(tempbuf2));
        sleep(2);
    }

    ctx = create_context();
    configure_client_context(ctx);
    ssl = SSL_new(ctx);
    if (!SSL_set_fd(ssl, sockfd)) {
        printf("Failed to create setfd\n");
    }
    if (SSL_connect(ssl) == 1) {

            printf("SSL connection to server successful\n\n");
    }
    doSolve(ssl);
    sleep(1);
    close(sockfd);
}