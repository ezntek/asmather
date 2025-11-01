#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define INPUT_MAX  1024
#define TOKENS_LEN 1536

// strings
static const char SYMS[] = "+-*/()";
static const char header[] = "Welcome to AsMather. <C VERSION>\n"
                             "Copyright (c) Eason Qin, 2025. This software is "
                             "licened under the MIT license.\n"
                             "Visit the OSI website to get a copy, or refer to "
                             "LICENSE at the root of the\n"
                             "source tree.\n";
static const int header_len = sizeof(header) - 1;
static const char prompt[] = "> ";
static const int prompt_len = sizeof(prompt) - 1;

#define STACK_MAX 128

#define DEFINE_STACK(T, name)                                                  \
    static T name[STACK_MAX] = {0};                                            \
    static int name##_height = 0;

#define PUSH_STACK(stack, val) (stack)[(stack##_height)++] = val
#define POP_STACK(stack)       (stack)[--(stack##_height)]
#define TOP_STACK(stack)       (stack)[(stack##_height) - 1]
#define RESET_STACK(stack)     stack##_height = 0
DEFINE_STACK(double, valstack)
DEFINE_STACK(char, opstack)

// enums are too 1971
#define OP_ADD    0
#define OP_SUB    1
#define OP_MUL    2
#define OP_DIV    3
#define OP_NEG    4
#define OP_OPAREN 5

static const int PRECS[] = {[OP_ADD] = 0, [OP_SUB] = 0, [OP_MUL] = 1,
                            [OP_DIV] = 1, [OP_NEG] = 2, [OP_OPAREN] = 3};

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

        if (strchr(SYMS, cur)) {
            tokens[tokens_begin] = cur;
            tokens[++tokens_begin] = 0;
            tokens_begin++;
            tokens_len++;
            i++;
            continue;
        }

        cur_begin = i;
        while (cur && !strchr(SYMS, cur) && !isspace(cur))
            cur = buf[++i];

        // we are now on an operator
        strncpy(&tokens[tokens_begin], &buf[cur_begin], i - cur_begin);

        cur_len = i - cur_begin;
        tokens[tokens_begin + cur_len] = 0; // delimit it
        tokens_begin += cur_len + 1;        // go after the delimiter

        tokens_len++;

        if (!cur)
            break;
    }
}

// 0: no problem
int reduce(void) {
    int op = 0;
    double left = 0, right = 0, result = 0;

    if (opstack_height == 0) {
        return 0;
    }

    op = POP_STACK(opstack);

    if (op <= OP_DIV) {
        if (valstack_height < 2) {
            printf("not enough operands in expression!\n");
            return 1;
        }

        right = POP_STACK(valstack);
        left = POP_STACK(valstack);
    }

    switch (op) {
        case OP_ADD: {
            result = left + right;
        } break;
        case OP_SUB: {
            result = left - right;
        } break;
        case OP_MUL: {
            result = left * right;
        } break;
        case OP_DIV: {
            result = left / right;
        } break;
        case OP_NEG: {
            left = POP_STACK(valstack);
            result = -1 * left;
        } break;
        case OP_OPAREN: {
            printf("unexpected opening parenthesis\n");
            return 1;
        } break;
    }

    PUSH_STACK(valstack, result);

    return 0;
}

void printstacks(void) {
    for (int i = 0; i < valstack_height; i++) {
        printf("%lf, ", valstack[i]);
    }
    puts("");
    for (int i = 0; i < opstack_height; i++) {
        printf("'%c', ", "+-*/U"[opstack[i]]);
    }
    puts("");
}

int eval(void) {
    int i = 0, curlen = 0, binary = 0, curprec = 0, prevprec = 0, bracket = 0,
        op_cur = 0, op_prev = 0;
    char *cur = tokens, *endptr = NULL;
    char ch = 0;

    while (i < tokens_len) {
        curlen = strlen(cur);
        ch = *cur;
        if (curlen == 1 && strchr(SYMS, ch)) {
            switch (ch) {
                case '+': {
                    PUSH_STACK(opstack, OP_ADD);
                } break;
                case '*': {
                    PUSH_STACK(opstack, OP_MUL);
                } break;
                case '/': {
                    PUSH_STACK(opstack, OP_DIV);
                } break;
                case '-': {
                    if (!binary) {
                        PUSH_STACK(opstack, OP_NEG);
                    } else {
                        PUSH_STACK(opstack, OP_SUB);
                    }
                } break;
                case '(': {
                    PUSH_STACK(opstack, OP_OPAREN);
                    bracket += 1;
                } break;
            }

            if (ch == ')') {
                if (!bracket) {
                    printf("found closing bracket but no opening bracket\n");
                    return 1;
                }

                while (TOP_STACK(opstack) != OP_OPAREN) {
                    if (reduce())
                        return 1;
                }
                POP_STACK(opstack);

                bracket -= 1;
                binary = 1;
                goto inc;
            }

            if (opstack_height >= 2) {
                op_cur = TOP_STACK(opstack);
                op_prev = opstack[opstack_height - 2];

                if (op_cur == OP_OPAREN || op_prev == OP_OPAREN)
                    goto done;

                curprec = PRECS[op_cur];
                prevprec = PRECS[op_prev];
                if (curprec < prevprec) {
                    POP_STACK(opstack);
                    while (opstack_height && TOP_STACK(opstack) != OP_OPAREN) {
                        if (reduce())
                            return 1;
                    }
                    PUSH_STACK(opstack, op_cur);
                }
            }

        done:
            binary = 0;
        } else if (isdigit(ch)) {
            if (binary) {
                printf("invalid syntax near \"%s\" (token #%d)\n", cur, i + 1);
                return 1;
            }

            double num = strtod(cur, &endptr);

            if (*endptr) {
                printf("number invalid: \"%s\"\n", cur);
                int diff = endptr - cur;
                diff += 18; // number invalid len
                printf("%*c\n", diff, '^');
                return 1;
            } else {
                PUSH_STACK(valstack, num);
            }

            // reduce unary
            if (opstack_height && TOP_STACK(opstack) == OP_NEG &&
                valstack_height) {
                if (reduce())
                    return 1;
            }

            binary = 1;
        } else {
            printf("unknown word: \"%s\"\n", cur);
            return 1;
        }

    inc:
        curlen++;
        cur += curlen;
        i++;
    }

    while (opstack_height) {
        if (reduce())
            return 1;
    }

    return 0;
}

int main(void) {
    int stop = 0;
    double result = 0;

    write(STDOUT_FILENO, header, header_len);

    do {
        memset(buf, 0, INPUT_MAX);
        memset(tokens, 0, TOKENS_LEN);
        RESET_STACK(opstack);
        RESET_STACK(valstack);
        tokens_len = 0;

        write(STDOUT_FILENO, prompt, prompt_len);
        read(STDIN_FILENO, buf, INPUT_MAX - 1);

        int len = strlen(buf);
        len--;
        if (buf[len] == '\n') {
            buf[len] = '\0';
        }

        if (!strcmp(buf, "quit")) {
            break;
        } else if (!strcmp(buf, "exit")) {
            break;
        }

        tokenize();
        if (eval())
            continue;

        if (valstack_height) {
            result = POP_STACK(valstack);
            printf("%lf\n", result);
        }
    } while (1);

    return 0;
}
