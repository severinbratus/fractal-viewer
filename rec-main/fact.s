.text
ansfmtp:   .asciz "%ld! = "
ansfmt:    .asciz "%ld\n"

.global main

main:
    # prologue of main
    pushq   %rbp            # push the base ptr onto stack
    movq    %rsp, %rbp      # copy stack ptr value to base ptr

    # check for base case
    cmpq    $0, %rdi
    je      factbase
    jmp     factnotbase

factbase:
    # return 1
    movq    $1, %rax
    movq    $0, %rbx        # value of n is 0 #
    jmp     factend

factnotbase:
    # recursive call for fact(n-1)
    # n is in %rdi at this pt
    pushq   %rdi            # push n for later on the stack
    decq    %rdi            # n-1 is the arg for rec call
    call    main
    
    # now, %rax has fact(n-1)
    popq   %rbx             # pop n back from the stack
    mulq    %rbx            # multiply n by fact(n-1)

factend:
    # save %rax for later #
    pushq   %rax

    movq    $ansfmtp, %rdi  # load the string address to printf
    movq    %rbx, %rsi      # load the answer as the second arg
    movq    $0, %rax        # no vec regs for printf
    call    printf          # print prompt

    # print the answer
    movq    $ansfmt, %rdi   # load the string address to printf
    movq    (%rsp), %rsi    # load the answer as the second arg
    movq    $0, %rax        # no vec regs for printf
    call    printf          # print prompt

    # restore value of %rax #
    popq    %rax 

    movq    $0, %rdi

    # epilogue of main
    movq    %rbp, %rsp      # clear local variables from stack
    popq    %rbp            # restore prev base ptr location
 
    # return instead of exiting #
    ret

/*
# Spec of fact
int fact(int n) {
    if n == 0
        return 1
    else return fact(n-1) * n
}
*/
