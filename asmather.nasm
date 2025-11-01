;; AsMather: a scuffed calculator REPL written in x86_64 assembly because why not.
;;
;; Copyright (c) Eason Qin, 2025.
;;
;; This software is licensed under the MIT license. Visit the OSI website for a
;; digital copy, or view LICENSE in the root of the project directory.
;;
%include "linux.inc"

%define INPUT_MAX 1024
%define TOKENS_LEN 1536
%define STACK_MAX 128

%macro declstring 2
%1: db %2,0x0
%1%+_len: equ $ - %1
%endmacro

%macro _memset 3
    lea rdi, [rel %1]
    mov rax, %2
    mov rcx, %3
    cld
    rep stosb
%endmacro

%macro _strlen 1
    lea rdi, [rel %1]
    xor rax, rax
    mov rcx, %1%+_len
    cld
    repne scasb
    lea rsi, [rel %1]
    sub rdi, rsi
    dec rdi ; exclude null term
    mov rax, rdi ; consistency
%endmacro

; name, size, value
; mystack, byte, 0x4
%macro stack.push 3
    mov r12, [rel %1%+_height]
    mov r13, [rel %1]
    mov %2 [r13 + r12], %3
    inc r12
    mov [rel %1%+_height], r12
%endmacro

; name, size, target
; mystack, qword, rdx
%macro stack.pop 3
    mov r12, [rel %1%+_height]
    mov r13, [rel %1]
    dec r12
    mov [rel %1%+_height], r12
    mov %3, %2 [r13 + r12]
%endmacro

; name,  size
%macro stack.reset 1
    _memset %1, 0, STACK_MAX
%endmacro

; its so cursed that it breaks syntax highlighting
%macro stack.declare 2
    %1: res%+%2 STACK_MAX
    %1%+_size: equ $ - %1
    %1%+_height: resd 1
%endmacro

%define INPUT_SIZE 1024
%define INPUT_MAX 1023
%define TOKENS_SIZE 2048
%define TOKENS_MAX 2047

section .text
strlen:
    push rbp
    mov rbp, rsp
    xor rax, rax
    .loop:
        cmp byte [rdi+rax], 0
        je .loop_after
        inc rax
        jmp .loop
    .loop_after:
    pop rbp
    ret

strcmp:
    ;; rdi = str1
    ;; rsi = str2
    ; rax = isequal
    push rbp
    mov rbp, rsp
    xor rcx, rcx
    strcmp_loop:
        mov r8b, byte [rdi+rcx]
        mov r9b, byte [rsi+rcx]
        test r8b, r8b 
        je strcmp_loop_after
        test r9b, r9b
        je strcmp_loop_after

        cmp r8b, r9b
        jne strcmp_loop_after
        inc rcx
        jmp strcmp_loop

    strcmp_loop_after:
    xor rax, rax
    mov al, r8b
    sub al, r9b
    pop rbp
    ret

strncpy:
    ;; rax: char*
    ;; rdi: int dsize 
    ;; rsi: char* dest
    ;; rdx: const char* src
    push rbp
    mov rbp, rsp
    ; because while (i < dsize)
    sub rdi, 1

    ; rcx: int i
    xor rcx, rcx
    .loop: 
        ; if (i >= dsize) break;
        cmp rcx, rdi
        jge .loop_after

        ; if (src[i] != 0x0) goto _copy_byte
        cmp byte [rdx+rcx], 0
        jne .loop_copy_byte
        
        .loop_copy_null:
        mov byte [rsi+rcx], 0
        jmp .loop_end

        .loop_copy_byte:
        mov r8b, byte [rdx+rcx]
        mov byte [rsi+rcx], r8b
        
        .loop_end:
        ; i++
        inc rcx
        jmp .loop

    .loop_after:
    pop rbp
    mov rax, rsi
    ret

global main
main:
    push rbp
    mov rbp, rsp
    cld

    mov rax, SYS_write
    mov rdi, stdout
    lea rsi, [rel header]
    mov rdx, header_len
    syscall

    .mainloop:
        ; clear input buf
        _memset buf, 0, INPUT_SIZE
        ; clear tokens
        _memset tokens, 0, TOKENS_SIZE
        ; reset tokens_len
        mov dword [rel tokens_len], 0
        
        syscall3 SYS_write, stdout, prompt, prompt_len
        syscall3 SYS_read, stdin, buf, INPUT_SIZE
        
        mov rdi, buf
        call strlen
        dec rax
        cmp byte [buf + rax], 0xA
        jne .del_newline_after
        mov byte [buf + rax], 0x0
        .del_newline_after:
            
        lea rdi, [rel buf]
        lea rsi, [rel txt_quit] 
        call strcmp
        jz .done
        lea rdi, [rel buf]
        lea rsi, [rel txt_exit] 
        call strcmp
        jz .done

        jmp .mainloop

.done:
    pop rbp
    xor eax, eax
    ret

section .bss
stack.declare opstack, b
stack.declare valstack, q
tokens: resb TOKENS_LEN
tokens_len: resd 1
buf: resb INPUT_MAX

section .data
header: db "Welcome to AsMather.", 0xA
    db "Copyright (c) Eason Qin, 2025. This software is licensed under the MIT License.", 0xA
    db "Visit the OSI website to get a copy, or refer to LICENSE at the root of the", 0xA
    db "source tree.", 0xA, 0x0
header_len: equ $ - header
declstring symbols, "+-*/^()"
declstring prompt, "> "
declstring txt_quit, "quit"
declstring txt_exit, "exit"

; vim :filetype=nasm:
