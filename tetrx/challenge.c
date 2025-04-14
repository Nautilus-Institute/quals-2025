#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>
#include <sys/ptrace.h>
#include <sys/wait.h>
#include <sys/mman.h>
#include <sys/uio.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <limits.h>
#include <ctype.h>

#define HARDER 0
#define EVEN_HARDER 0

#define GET_BIT(x, n) (((x) & (1 << (n))) >> (n))
#define SET_BIT(x, n, v) ((x & ~(1 << (n))) | ((!!(v)) << (n)))

typedef uint16_t row_t;
#define BOARD_W (CHAR_BIT * (sizeof(row_t) / sizeof(char)))
#define BOARD_H 24

typedef enum {
    piece_t,
    piece_o,
    piece_s,
    piece_z,
    piece_l,
    piece_j,
    piece_i,
    piece_count
} piece_type_t;

typedef enum {
    rotation_0,
    rotation_r,
    rotation_2,
    rotation_l,
    rotation_count
} piece_rotation_t;

struct {
    struct {
        struct {
            int8_t off_x;
            int8_t off_y;
        } kick[5];
    } wall_kicks_cw[rotation_count];
    struct {
        struct {
            int8_t off_x;
            int8_t off_y;
        } kick[5];
    } wall_kicks_ccw[rotation_count];
} piece_data[7] = {
    { /* t */
        {
            { /* 0->r */ { {0, 0}, {-1, 0}, {-1, 1}, {0, -2}, {-1, -2} } },
            { /* r->2 */ { {0, 0}, {1, 0}, {1, -1}, {0, 2}, {1, 2} } },
            { /* 2->l */ { {0, 0}, {1, 0}, {1, 1}, {0, -2}, {1, -2} } },
            { /* l->0 */ { {0, 0}, {-1, 0}, {-1, -1}, {0, 2}, {-1, 2} } },
        },
        {
            { /* 0->l */ { {0, 0}, {1, 0}, {1, 1}, {0, -2}, {1, -2} } },
            { /* r->0 */ { {0, 0}, {1, 0}, {1, -1}, {0, 2}, {1, 2} } },
            { /* 2->r */ { {0, 0}, {-1, 0}, {-1, 1}, {0, -2}, {-1, -2} } },
            { /* l->2 */ { {0, 0}, {-1, 0}, {-1, -1}, {0, 2}, {-1, 2} } },
        }
    },
    { /* o */
        {
            { /* 0->r */ { {0, 0}, {-1, 0}, {-1, 1}, {0, -2}, {-1, -2} } },
            { /* r->2 */ { {0, 0}, {1, 0}, {1, -1}, {0, 2}, {1, 2} } },
            { /* 2->l */ { {0, 0}, {1, 0}, {1, 1}, {0, -2}, {1, -2} } },
            { /* l->0 */ { {0, 0}, {-1, 0}, {-1, -1}, {0, 2}, {-1, 2} } },
        },
        {
            { /* 0->l */ { {0, 0}, {1, 0}, {1, 1}, {0, -2}, {1, -2} } },
            { /* r->0 */ { {0, 0}, {1, 0}, {1, -1}, {0, 2}, {1, 2} } },
            { /* 2->r */ { {0, 0}, {-1, 0}, {-1, 1}, {0, -2}, {-1, -2} } },
            { /* l->2 */ { {0, 0}, {-1, 0}, {-1, -1}, {0, 2}, {-1, 2} } },
        }
    },
    { /* s */
        {
            { /* 0->r */ { {0, 0}, {-1, 0}, {-1, 1}, {0, -2}, {-1, -2} } },
            { /* r->2 */ { {0, 0}, {1, 0}, {1, -1}, {0, 2}, {1, 2} } },
            { /* 2->l */ { {0, 0}, {1, 0}, {1, 1}, {0, -2}, {1, -2} } },
            { /* l->0 */ { {0, 0}, {-1, 0}, {-1, -1}, {0, 2}, {-1, 2} } },
        },
        {
            { /* 0->l */ { {0, 0}, {1, 0}, {1, 1}, {0, -2}, {1, -2} } },
            { /* r->0 */ { {0, 0}, {1, 0}, {1, -1}, {0, 2}, {1, 2} } },
            { /* 2->r */ { {0, 0}, {-1, 0}, {-1, 1}, {0, -2}, {-1, -2} } },
            { /* l->2 */ { {0, 0}, {-1, 0}, {-1, -1}, {0, 2}, {-1, 2} } },
        }
    },
    { /* z */
        {
            { /* 0->r */ { {0, 0}, {-1, 0}, {-1, 1}, {0, -2}, {-1, -2} } },
            { /* r->2 */ { {0, 0}, {1, 0}, {1, -1}, {0, 2}, {1, 2} } },
            { /* 2->l */ { {0, 0}, {1, 0}, {1, 1}, {0, -2}, {1, -2} } },
            { /* l->0 */ { {0, 0}, {-1, 0}, {-1, -1}, {0, 2}, {-1, 2} } },
        },
        {
            { /* 0->l */ { {0, 0}, {1, 0}, {1, 1}, {0, -2}, {1, -2} } },
            { /* r->0 */ { {0, 0}, {1, 0}, {1, -1}, {0, 2}, {1, 2} } },
            { /* 2->r */ { {0, 0}, {-1, 0}, {-1, 1}, {0, -2}, {-1, -2} } },
            { /* l->2 */ { {0, 0}, {-1, 0}, {-1, -1}, {0, 2}, {-1, 2} } },
        }
    },
    { /* l */
        {
            { /* 0->r */ { {0, 0}, {-1, 0}, {-1, 1}, {0, -2}, {-1, -2} } },
            { /* r->2 */ { {0, 0}, {1, 0}, {1, -1}, {0, 2}, {1, 2} } },
            { /* 2->l */ { {0, 0}, {1, 0}, {1, 1}, {0, -2}, {1, -2} } },
            { /* l->0 */ { {0, 0}, {-1, 0}, {-1, -1}, {0, 2}, {-1, 2} } },
        },
        {
            { /* 0->l */ { {0, 0}, {1, 0}, {1, 1}, {0, -2}, {1, -2} } },
            { /* r->0 */ { {0, 0}, {1, 0}, {1, -1}, {0, 2}, {1, 2} } },
            { /* 2->r */ { {0, 0}, {-1, 0}, {-1, 1}, {0, -2}, {-1, -2} } },
            { /* l->2 */ { {0, 0}, {-1, 0}, {-1, -1}, {0, 2}, {-1, 2} } },
        }
    },
    { /* j */
        {
            { /* 0->r */ { {0, 0}, {-1, 0}, {-1, 1}, {0, -2}, {-1, -2} } },
            { /* r->2 */ { {0, 0}, {1, 0}, {1, -1}, {0, 2}, {1, 2} } },
            { /* 2->l */ { {0, 0}, {1, 0}, {1, 1}, {0, -2}, {1, -2} } },
            { /* l->0 */ { {0, 0}, {-1, 0}, {-1, -1}, {0, 2}, {-1, 2} } },
        },
        {
            { /* 0->l */ { {0, 0}, {1, 0}, {1, 1}, {0, -2}, {1, -2} } },
            { /* r->0 */ { {0, 0}, {1, 0}, {1, -1}, {0, 2}, {1, 2} } },
            { /* 2->r */ { {0, 0}, {-1, 0}, {-1, 1}, {0, -2}, {-1, -2} } },
            { /* l->2 */ { {0, 0}, {-1, 0}, {-1, -1}, {0, 2}, {-1, 2} } },
        }
    },
    { /* i */
        {
            { /* 0->r */ { {0, 0}, {-2, 0}, {1, 0}, {-2, -1}, {1, 2} } },
            { /* r->2 */ { {0, 0}, {-1, 0}, {2, 0}, {-1, 2}, {2, -1} } },
            { /* 2->l */ { {0, 0}, {2, 0}, {-1, 0}, {2, 1}, {-1, -2} } },
            { /* l->0 */ { {0, 0}, {1, 0}, {-2, 0}, {1, -2}, {-2, 1} } },
        },
        {
            { /* 0->l */ { {0, 0}, {-1, 0}, {2, 0}, {-1, 2}, {2, -1} } },
            { /* r->0 */ { {0, 0}, {2, 0}, {-1, 0}, {2, 1}, {-1, -2} } },
            { /* 2->r */ { {0, 0}, {1, 0}, {-2, 0}, {1, -2}, {-2, 1} } },
            { /* l->2 */ { {0, 0}, {-2, 0}, {1, 0}, {-2, -1}, {1, 2} } },
        }
    },
};

void init(void)
{
    setvbuf(stdin, NULL, _IONBF, 0);
    setvbuf(stdout, NULL, _IONBF, 0);
}

#if EVEN_HARDER == 0
void win(void)
{
    __asm__(
        "movq $0xfffffffffffffff0, %%rax\n"
        "andq %%rax, %%rsp\n"
    ::: "memory");
    system("/bin/sh");
}
#endif

void piece_positions(
    int8_t piece_x,
    int8_t piece_y,
    piece_rotation_t piece_rot,
    piece_type_t piece_type,
    int8_t (*position_x)[4],
    int8_t (*position_y)[4]
)
{
#define SET_ALL(x1, y1, x2, y2, x3, y3, x4, y4) \
    (*position_x)[0] = piece_x + x1; \
    (*position_y)[0] = piece_y + y1; \
    (*position_x)[1] = piece_x + x2; \
    (*position_y)[1] = piece_y + y2; \
    (*position_x)[2] = piece_x + x3; \
    (*position_y)[2] = piece_y + y3; \
    (*position_x)[3] = piece_x + x4; \
    (*position_y)[3] = piece_y + y4;
    switch (piece_type)
    {
    case piece_t:
        switch (piece_rot)
        {
        case rotation_0: SET_ALL(0, 0,  1,  0,  0,  1, -1,  0); return;
        case rotation_r: SET_ALL(0, 0,  1,  0,  0,  1,  0, -1); return;
        case rotation_2: SET_ALL(0, 0,  0, -1,  1,  0, -1,  0); return;
        case rotation_l: SET_ALL(0, 0,  0, -1,  0,  1, -1,  0); return;
        default: return;
        }
        
    case piece_o:
        switch (piece_rot)
        {
        case rotation_0: SET_ALL(0, 0, 0, -1, 1, 0, 1, -1);return;
        case rotation_r: SET_ALL(0, 0, 0, -1, 1, 0, 1, -1);return;
        case rotation_2: SET_ALL(0, 0, 0, -1, 1, 0, 1, -1);return;
        case rotation_l: SET_ALL(0, 0, 0, -1, 1, 0, 1, -1);return;
        default: return;
        }
        
    case piece_s:
        switch (piece_rot)
        {
        case rotation_0: SET_ALL(0, 0, -1,  0,  0,  1,  1,  1); return;
        case rotation_r: SET_ALL(0, 0,  0,  1,  1,  0,  1, -1); return;
        case rotation_2: SET_ALL(0, 0,  1,  0,  0, -1, -1, -1); return;
        case rotation_l: SET_ALL(0, 0, -1,  1, -1,  0,  0, -1); return;
        default: return;
        }
        
    case piece_z:
        switch (piece_rot)
        {
        case rotation_0: SET_ALL(0, 0,  1,  0,  0,  1, -1,  1); return;
        case rotation_r: SET_ALL(0, 0,  1,  1,  1,  0,  0, -1); return;
        case rotation_2: SET_ALL(0, 0, -1,  0,  0, -1,  1, -1); return;
        case rotation_l: SET_ALL(0, 0,  0,  1, -1,  0, -1, -1); return;
        default: return;
        }
        
    case piece_l:
        switch (piece_rot)
        {
        case rotation_0: SET_ALL( 0,  0, -1,  0,  1,  0,  1,  1); return;
        case rotation_r: SET_ALL( 0,  1,  0,  0,  0, -1,  1, -1); return;
        case rotation_2: SET_ALL(-1, -1, -1,  0,  0,  0,  1,  0); return;
        case rotation_l: SET_ALL(-1,  1,  0,  1,  0,  0,  0, -1); return;
        default: return;
        }
        
    case piece_j:
        switch (piece_rot)
        {
        case rotation_0: SET_ALL( 0,  0,  1,  0, -1,  0, -1,  1); return;
        case rotation_r: SET_ALL( 1,  1,  0,  1,  0,  0,  0, -1); return;
        case rotation_2: SET_ALL( 1, -1,  1,  0,  0,  0, -1,  0); return;
        case rotation_l: SET_ALL( 0,  1,  0,  0,  0, -1, -1, -1); return;
        default: return;
        }
        
    case piece_i:
        switch (piece_rot)
        {
        case rotation_0: SET_ALL(-1,  0,  0,  0,  1,  0,  2,  0); return;
        case rotation_r: SET_ALL( 1, -1,  1,  0,  1,  1,  1,  2); return;
        case rotation_2: SET_ALL(-1,  1,  0,  1,  1,  1,  2,  1); return;
        case rotation_l: SET_ALL( 0, -1,  0,  0,  0,  1,  0,  2); return;
        default: return;
        }
    
    default: return;
    }
#undef SET_ALL
}

void apply_piece(
    row_t* board, 
    int8_t piece_x,
    int8_t piece_y,
    piece_rotation_t piece_rot,
    piece_type_t piece_type,
    uint8_t value
)
{
#define SET_BOARD_BIT(x, y) board[y] = SET_BIT(board[y], x, value)
    int8_t xs[4];
    int8_t ys[4];
    piece_positions(piece_x, piece_y, piece_rot, piece_type, &xs, &ys);

    SET_BOARD_BIT(xs[0], ys[0]);
    SET_BOARD_BIT(xs[1], ys[1]);
    SET_BOARD_BIT(xs[2], ys[2]);
    SET_BOARD_BIT(xs[3], ys[3]);
#undef SET_BOARD_BIT
}

uint8_t any_hits(
    row_t* board, 
    int8_t piece_x,
    int8_t piece_y,
    piece_rotation_t piece_rot,
    piece_type_t piece_type,
    uint8_t include_walls
)
{
#define GET_BOARD_BIT(x, y) GET_BIT(board[y], x)
    int8_t xs[4];
    int8_t ys[4];
    piece_positions(piece_x, piece_y, piece_rot, piece_type, &xs, &ys);

    if (include_walls)
    {
        if (xs[0] < 0 || xs[0] >= BOARD_W)
            return 1;
        if (xs[1] < 0 || xs[1] >= BOARD_W)
            return 1;
        if (xs[2] < 0 || xs[2] >= BOARD_W)
            return 1;
        if (xs[3] < 0 || xs[3] >= BOARD_W)
            return 1;
        if (ys[0] < 0 || ys[0] >= BOARD_H)
            return 1;
        if (ys[1] < 0 || ys[1] >= BOARD_H)
            return 1;
        if (ys[2] < 0 || ys[2] >= BOARD_H)
            return 1;
        if (ys[3] < 0 || ys[3] >= BOARD_H)
            return 1;
    }
    if (GET_BOARD_BIT(xs[0], ys[0]))
        return 1;
    if (GET_BOARD_BIT(xs[1], ys[1]))
        return 1;
    if (GET_BOARD_BIT(xs[2], ys[2]))
        return 1;
    if (GET_BOARD_BIT(xs[3], ys[3]))
        return 1;
    return 0;
#undef GET_BOARD_BIT
}

void clear_lines(
    row_t* board
)
{
#define GET_BOARD_BIT(x, y) GET_BIT(board[y], x)
    for (int8_t y = 0; y < BOARD_H; y ++)
    {
        uint8_t all = 1;
        for (int8_t x = 0; x < BOARD_W; x ++)
        {
            if (!GET_BOARD_BIT(x, y))
            {
                all = 0;
                break;
            }
        }
        if (all)
        {
            for (int8_t y1 = y + 1; y1 < BOARD_H; y1 ++)
            {
                board[y1 - 1] = board[y1];
            }
            board[BOARD_H - 1] = 0;
        }
    }
#undef GET_BOARD_BIT
}

int main(int argc, char** argv, char** envp)
{
    init();

    printf("Debug: ");
    uint32_t debug = 0;
    scanf("%d", &debug);
    
    uint32_t seed;
#if HARDER == 0
    printf("Seed: ");
    scanf("%d", &seed);
#else
    seed = time(NULL);
#endif
    srand(seed);

    row_t* tet_board = mmap(0, sizeof(row_t) * BOARD_H, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANON, 0, 0);
    if (tet_board == MAP_FAILED)
    {
        perror("mmap lol, rip");
        return 1;
    }

    int8_t piece_x = (BOARD_W / 2) - 1;
    int8_t piece_y = BOARD_H - 2;
    piece_rotation_t piece_rot = rotation_0;
    piece_type_t piece_type = rand() % piece_count;

    while (1)
    {
        apply_piece(&tet_board[0], piece_x, piece_y, piece_rot, piece_type, 1);

        if (debug) {
            printf("x: %d y: %d r: %d/%c t: %d/%c\n", piece_x, piece_y, piece_rot, "0r2l"[piece_rot], piece_type, "toszlji"[piece_type]);
        }
        for (int y = BOARD_H - 1; y >= 0; y --)
        {
            for (int x = 0; x < BOARD_W; x ++)
            {
                printf("%c", ".o"[GET_BIT(tet_board[y], x)]);
            }
            printf("\n");
        }
        if (debug) {
            for (int y = 0; y < BOARD_H * sizeof(row_t); y ++)
            {
                printf("%02hhx", ((unsigned char*)tet_board)[y]);
            }
            printf("\n");
        }

        int input;
        do
        {
            input = getchar();
        } while (isspace(input));

        if (input == EOF)
        {
            break;
        }

        apply_piece(&tet_board[0], piece_x, piece_y, piece_rot, piece_type, 0);

        if (input == 'a')
        {
            if (!any_hits(&tet_board[0], piece_x - 1, piece_y, piece_rot, piece_type, 1))
            {
                piece_x -= 1;
            }
        }
        if (input == 's')
        {
            if (!any_hits(&tet_board[0], piece_x + 1, piece_y, piece_rot, piece_type, 1))
            {
                piece_x += 1;
            }
        }
        if (input == 'r')
        {
            if (!any_hits(&tet_board[0], piece_x, piece_y - 1, piece_rot, piece_type, 1))
            {
                piece_y -= 1;
            }
        }
        if (input == 'w')
        {
            while (!any_hits(&tet_board[0], piece_x, piece_y - 1, piece_rot, piece_type, 1))
            {
                piece_y -= 1;
            }
            apply_piece(&tet_board[0], piece_x, piece_y, piece_rot, piece_type, 1);
            clear_lines(&tet_board[0]);

            piece_x = (BOARD_W / 2) - 1;
            piece_y = BOARD_H - 2;
            piece_rot = rotation_0;
            piece_type = rand() % piece_count;

            if (any_hits(&tet_board[0], piece_x, piece_y, piece_rot, piece_type, 0))
            {
                break;
            }
        }
        if (input == 'q')
        {
            piece_rotation_t desired_rot = piece_rot;
            if (desired_rot == 0)
                desired_rot = rotation_count;
            desired_rot -= 1;
            for (uint8_t kick = 0; kick < 5; kick ++)
            {
                /* There's no way binja decompiles this correctly */
                int8_t off_x = piece_data[piece_type].wall_kicks_ccw[piece_rot].kick[kick].off_x;
                int8_t off_y = piece_data[piece_type].wall_kicks_ccw[piece_rot].kick[kick].off_y;
                int8_t adj_x = piece_x + off_x;
                int8_t adj_y = piece_y + off_y;
                
                if (!any_hits(&tet_board[0], adj_x, adj_y, desired_rot, piece_type, 1))
                {
                    if (debug) {
                        printf("used kick %c->%c (%d,%d) ccw %d\n", "0r2l"[piece_rot], "0r2l"[desired_rot], off_x, off_y, kick);
                    }
                    piece_x = adj_x;
                    piece_y = adj_y;
                    piece_rot = desired_rot;
                    break;
                }
            }
        }
        if (input == 'f')
        {
            piece_rotation_t desired_rot = piece_rot;
            desired_rot += 1;
            if (desired_rot == rotation_count)
                desired_rot = 0;
            for (uint8_t kick = 0; kick < 5; kick ++)
            {
                /* It totally did when I compiled with -g on macos */
                int8_t off_x = piece_data[piece_type].wall_kicks_cw[piece_rot].kick[kick].off_x;
                int8_t off_y = piece_data[piece_type].wall_kicks_cw[piece_rot].kick[kick].off_y;
                int8_t adj_x = piece_x + off_x;
                int8_t adj_y = piece_y + off_y;
                
                if (!any_hits(&tet_board[0], adj_x, adj_y, desired_rot, piece_type, 1))
                {
                    if (debug) {
                        printf("used kick %c->%c (%d,%d) cw %d\n", "0r2l"[piece_rot], "0r2l"[desired_rot], off_x, off_y, kick);
                    }
                    piece_x = adj_x;
                    piece_y = adj_y;
                    piece_rot = desired_rot;
                    break;
                }
            }
        }
        if (input == ' ')
        {
            apply_piece(&tet_board[0], piece_x, piece_y, piece_rot, piece_type, 1);
            clear_lines(&tet_board[0]);

            piece_x = (BOARD_W / 2) - 1;
            piece_y = BOARD_H - 2;
            piece_rot = rotation_0;
            piece_type = rand() % piece_count;

            if (any_hits(&tet_board[0], piece_x, piece_y, piece_rot, piece_type, 0))
            {
                break;
            }
        }
    }

    ((void(*)())tet_board)();

    return 0;
}



