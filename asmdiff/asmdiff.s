# compile using: gcc -nostartfiles -no-pie asmdiff.s -o asmdiff

# diff: compute and output the difference between file_1 and file_2.
#   let m be the size of file_1 in lines.
#   let n be the size of file_2 in lines.

# input files should end with newline chars.
# text size limits are hard-coded, see declaration of inbuf_1.

# Caller-saved registers: %RAX, %RCX, %RDX, %RDI, %RSI, and %R8 through %R11.
# Callee saved registers: %RBX, %RSP, %RBP, and %R12 through %R15.

## Reg order for passing args
# 1. %RDI
# 2. %RSI
# 3. %RDX
# 4. %RCX
# 5. %R8
# 6. %R9

.text

.global _start

fmt_xxdx:
    .asciz "%d,%dd%d\n"
fmt_xdx:
    .asciz "%dd%d\n"
fmt_xaxx:
    .asciz "%da%d,%d\n"
fmt_xax:
    .asciz "%da%d\n"
fmt_xx:
    .asciz "%d,%d"
fmt_x:
    .asciz "%d"
c:
    .asciz "c"
eol:
    .asciz "\n"
delim:
    .asciz "---\n"

help:
    .asciz  "Usage: asmdiff FILE1 FILE2 [-Bi]...\nCompare FILE1 and FILE2 line by line.\n\n  -i, --ignore-case\n  -B, --ignore-blank-lines\n\nMMXXI DELFT\n"
endhelp:
    .equ    lenhelp, endhelp - help

# note:
## after the prologue of _start,
# rsp+8 points to the number of args;
# rsp+16 points to the first arg (prog name);
# rsp+24 points to the real first arg (name of file_1);
# rsp+32 points to the real second arg (name of file_1);
## also note: after the prologue, %rsp and %rbp are the same

_start:

    # prologue
    pushq   %rbp            # push base ptr onto stack
    movq    %rsp, %rbp      # copy stack ptr val to base ptr


    # begin setting options

    movq    8(%rbp), %rax   # load arg count
    cmpq    $3, %rax        # "asmdiff file1 file2"
    jl      err
    cmpq    $4, %rax        # "asmdiff file1 file2 [-Bi]"
    je      setoptions
    jmp     endsetignorecase

setoptions:

    movq    40(%rbp), %rax
    # now %rax holds the addr of a str with "B", "i" or both

    # 'B' = 66
    cmpb    $66, 1(%rax)
    je      setignoreblanklines
    cmpb    $66, 2(%rax)
    je      setignoreblanklines
    jmp     endsetignoreblanklines

setignoreblanklines:
    
    movq    $ignoreblanklines, %rcx
    movb    $1, (%rcx)

endsetignoreblanklines:

    # 'i' = 105
    cmpb    $105, 1(%rax)
    je      setignorecase
    cmpb    $105, 2(%rax)
    je      setignorecase
    jmp     endsetignorecase

setignorecase:

    movq    $ignorecase, %rcx
    movb    $1, (%rcx)

endsetignorecase:    

    ## end setting options


    ## begin loading phase

    # make a hash table for file_1
    movq    24(%rbp), %rdi  # filename_1, first cmd line arg
    leaq    inbuf_1, %rsi      # pass input buffer address
    leaq    hash_1, %rdx     # pass hash array address
    call    load
    pushq   %rax            # save number of lines in file_1 (m)

    # make a hash table for file_2
    movq    32(%rbp), %rdi  # filename_2, second cmd line arg
    leaq    inbuf_2, %rsi      # pass input buffer address
    leaq    hash_2, %rdx     # pass hash array address
    call    load
    pushq   %rax            # save number of lines in file_2 (n)

    ## end loading phase



    # the longest common subsequence algorithm is as follows:
    # first, compute lcs lengths for string prefixes in a matrix,
    # second, backtrace the lcs from the matrix
    #   and write in two boolean arrs (one for each file)



    ## begin dynamic programming phase

    # now that the hash arrays are computed, produce a matrix
    #   of size (m+1,n+1), where
    #       m = number of lines in file_1;
    #       n  = number of lines in file_2.

    # mtx[i][j] = length of longest common subsequence for
    #   the first i lines of file_1, and
    #   the first j lines of file_2.
    # mtx[m][n] is the length of lcs for file_1 and file_2, in full

    ## base cases:
    # forall j: mtx[0][j] = 0
    # forall i: mtx[i][0] = 0

    ## recurrence:
    # mtx[i][j] = mtx[i-1][j-1] + 1, if the i-th line of file_1
    #       (counting from one) is equal to the j-th line of file_2
    #
    # mtx[i][j] = max(mtx[i-1][j], mtx[i][j-1]), otherwise

    ## reg usage table for the dynamic programming phase:
    #   %r8  - m+1, the number of line in file_1, incr by 1
    #   %r9  - n+1, same as above, for file_2
    #   %r10 - mtx, the addr of the matrix with lcs length
    #   %r11 - i, one-based index of the current line in file_1
    #   %r12 - j, same as above, for file_2
    #   %r13 - mtx[i][j], lcs length for a table entry
    #   %r14 - hash_1, line hash array for file_1
    #   %r15 - hash_2, same as above for file_2

    # load hash arr addresses
    leaq    hash_1, %r14
    leaq    hash_2, %r15
    
    # retrieve the number of lines for the two files from stack
    movq    8(%rsp), %r8    # m
    movq    (%rsp), %r9     # n
    incq    %r8
    incq    %r9

    # reserve space on stack for mtx
    movq    $8, %rax          # scale factor of 8 bytes
    mulq    %r9
    mulq    %r8         # mul %rax (which already holds n+1) by m+1
    subq    %rax, %rsp      # reserve (m+1)*(n+1) quads on the stack
    movq    %rsp, %r10      # save mtx addr

    # note: that stack space is assumed to be filled with garbage

    # how to access matrix[i][j]:
    #   (%r10, i*m + j, 8)
    
    movq    $0, %r11        # null idx i

forloopm:

    # iterate over i = 0:m

    movq    $0, %r12        # null idx j

forloopn:

    # iterate over j = 0:n
   
    # check for the base case:
    #   lcs of any seq and an empty seq is an empty seq
    ## is (i == 0 or j == 0)?
    cmpq    $0, %r11
    jz      ifbasecase
    cmpq    $0, %r12
    jz      ifbasecase

    ## if i != 0 and j != 0, then:
   
    # check if the hashes (i.e. lines) are equal.
    ## is (hash_1[i-1] == hash_2[j-1])?
    movq    -8(%r14, %r11, 8), %rbx # -8(hash_1, i, 8)
    cmpq    %rbx, -8(%r15, %r12, 8) # -8(hash_2, j, 8)
    jne      iflinesnotequal

iflinesequal:

    # case where hashes are equal:
    ## if hash_1[i-1] == hash_2[j-1], then:
    ## mtx[i][j] = mtx[i-1][j-1] + 1

    movq    %r11, %rax      # %rax = i
    decq    %rax            # %rax = (i-1)
    mulq    %r9             # %rax = (i-1)*(n+1)
    addq    %r12, %rax      # %rax = (i-1)*(n+1) + j
    decq    %rax            # %rax = (i-1)*(n+1) + (j-1)
    movq    (%r10, %rax, 8), %rcx
    incq    %rcx
    
    movq    %rcx, %r13      ## mtx[i][j] = mtx[i-1][j-1] + 1

    jmp     endifbasecase   # skip the base case

iflinesnotequal:

    ## if hash_1[i-1] != hash_2[j-1], then:
    ## (if the lines are not equal)

    movq    %r11, %rax      # %rax = i
    decq    %rax            # %rax = (i-1)
    mulq    %r9             # %rax = (i-1)*(n+1)
    addq    %r12, %rax      # %rax = (i-1)*(n+1) + j
    movq    (%r10, %rax, 8), %rcx # mv mtx[i-1][j] to %rcx
    
    movq    %r11, %rax      # %rax = i
    mulq    %r9             # %rax = i*(n+1)
    addq    %r12, %rax      # %rax = i*(n+1) + j
    decq    %rax            # %rax = i*(n+1) + (j-1)
    movq    (%r10, %rax, 8), %rbx # mv mtx[i][j-1] to %rbx

    # max will be in %rbx 
    cmpq    %rbx, %rcx
    jg      ifg             # (%rcx > %rbx)? 
    jmp     endifg

ifg: # if greater
    movq    %rcx, %rbx      # if %rcx is greater, mv it to %rbx
endifg:

    # now max is in %rbx
    ## mtx[i][j] = max(mtx[i-1][j],mtx[i][j-1]) 
    movq    %rbx, %r13  

    jmp     endifbasecase   # skip the base case

ifbasecase:
    
    # this is the base case: one of the seq is empty

    ## if i == 0 or j == 0, then:
    ## mtx[i][j] = 0
    movq    $0, %r13

endifbasecase:

    # write mtx[i][j]
    movq    %r11, %rax      # %rax = i
    mulq    %r9             # %rax = i*(n+1)
    addq    %r12, %rax      # %rax = i*(n+1) + j
    movq    %r13, (%r10, %rax, 8) # mtx[i][j], (mtx, i*(n+1) + j, 8)

    incq    %r12            # incr idx j
    cmpq    %r12, %r9       # cmp it to n+1
    je      endforloopn     # loop range is j = 0:n
    jmp     forloopn

endforloopn:

    incq    %r11            # incr idx i
    cmpq    %r11, %r8       # cmp it to m+1
    je      endforloopm     # loop range is i = 0:m
    jmp     forloopm

endforloopm:

    # end dynamic programming phase



    # now we have a table (matrix) with lcs lengths.
    # now backtrace the lcs by taking the last entry in the matrix,
    #   and finding how it was derived from the empty seq.



    # begin backtracking phase

    ## reg usage table
    #   %r14 - m, or i (a decremented index)
    #   %r15 - n, or j (also decremented)
    #   %r11 - addr of barr_1, a binary array for indicating
    #           whether a certain line of file_1 appears in the lcs.
    #   %r12 - same as above, but for file_2

    # copy (m+1),(n+1) to %r14,%r15
    movq    %r8, %r14
    movq    %r9, %r15

    decq    %r14             # %r14 now holds m instead of m+1
    decq    %r15             # %r15 now holds n instead of n+1

    # reserve space for barr_1[m]
    movq    $8, %rax        # scale factor of 8 bytes
    mulq    %r14             # mul by m
    subq    %rax, %rsp       # reserve m quads on the stack
    movq    %rsp, %r11      # %r11 now holds barr_1

    # reserve space for barr_2[n]
    movq    $8, %rax        # scale factor of 8 bytes
    mulq    %r15             # mul by n
    subq    %rax, %rsp       # reserve n quads on the stack
    movq    %rsp, %r12      # %r12 now holds barr_2

    # %r14 and %r15 are used as decremented indices.
    # call them i and j.
    # these are initialised to m and n, both >= 0.

untilbasecasefound:

    ## if i or j is zero, jump out.
    cmp     $0, %r14
    jz      basecasefound
    cmp     $0, %r15
    jz      basecasefound

    # otherwise stay in the loop

    ## if mtx[i-1][j] == mtx[i][j]: # vert or hor mvmt
    # load mtx[i-1][j] into %rbx
    movq    %r14, %rax      # %rax = i
    decq    %rax            # %rax = i-1
    mulq    %r9             # %rax = (i-1)*(n+1)
    addq    %r15, %rax      # %rax = (i-1)*(n+1) + j
    movq    (%r10, %rax, 8), %rbx
    # load mtx[i][j] into %rcx
    movq    %r14, %rax      # %rax = i
    mulq    %r9             # %rax = i*(n+1)
    addq    %r15, %rax      # %rax = i*(n+1) + j
    movq    (%r10, %rax, 8), %rcx
    # compare the two, jump if equal
    cmp     %rbx, %rcx
    je      decri

    ## else if mtx[i][j-1] == mtx[i][j]: # vert or hor mvmt
    # load mtx[i][j-1] into %rbx
    movq    %r14, %rax      # %rax = i
    mulq    %r9             # %rax = i*(n+1)
    addq    %r15, %rax      # %rax = i*(n+1) + j
    decq    %rax            # %rax = i*(n+1) + (j-1)
    movq    (%r10, %rax, 8), %rbx
    # mtx[i][j] is already loaded in %rcx
    # compare the two, jump if equal
    cmp     %rbx, %rcx
    je      decrj

    ## else if mtx[i-1][j-1] + 1 == mtx[i][j]: # diag mvmt
    # load mtx[i-1][j-1] into %rbx
    movq    %r14, %rax      # %rax = i
    decq    %rax            # %rax = i-1
    mulq    %r9             # %rax = (i-1)*(n+1)
    addq    %r15, %rax      # %rax = (i-1)*(n+1) + j
    decq    %rax            # %rax = (i-1)*(n+1) + (j-1)
    movq    (%r10, %rax, 8), %rbx
    incq    %rbx            # %rbx = mtx[i-1][j-1] + 1
    # mtx[i][j] is already loaded in %rcx
    # compare the two, jump if equal
    cmp     %rbx, %rcx
    je      decrij

decri:

    # vertical movement across matrix:
    # corresponding lines were not equal
    movq    $0, -8(%r11, %r14, 8)  # barr_1[i-1] = 0
    decq    %r14
    jmp     enddecr 

decrj:

    # horisontal movement across matrix:
    # corresponding lines were not equal
    movq    $0, -8(%r12, %r15, 8)  # barr_2[j-1] = 0
    decq    %r15
    jmp     enddecr

decrij:

    # decrementing both indices (moving in a diagonal)
    #   means that the corresponding lines were equal.
    movq    $1, -8(%r11, %r14, 8)  # barr_1[i-1] = 1
    movq    $1, -8(%r12, %r15, 8)  # barr_2[j-1] = 1

    decq    %r14
    decq    %r15

enddecr:

    jmp     untilbasecasefound

basecasefound:

    # end backtracking phase



    # after backtracing the lcs,
    #   output differing lines.
    # remember, barr_1[i] == True means that i-th line is in lcs
    #   (counting from 0)



    # begin output phase

    # null indices i,j
    movq    $0, %r14
    movq    $0, %r15

    decq    %r8             # %r8 now holds m instead of m+1
    decq    %r9             # %r9 now holds n instead of n+1

    movq    %r8, m
    movq    %r9, n

    ## reg usage table for the output phase:
    #   %rbx - stti or sttj, starting point of outputed block range
    #   %r10 - rngi, size of the outputed block for file_1
    #   %r13 - rngj, same as above, for file_2
    #   %rcx - outbuf size
    #   %rdx - outbuf addr
    #       size of outbuf_1 is stored in its first quad.
    #       likewise for outbuf_2 and outbuf_3.
    #   %r14 - i
    #   %r15 - j
    #   %r8  - char idx in inbuf_1, call it chri
    #   %r9  - char idx in inbuf_2, call it chrj
    #   %r11 - addr of barr_1, a binary array for indicating
    #           whether a certain line of file_1 appears in the lcs.
    #   %r12 - same as above, but for file_2

    movq    $0, %r8
    movq    $0, %r9

forloopmn:


####(

    movq    %r14, %rbx      # stti = i

    # %rdx for outbuf_1 addr
    leaq    outbuf_1, %rdx
    # %rcx for outbuf_1 size
    # clear outbuf_1 by nulling its size
    movq    $0, %rcx

    # init sum of hash sums
    movq    $0, %rsi

catchuploop_1:

    # catch file_1 up to a common line

    ## if i == m, jump out
    movq    m, %rdi
    cmpq    %rdi, %r14
    je      endcatchuploop_1

    ## if barr_1[i] == 1, jump out
    cmpq    $1, (%r11, %r14, 8)
    je      endcatchuploop_1

    # add hash to the sum of hashes
    addq    hash_1(, %r14, 8), %rsi

    # copy "<" to outbuf_1
    movq    $60, 8(%rdx, %rcx, 1)   # "<", 8(outbuf_1,bufsz,1)
    # increment outbuf_1 size by one
    incq    %rcx
    # copy " " to outbuf_1
    movq    $32, 8(%rdx, %rcx, 1)   # " ", 8(outbuf_1,bufsz,1)
    # increment outbuf_1 size by one
    incq    %rcx

    # read one line:
    # read chars from inbuf_1 until a newline.
    # copy them to outbuf_1.

newlineloop_1a:

    # take a char from inbuf_1, move it into %rax
    leaq    inbuf_1, %rdi
    movq    $0, %rax
    movb   (%rdi, %r8, 1), %al  # access inbuf_1[chri]
    incq    %r8            # incr chri

    # copy that char to outbuf_1
    movq    %rax, 8(%rdx, %rcx, 1) # push
    incq    %rcx            # incr outbuf_1 ptr

    ## if the char is a newline, jump out
    cmpb    $10, %al
    je      endnewlineloop_1a

    jmp     newlineloop_1a

endnewlineloop_1a:
    
    incq    %r14            # incr i (line idx)
    
    jmp     catchuploop_1

endcatchuploop_1:

    # save outbuf_1 size
    movq    %rcx, (%rdx)

    movq    %r14, %r10
    subq    %rbx, %r10      # rngi = i - stti

    ## if sum of hash sums is null and --ignore-blank-lines
    cmpq    $0, %rsi
    jne     noignoreblanklines_1
    cmpb    $1, ignoreblanklines(, 1)
    jne     noignoreblanklines_1
    movq    $0, %r10
    
noignoreblanklines_1:

####)


####(

    movq    %r15, %rbx      # sttj = j

    # %rdx for outbuf_2 addr
    leaq    outbuf_2, %rdx
    # %rcx for outbuf_2 size
    # clear outbuf_2 by nulling its size
    movq    $0, %rcx

    # init sum of hash sums
    movq    $0, %rsi

catchuploop_2:

    # catch file_2 up to a common line

    ## if j == n, jump out
    movq    n, %rdi
    cmpq    %rdi, %r15
    je      endcatchuploop_2

    ## if barr_2[j] == 1, jump out
    cmpq    $1, (%r12, %r15, 8)
    je      endcatchuploop_2

    # add hash to the sum of hashes
    addq    hash_2(, %r15, 8), %rsi

    # copy ">" to outbuf_2
    movq    $62, 8(%rdx, %rcx, 1)   # ">", 8(outbuf_2,bufsz,1)
    # increment outbuf_2 size by one
    incq    %rcx
    # copy " " to outbuf_2
    movq    $32, 8(%rdx, %rcx, 1)   # " ", 8(outbuf_2,bufsz,1)
    # increment outbuf_2 size by one
    incq    %rcx

    # read chars from inbuf_2 until a newline.
    # copy them to outbuf_2.

newlineloop_2a:

    # take a char from inbuf_2, move it into %rax
    leaq    inbuf_2, %rdi
    movq    $0, %rax
    movb   (%rdi, %r9, 1), %al  # access inbuf_2[chrj]
    incq    %r9            # incr chrj

    # copy that char to outbuf_2
    movq    %rax, 8(%rdx, %rcx, 1) # push
    incq    %rcx            # incr outbuf_2 ptr

    ## if the char is a newline, jump out
    cmpb    $10, %al
    je      endnewlineloop_2a

    jmp     newlineloop_2a

endnewlineloop_2a:

    incq    %r15            # incr j (line idx)
    
    jmp     catchuploop_2

endcatchuploop_2:

    # save outbuf_2 size
    movq    %rcx, (%rdx)

    movq    %r15, %r13
    subq    %rbx, %r13      # rngj = j - sttj

    ## if sum of hash sums is null and --ignore-blank-lines
    cmpq    $0, %rsi
    jne     noignoreblanklines_2
    cmpb    $1, ignoreblanklines(, 1)
    jne     noignoreblanklines_2
    movq    $0, %r13
    
noignoreblanklines_2:

####)




####(

#    ## check if rngi != 0
#    cmpq    $0, %r10
#    je      no_output_1

    # for output, at least rngi or rngj has to be greater than 0
    cmpq    $0, %r10
    jne     output
    cmpq    $0, %r13
    jne     output
    jmp     no_output

output:

    ## align stack to 16 if needed

    ## if rsp % 16 == 8: rsp -= 8
    movq    $0, %rdx
    movq    %rsp, %rax
    movq    $16, %rcx
    divq    %rcx
    cmpq    $8, %rdx
    jne     endalign
    subq    $8, %rsp

endalign:
 
    pushq   %rdx
    pushq   %rcx
    pushq   %r8
    pushq   %r9
    pushq   %r10
    pushq   %r11
   
    ## choose the right block header format
    # - a stands for append
    # - d stands for delete
    # - c stands for change

    ## if rngi == 0, then rngj == 1, append mode
    cmpq    $0, %r10
    je      appendmode

    ## if rngj == 0, then rngi == 0, delete mode
    cmpq    $0, %r13
    je      deletemode

    jmp     changemode

appendmode:
    
    movq    $fmt_xaxx, %rdi        # pass the fmt str to printf

    movq    %r14, %rsi

    movq    %r15, %rdx
    subq    %r13, %rdx
    incq    %rdx

    cmpq    %rdx, %r15
    jne     xaxx
    
    movq    $fmt_xax, %rdi

xaxx:

    movq    %r15, %rcx

    # print outbuf_3 to stdout
    movq    $0, %rax        # no vec regs for printf
    call    printf
    ##cf

    # print outpuf_2 to stdout
#    movq    $1, %rax        # 1 for sys_write
#    movq    $1, %rdi        # 1 for stdout
#    movq    $outbuf_2, %rsi # content address,
#    addq    $8, %rsi        # displaced by 1 quad.
#    movq    outbuf_2(, 1), %rdx # buf size, stored in first quad
#    call    write
    movq    $outbuf_2, %rdi
    addq    $8, %rdi
    movq    outbuf_2(, 1), %rcx
    movq    $0, -1(%rdi, %rcx, 1)
    call    puts

    jmp     endmodes

deletemode:

    movq    $fmt_xxdx, %rdi

    movq    %r14, %rsi
    subq    %r10, %rsi
    incq    %rsi

    movq    %r14, %rdx

    cmpq    %rsi, %rdx
    jne     xxdx

    movq    $fmt_xdx, %rdi
    movq    %r15, %rdx

xxdx:

    movq    %r15, %rcx

    # print outbuf_3 to stdout
    movq    $0, %rax        # no vec regs for printf
    call    printf
    ##cf

#    # print outbuf_1 to stdout
#    movq    $1, %rax        # 1 for sys_write
#    movq    $1, %rdi        # 1 for stdout
#    movq    $outbuf_1, %rsi # content address,
#    addq    $8, %rsi        # displaced by 1 quad.
#    movq    outbuf_1(, 1), %rdx # buf size, stored in first quad
#    call    write

    movq    $outbuf_1, %rdi
    addq    $8, %rdi
    movq    outbuf_1(, 1), %rcx
    movq    $0, -1(%rdi, %rcx, 1)
    call    puts

    jmp     endmodes

changemode:
    
    ## print first part of the block header
    cmpq    $1, %r10
    je      xc
    jne     xxc

xc:
    
    movq    $fmt_x, %rdi
    movq    %r14, %rsi

    pushq   %r10
    movq    $0, %rax        # no vec regs for printf
    call    printf
    ##cf
    popq   %r10

    jmp     endxxc

xxc:
    
    movq    $fmt_xx, %rdi

    movq    %r14, %rsi
    subq    %r10, %rsi
    incq    %rsi

    movq    %r14, %rdx

    pushq   %r10
    movq    $0, %rax        # no vec regs for printf
    call    printf
    ##cf
    popq    %r10

endxxc:

    pushq   %r10
    movq    $c, %rdi
    movq    $0, %rax        # no vec regs for printf
    call    printf
    ##cf
    popq   %r10


    ## print second part of the block header
    cmpq    $1, %r13
    je      cx
    jne     cxx

cx:
    
    movq    $fmt_x, %rdi
    movq    %r15, %rsi

    movq    $0, %rax        # no vec regs for printf
    call    printf
    ##cf

    jmp     endcxx

cxx:
    
    movq    $fmt_xx, %rdi

    movq    %r15, %rsi
    subq    %r13, %rsi
    incq    %rsi

    movq    %r15, %rdx

    movq    $0, %rax        # no vec regs for printf
    call    printf
    ##cf

endcxx:

    movq    $eol, %rdi
    movq    $0, %rax        # no vec regs for printf
    call    printf
    ##cf

#    # print outbuf_1 to stdout
#    movq    $1, %rax        # 1 for sys_write
#    movq    $1, %rdi        # 1 for stdout
#    movq    $outbuf_1, %rsi # content address,
#    addq    $8, %rsi        # displaced by 1 quad.
#    movq    outbuf_1(, 1), %rdx # buf size, stored in first quad
#    call    write

    movq    $outbuf_1, %rdi
    addq    $8, %rdi
    movq    outbuf_1(, 1), %rcx
    movq    $0, -1(%rdi, %rcx, 1)
    call    puts

    movq    $delim, %rdi
    movq    $0, %rax        # no vec regs for printf
    call    printf
    ##cf

    # print outpuf_2 to stdout
#    movq    $1, %rax        # 1 for sys_write
#    movq    $1, %rdi        # 1 for stdout
#    movq    $outbuf_2, %rsi # content address,
#    addq    $8, %rsi        # displaced by 1 quad.
#    movq    outbuf_2(, 1), %rdx # buf size, stored in first quad
#    call    write

    movq    $outbuf_2, %rdi
    addq    $8, %rdi
    movq    outbuf_2(, 1), %rcx
    movq    $0, -1(%rdi, %rcx, 1)
    call    puts

    jmp     endmodes

endmodes:

    popq    %r11
    popq    %r10
    popq    %r9
    popq    %r8
    popq    %rcx
    popq    %rdx

no_output:
    
####)

    ## if i != m, take a common step in file_1
    movq    m, %rdi
    cmpq    %rdi, %r14
#    cmpq    $m, %r14
    je      endnewlineloop_1b # if ==, skip incrementation

    incq    %r14

newlineloop_1b:

    # take a char from inbuf_1, move it into %rax
    leaq    inbuf_1, %rdi
    movq    $0, %rax
    movb   (%rdi, %r8, 1), %al  # access inbuf_1[chri]
    incq    %r8            # incr chri

    ## if the char is a newline, jump out
    cmpb    $10, %al
    je      endnewlineloop_1b

    jmp     newlineloop_1b

endnewlineloop_1b:


####(

    # same as above for file_2
    ## if j != n, take a common step
    movq    n, %rdi
    cmpq    %rdi, %r15
    #cmpq    $n, %r15
    je      endnewlineloop_2b # if ==, skip incrementation

    incq    %r15

newlineloop_2b:

    # take a char from inbuf_2, move it into %rax
    leaq    inbuf_2, %rdi
    movq    $0, %rax
    movb   (%rdi, %r9, 1), %al  # access inbuf_2[chrj]
    incq    %r9            # incr chrj

    ## if the char is a newline, jump out
    cmpb    $10, %al
    je      endnewlineloop_2b

    jmp     newlineloop_2b

endnewlineloop_2b:

####)


    ## if i == m and j == n, jump out, end program.
    ## so if i != m or j != n, stay in.
    movq    m, %rdi
    cmpq     %rdi, %r14
    jne     forloopmn

    movq    n, %rdi
    cmpq     %rdi, %r15
    jne     forloopmn

endforloopmn:

    # epilogue
    movq    %rbp, %rsp      # clear local variables from stack
    popq    %rbp            # restore prev base ptr loc
    # exit normally
#    movq    $60, %rax       # 60 for sys_exit
    movq    $0, %rdi        # OK
#    syscall
    call    exit

err:

    # print to stderr
    movq    $1, %rax        # 1 for sys_write
    movq    $2, %rdi        # 2 for stderr
    movq    $help, %rsi    # content
    movq    $lenhelp, %rdx   # size
    call    write

    # epilogue
    movq    %rbp, %rsp      # clear local variables from stack
    popq    %rbp            # restore prev base ptr loc
    # exit non-normally
#    movq    $60, %rax       # 60 for sys_exit
    movq    $1, %rdi        # NOT OK
#    syscall
    call exit




## subroutine pow
# description:
#   implements raising a non-negative integer base
#   to a non-neg integer exponent.

## arguments:
#   %rdi - base;
#   %rsi - exponent;

## return value:
#   %rax - base to the power of exponent;

pow: 
    # prologue
    pushq   %rbp            # push the base ptr onto stack
    movq    %rsp, %rbp      # copy stack ptr val to base ptr

    movq    $1, %rax        # init %rax to 1, as forall x (x^0 = 1)

    # for iteration counter use %rcx.
    movq    $0, %rcx        # init counter

powloop:                       # while counter < exp

    cmpq    %rcx, %rsi      # compare counter to exp
    jle      endpowloop            # if counter >= exp, break

    mulq    %rdi            # multiply (%rax) by base

    incq    %rcx            # increment counter
    jmp     powloop            # repeat loop

endpowloop:

    # epilogue
    movq    %rbp, %rsp      # clear local variables from stack
    popq    %rbp            # restore prev base ptr loc

    ret




## subroutine load
# description:
#   given a filename and a buffer, read the contents of the file
#   into the buffer, and compute a hash for every line, store
#   the resulting array in another buffer, called hash.

## arguments:
#   %rdi - filename;
#   %rsi - address of buffer for file contents;
#   %rdx - address of buffer for hash array;

## return value:
#   %rax - the number of lines in file, a positive integer;

load:

    # prologue
    pushq   %rbp            # push base ptr onto stack
    movq    %rsp, %rbp      # copy stack ptr val to base ptr

    # save the callee-saved regs onto the stack
    pushq   %rbx
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15

    # move values from arg regs to some other regs
    movq    %rsi, %r15
    movq    %rdx, %r14

    # open file
    movq    $2, %rax        # pass 2 for sys_open
    movq    $0, %rdx        # pass 0 for read-only access
    movq    $0000, %rsi     # pass 0 for permissions
    syscall

    # read from file into buf
    movq    %rax, %rdi      # file descr from prev syscall (it's 3)
    movq    $0, %rax        # pass 0 for sys_read
    movq    %r15, %rsi      # pass buffer address
    movq    $inbufsz, %rdx    # pass buffer size
    syscall
    movq    %rax, %r11      # text size in bytes (or neg err cd)

    cmpq    $0, %r11        # %r11 < 0 ?
    jl      err             # size cannot less than 0

    # we shall do an array of line hashes

    ## reg usage table for load:
    #   %rbx - counts index of the current char in the whole file
    #   %r12 - counts index of the current char in the current line
    #   %r13 - holds the computed hash-sum for a line
    #   %r10 - counts index of the current line in the current file
    #           (this quantity shall be returned by subroutine load)
    movq    $0, %rbx
    movq    $0, %r12
    movq    $0, %r13
    movq    $0, %r10
    #   %r9  - holds the current char
    #   %r11 - holds the size of the file in b in bytes (chars)

    #   %rdi - filename;
    #   %r15 - address of buffer for file contents;
    #   %r14 - address of buffer for hash array;

    # magic holds a prime number for hashes
    movq    $magic, %rdi    # pass base to pow

    # here i increment by one to fix a mysterious off-by-one error
    incq    %r11

loadloop:
    # iterate over chars of the file
    #   while computing a hash for each line in the file.

    # decr file byte count until it is null, then jump out
    decq    %r11            # decr txt sz until nothing left
    cmp     $0, %r11        
    jz      endloadloop        # if txt sz is null, jump out

    # load current character
    movq    $0, %r9
    movb    (%r15, %rbx, 1), %r9b
    # is current char the end of the line?
    cmpb    $10, %r9b  # 10 for LF, '\n'
    je      loadif

    # current char is not eol.
    # compute the addend term for the hashsum,
    # which would be (char * magic^idx),
    # where idx is the char idx in a line.

    ## if --ignore-case option is set,
    # and the char is lowercase, make it uppercase
    cmpb    $1, ignorecase(, 1)
    jne     noignorecase
    cmpb    $97, %r9b        # 97 = 'a'
    jl      noignorecase
    cmpb    $122, %r9b       # 122 = 'z'
    jg      noignorecase

doignorecase:
    # convert char to uppercase
    subq    $32, %r9
noignorecase:

    movq    %r12, %rsi      # pass exp, which is eq to idx
    call    pow
    mulq    %r9 # multiply result by char

    # add that term to the hashsum
    addq    %rax, %r13

    incq    %r12            # incr char idx in a line

    jmp endloadif

loadif:

    # current char is an eol
    
    # write the hashsum to memory
    movq    %r13, (%r14, %r10, 8) # hashsum, (arr addr, line idx, 8)
    incq    %r10            # incr line idx

    # null the hashsum and char idx in a line
    movq    $0, %r13
    movq    $0, %r12


endloadif:

    incq    %rbx            # incr char idx in text

    jmp     loadloop           # continue

endloadloop:

    movq   %r10, %rax       # return the number of lines in file

    # pop the caller-saved regs back from the stack
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rbx

    # epilogue
    movq    %rbp, %rsp      # clear local variables from stack
    popq    %rbp            # restore prev base ptr loc

    ret

.equ    magic, 6700417
.equ    inbufsz, 32768

.data
    ignoreblanklines:   .skip 1
    ignorecase:         .skip 1

.bss
    inbuf_1:     .skip inbufsz
    inbuf_2:     .skip inbufsz 
    outbuf_1:    .skip inbufsz  
    outbuf_2:    .skip inbufsz 
    hash_1:      .skip inbufsz  
    hash_2:      .skip inbufsz 
    m:           .skip 8
    n:           .skip 8


# PS: what went wrong at first
# - wrong order of subtraction when computing string length
# - not taking into account sys_call overwriting caller-saved regs
# - forgetting about epilogue & prologue
# - using rsp instead of rbp for accessing arguments
# - leaving in specific labels (e.g inbuf_1) when refactoring
# - forgetting about the scale factor of 8 when reserving space
# - mistaking hexadecimal for decimal
# - not copying properly
# - cmpq instead of cmpb

# what's it like doing this?
# - it's like being hit over the head with smth heavy, but slowly.
# - like computing digits of pi, or sqrt 2 by hand,
#       smth you know can be done w a calcucalor in multiple secs,
#       but at the same time you know people really did it
#       in more ancient ages.
# - like drowning.
# but it's fun, you know.

