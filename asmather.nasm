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

%macro clearbuf 2
    lea rdi, [rel %1]
    xor sil, sil
    mov rdx, %2
    call memset
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
    clearbuf %1, 0, STACK_MAX
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
; === utility functions ===
memset:
    ; rdi: buf
    ; rsi: ch
    ; rdx: count
    push rbp
    mov rbp, rsp
    .loop:
        test rdx, rdx
        jz .done
        mov byte [rdi], sil 
        inc rdi
        dec rdx
        jmp .loop
    .done:
    pop rbp
    ret

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

strchr:
    ; rdi: const char* s
    ; sil: char ch
    push rbp
    mov rbp, rsp
    xor r8, r8
    mov rax, rdi
    .loop:
        mov dl, byte [rax]
        test dl, dl
        jz .end
        cmp dl, sil
        je .leave
        inc rax
        jmp .loop
    
    .end:
    xor rax, rax
    .leave:
    pop rbp
    ret

isspace:
    ; al: char ch
    push rbp
    mov rbp, rsp
    mov sil, al
    lea rdi, [rel isspace_spaces]
    call strchr
    test rax, rax
    setz al
    movzx rax, al
    pop rbp
    ret

; === program functions ===
tokenize:
    push rbp
    mov rbp, rsp
    ; === OFFSET TABLE ===
    ; -16: int i
    ; -20: int cur_begin
    ; -24: int tokens_begin
    ; -28: int cur_len
    ; -29: char cur
    sub rsp, 32
   
    ; clear space
    lea rdi, [rbp - 32]
    call3 memset, rdi, 0, 20
    
    .loop:
        ; buf: rdi
        ; cur: rsi
        lea rdi, [rel buf]
        add edi, dword [rbp - 16]
        mov sil, byte [rdi]
        mov byte [rbp - 29], sil

        ; skip whitespaces
        .clean_ws_loop:
            ; check if cur == 0
            mov dil, byte [rbp - 29] 
            test dil, dil
            jz .clean_ws_loop_after
            ; check if isspace(cur)
            call1 isspace, rsi
            test rax, rax
            jz .clean_ws_loop_after
            ; loop body
            inc dword [rbp - 16] ; buf[++i]
            lea rdi, [rel buf]
            add edi, dword [rbp - 16]
            mov sil, byte [rdi] ; cur = buf[++i]
            mov byte [rbp - 29], sil
            jmp .clean_ws_loop
        .clean_ws_loop_after:
        
        ; quit if at nullterm
        mov sil, byte [rbp - 29]
        test sil, sil
        jz .done

        ; check if it's a symbol
        lea rdi, [rel symbols]
        ; sil contains our char already
        call strchr
        jz .handle_symbol_after
        ; rdi: tokens
        ; rsi: tokens_begin
        ; rdx: cur
        ; tokens[tokens_begin] = cur
        lea rdi, [rel tokens]
        mov rsi, [rbp - 24]
        add rdi, rsi
        mov dl, byte [rbp - 29] ; fetch cur into sil
        mov byte [rdi], dl
        inc rsi
        inc rdi ; just increment the pointer too
        mov byte [rdi], 0 ; null term
        inc rsi ; tokens_begin++
        inc dword [rel tokens_len]
        inc dword [rbp - 16]
        jmp .loop

        .handle_symbol_after:
        ; save cur_begin
        mov edi, dword [rbp - 16]
        mov dword [rbp - 20], edi
        ; get the word
        .get_word_loop:
            mov dil, byte [rbp - 29]
            test dil, dil
            jz .get_word_loop_after
            lea rdi, [rel symbols]
            mov sil, byte [rbp - 29]
            call strchr
            ; jump if cur is a symbol
            jnz .get_word_loop_after
            mov dil, byte [rbp - 29]
            call isspace
            ; jump if isspace(cur)
            jnz .get_word_loop_after
            inc dword [rbp - 16] ; buf[++i]
            lea rdi, [rel buf]
            add edi, dword [rbp - 16]
            mov sil, byte [rdi] ; cur = buf[++i]
            mov byte [rbp - 29], sil
        .get_word_loop_after:

        ; we are now on an operator
        ; rdi: &tokens[tokens_begin]
        lea rdi, [rel tokens]
        xor r8, r8
        mov r8d, dword [rbp - 24]
        add rdi, r8
        ; rsi: &buf[cur_begin]
        lea rsi, [rel buf]
        mov r8d, dword [rbp - 20]
        add rsi, r8
        ; rdx: i - cur_begin
        xor edx, edx
        mov edx, dword [rbp - 16]
        sub rdx, r8
        ; copy the token
        call strncpy

        ; cur_len = i - cur_begin
        mov edx, dword [rbp - 16]
        sub rdx, r8
        mov dword [rbp - 28], edx

        ; delimit the current token
        lea rdi, [rel tokens]
        xor r8, r8
        mov r8d, dword [rbp - 24]
        add rdi, r8
        mov r8d, dword [rbp - 28] ;cur_len
        add rdi, r8 ; tokens[tokens_begin + cur_len]
        mov byte [rdi], ','

        ; begin the next token after the delim
        inc r8d
        mov dword [rbp - 24], r8d
        ; inc token
        inc dword [rel tokens_len]

        mov dil, byte [rbp - 29]
        test dil, dil
        jz .done

        ; done!
        jmp .loop

    .done:
    xor rax, rax ; just in case
    add rsp, 32
    pop rbp
    ret

; 1 on failure, 0 on success
reduce:
    push rbp
    mov rbp, rsp

    pop rbp
    ret

; 1 on failure, 0 on success
eval:
    push rbp
    mov rbp, rsp

    pop rbp
    ret

extern puts

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
        clearbuf buf, INPUT_SIZE
        ; clear tokens
        clearbuf tokens, TOKENS_SIZE
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

        call tokenize
        lea rdi, [rel tokens]
        call puts

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
isspace_spaces: db 0x20, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0

; vim :filetype=nasm:
