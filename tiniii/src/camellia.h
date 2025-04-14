#  define CAMELLIA_TABLE_BYTE_LEN 272
#  define CAMELLIA_TABLE_WORD_LEN (CAMELLIA_TABLE_BYTE_LEN / 4)
typedef unsigned int KEY_TABLE_TYPE[CAMELLIA_TABLE_WORD_LEN];

struct camellia_key_st {
    union {
        double d;               /* ensures 64-bit align */
        KEY_TABLE_TYPE rd_key;
    } u;
    int grand_rounds;
};
typedef struct camellia_key_st CAMELLIA_KEY;
