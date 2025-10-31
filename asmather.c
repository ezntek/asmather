#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define INPUT_MAX  1024
#define TOKENS_LEN 1536

// strings
static const char OPS[] = "+-*/";
static const char header[] = "Welcome to AsMather.\n"
                             "Copyright (c) Eason Qin, 2025. This software is "
                             "licened under the MIT license.\n"
                             "Visit the OSI website to get a copy, or refer to "
                             "LICENSE at the root of the\n"
                             "source tree.\n";
static const int header_len = sizeof(header) - 1;
static const char prompt[] = "> ";
static const int prompt_len = sizeof(prompt) - 1;

#define DEFINE_STACK(T, name)                                                  \
    static T name[] = {0};                                                     \
    static int name##_top = 0;

#define PUSH_STACK(stack, val) (stack)[++(stack##_top)] = val
#define POP_STACK(stack)       (stack)[(stack##_top)--]

DEFINE_STACK(char*, numstack)
DEFINE_STACK(char, opstack)

// enums are too 1971
#define OP_ADD 0
#define OP_SUB 1
#define OP_DIV 2
#define OP_MUL 3
#define OP_NEG 4

static char tokens[TOKENS_LEN];
static int tokens_len = 0;
char buf[INPUT_MAX];

void tokenize(void) {
    int i = 0, cur_begin = 0, tokens_begin = 0, cur_len = 0;
    char cur = 0, backup = 0;

    while (1) {
        cur = buf[i];

        while (cur && isspace(cur))
            cur = buf[++i];

        if (!cur)
            break;

        if (strchr(OPS, cur)) {
            tokens[tokens_begin] = cur;
            tokens[++tokens_begin] = 0;
            tokens_begin++;
            tokens_len++;
            i++;
            continue;
        }

        cur_begin = i;
        while (cur && !strchr(OPS, cur) && !isspace(cur))
            cur = buf[++i];

        // we are now on an operator
        backup = buf[i];
        buf[i] = 0;
        strcpy(&tokens[tokens_begin], &buf[cur_begin]);
        buf[i] = backup;

        cur_len = i - cur_begin;
        tokens[tokens_begin + cur_len] = 0; // delimit it
        tokens_begin += cur_len + 1;        // go after the delimiter

        tokens_len++;

        if (!cur)
            break;
    }
}

void eval(void) {
    int i = 0, curlen = 0, unary = 1;
    char* cur = tokens;

    while (i < tokens_len) {
        curlen = strlen(cur);
        if (curlen == 1) {
            switch (*cur) {
                case '+': {
                    PUSH_STACK(opstack, OP_ADD);
                    break;
                } break;
                case '*': {
                    PUSH_STACK(opstack, OP_ADD);
                    break;
                } break;
                case '/': {
                    PUSH_STACK(opstack, OP_ADD);
                    break;
                } break;
                case '-': {
                    if (unary) {
                        PUSH_STACK(opstack, OP_NEG);
                    } else {
                        PUSH_STACK(opstack, OP_SUB);
                    }
                } break;
            }
        }

        curlen++;
        cur += curlen;
        i++;
    }
}

int main(void) {

    int stop = 0;

    write(STDOUT_FILENO, header, header_len);

    do {
        memset(buf, 0, INPUT_MAX);
        memset(tokens, 0, TOKENS_LEN);
        tokens_len = 0;

        write(STDOUT_FILENO, prompt, prompt_len);
        read(STDIN_FILENO, buf, INPUT_MAX - 1);

        int len = strlen(buf);
        len--;
        if (buf[len] == '\n') {
            buf[len] = '\0';
        }

        if (!strcmp(buf, "quit")) {
            stop = 1;
        } else if (!strcmp(buf, "exit")) {
            stop = 1;
        }

        tokenize();
        eval();
    } while (!stop);

    return 0;
}
