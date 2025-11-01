%ifndef _COMMON_INC
%define _COMMON_INC

%define stdin 0
%define stdout 1
%define stderr 2

%define EXIT_SUCCESS 0
%define EXIT_FAILURE 1

; thanks chatjippety
%define SYS_read           0
%define SYS_write          1
%define SYS_open           2
%define SYS_close          3
%define SYS_stat           4
%define SYS_fstat          5
%define SYS_lstat          6
%define SYS_poll           7
%define SYS_lseek          8
%define SYS_mmap           9
%define SYS_munmap         11
%define SYS_brk            12
%define SYS_rt_sigaction   13
%define SYS_rt_sigprocmask 14
%define SYS_ioctl          16
%define SYS_pread64        17
%define SYS_pwrite64       18
%define SYS_readv          19
%define SYS_writev         20

%define SYS_access         21
%define SYS_pipe           22
%define SYS_select         23
%define SYS_sched_yield    24
%define SYS_mremap         25
%define SYS_msync          26
%define SYS_mincore        27
%define SYS_madvise        28

%define SYS_dup            32
%define SYS_dup2           33
%define SYS_nanosleep      35
%define SYS_getpid         39
%define SYS_socket         41
%define SYS_connect        42
%define SYS_accept         43
%define SYS_sendto         44
%define SYS_recvfrom       45

%define SYS_execve         59
%define SYS_exit           60
%define SYS_wait4          61
%define SYS_kill           62

%define SYS_uname          63
%define SYS_fcntl          72
%define SYS_fsync          74
%define SYS_fdatasync      75
%define SYS_ftruncate      77

%define SYS_getcwd         79
%define SYS_chdir          80
%define SYS_rename         82
%define SYS_mkdir          83
%define SYS_rmdir          84
%define SYS_creat          85
%define SYS_link           86
%define SYS_unlink         87

%define SYS_symlink        88
%define SYS_readlink       89
%define SYS_chmod          90
%define SYS_fchmod         91

%define SYS_openat         257
%define SYS_newfstatat     262

%define O_RDONLY    0
%define O_WRONLY    1
%define O_RDWR      2
%define O_CREAT     0x40       
%define O_EXCL      0x80
%define O_NOCTTY    0x100
%define O_TRUNC     0x200
%define O_APPEND    0x400
%define O_NONBLOCK  0x800
%define O_DSYNC     0x1000
%define O_SYNC      0x101000 
%define O_CLOEXEC   0x80000

%define PROT_READ	0x1
%define PROT_WRITE	0x2
%define PROT_EXEC	0x4	
%define PROT_NONE	0x0

%define MAP_SHARED	0x01	
%define MAP_PRIVATE	0x02

%define SEEK_SET 0x0
%define SEEK_CUR 0x1
%define SEEK_END 0x2

; =====

%define PATH_MAX 1024
%define BUF_MAX 4096
%define DEFAULT_OPENMODE 0o644

%macro syscall1 2
    mov rax, %1
    mov rdi, %2
    syscall
%endmacro

%macro syscall2 3
    mov rax, %1
    mov rdi, %2
    mov rsi, %3
    syscall
%endmacro

%macro syscall3 4
    mov rax, %1
    mov rdi, %2
    mov rsi, %3
    mov rdx, %4
    syscall
%endmacro

%macro call1 2
    mov rdi, %2
    call %1
%endmacro

%macro call2 3
    mov rdi, %2
    mov rsi, %3
    call %1
%endmacro

%macro call3 4
    mov rdi, %2
    mov rsi, %3
    mov rdx, %4
    call %1
%endmacro

%endif

; vim: filetype=nasm :
