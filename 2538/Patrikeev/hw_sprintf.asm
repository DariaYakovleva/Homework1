global hw_sprintf

extern printf

%define set_flag(x)  or ebx, x
%define test_flag(x) test ebx, x
%assign plus_flag    1 << 1 ;; '+' specified
%assign minus_flag   1 << 2 ;; '-' specified
%assign zero_flag    1 << 3 ;; '0' specified
%assign space_flag   1 << 4 ;; ' ' specified
%assign long_flag    1 << 5 ;; 'll' specified
%assign unsign_flag  1 << 6 ;; 'u' specified
%assign neg_flag     1 << 8 ;; current printing number is negative 

section .bss
next_ptr:   resq     1      ;;next_ptr is an address of next number to be printed

section .text

;;the main function of the party
;;void hw_sprintf(char *out, char const *format, ...);
hw_sprintf:
    push    ebp         ;;save caller's stack frame
    mov     ebp, esp    ;;establish new stack frame

    push    ebx         ;;save callee-saved registers
    push    edi
    push    esi
    
    mov     edi, [ebp + 8]       ;;1-st param (*out)
    mov     esi, [ebp + 12]      ;;2-d parameter (*format)
    
    lea     eax, [ebp + 16]
    mov     [next_ptr], eax     ;;next_ptr now points to 1-st number
        
    xor     eax, eax        ;;clear room for chars
.read_until_eol:
    xor     ecx, ecx        ;;ecx holds chars length (and number of pushed elements)

    mov     byte al, [esi]  ;;load next char
    inc     esi             ;;move (*format) pointer
    push    eax             ;;push char to be printed in future if error occurs
    inc     ecx             ;;one more char...
    cmp     byte al, 0      ;;if EOL, then print '\0' to (*out) and exit
    je      .print_pushed_chars
    
    cmp     byte al, '%'    ;;check if start of format string
    jne     .print_pushed_chars ;;if not, then just print this char

;;this label reads format string and sets flags:
    xor     ebx, ebx        ;;ebx holds encountered flags 
.read_format_chars:

;;loop while specifiers are encountered:
.loop_specifiers:
    mov     byte al, [esi]  ;;load next char 
    inc     esi             ;;move (*format) pointer
    push    eax             ;;push char to be printed in future (if incorrect occurs)
    inc     ecx             ;;one more char to be printed
    cmp     byte al, 0      
    je      .print_pushed_chars ;;if EOL, then print all already pushed chars and exit

;;check flags and set those one which have been encountered:
    cmp     byte al, '0'
    je      set_zero_flag    ;;set zero_flag and jump to .loop_specifiers
    
    cmp     byte al, '-'
    je      set_minus_flag   ;;set minus_flag and jump to .loop_specifiers

    cmp     byte al, '+'
    je      set_plus_flag    ;;set plus_flag and jump to .loop_specifiers 

    cmp     byte al, ' '
    je      set_space_flag   ;;set space_flag and jump to .loop_specifiers
.end_loop_specifiers:

;;checks if digits sequence ("width") and parses it
.parse_width:
    xor     edx, edx        ;;edx holds parsed "width" 
.parse_width_loop:
    
    cmp     byte al, '0'
    jnge    .width_checked
    cmp     byte al, '9'
    jnle    .width_checked

    sub     eax, '0'        ;;EAX == current digit
    lea     edx, [edx+4*edx];;edx *= 5
    shl     edx, 1          ;;edx *= 2
    add     edx, eax        ;;edx += digit

    mov     byte al, [esi]  ;;load next char
    inc     esi             ;;move (*format) pointer to next char
    push    eax             ;;push char to be printed if error occurs
    inc     ecx             ;;one more char...
    cmp     al, 0           ;;if EOL(incorrect format sequence) then just print all pushed chars
    je      .print_pushed_chars

    jmp     .parse_width_loop 

.width_checked:

;;check if 'll' specifier
    cmp     byte al, 'l'
    jne     .long_flag_checked  

    ;;it may be 'll' specifier, so check if next char is also 'l'
    mov     byte al, [esi]  ;;load next char
    inc     esi             ;;move (*format) pointer
    push    eax             ;;push char to be printed in future
    inc     ecx             ;;one more char to be printed 
    cmp     byte al, 0
    je      .print_pushed_chars ;;if EOL (incorrect format sequence) => print chars

    cmp     byte al, 'l' 
    jne     .print_pushed_chars  ;;(incorrect format sequence) => print chars
    jmp     set_long_flag        ;;'ll' has been encountered
.long_flag_checked:

;;search for "type" specifier
    cmp     byte al, 'd'
    je      type_signed

    cmp     byte al, 'i'
    je      type_signed

    cmp     byte al, 'u'
    je      set_unsigned_flag   ;;set unsign_flag and jump to .unsigned_flag_checked

    cmp     byte al, '%'
    je      print_percent

    ;;'%%' has been checked earlier
    ;;we have not encountered any of available types => error => print chars
    jmp     .print_pushed_chars

.type_checked:
.unsigned_flag_checked:
;;all specifiers are OK, flags and "width" are set => print next number

    jmp     print_next_number
.next_number_printed:
.clear_stack:
    mov     eax, ecx    ;;eax == ecx - number of pushed chars
    mov     ebx, 4      ;;multiplier
    mul     ebx         ;;eax = ecx * 4
    add     esp, eax    ;;restore stack

    pop     eax         ;;unread last character
    dec     esi         ;;move (*format) pointer back
    
    jmp     .read_until_eol
     
;;this label pops chars from the stack(in reverse order)
;;and writes them to room, starting at [edi] (in forward order)
;;and then moves [edi] by the number of printed chars
.print_pushed_chars:
    mov     ebx, ecx                  ;;save number of chars to be printed
    xor     edx, edx                  ;;edx == 1 if we should exit after this loop, else we should go to next char
.loop_print_chars:
    cmp     ecx, 0                    ;;check if there are any chars to be printed
    je      .end_print_pushed_chars   ;;no chars to be printed
    pop     eax                       ;;get next char to be printed(reverse order)
    mov     byte [edi + ecx - 1], al  ;;write char from the end of room(to get forward order)
    dec     ecx                       ;;one less char 
    cmp     byte al, 0                ;;if current char == '\0', then we should exit after printing all chars
    jne     .loop_print_chars
    mov     edx, 1                    ;;set flag about exit
    jmp     .loop_print_chars         ;;and continue to write the rest of bytes 

.end_print_pushed_chars:
    add     edi, ebx                  ;;move (*out) by number of chars which are printed 
    cmp     edx, 0                    ;;if we should continue, then do continue, else end of format string
    je      .read_until_eol

.end_read_until_eol:
;;we have proceed the whole format string
    pop     esi         ;;restore callee-saved registers
    pop     edi
    pop     ebx

    mov     esp, ebp    ;;restore stack
    pop     ebp         ;;restore caller's stack frame
    ret
;;end hw_sprintf
;;--------------------------------------------------------------------------------

print_percent:
    mov     byte [edi], '%'
    inc     edi            ;;move to next (*out)
    mov     byte al, [esi] ;;load next after '%' char
    inc     esi            ;;move (*format)
    push    eax            ;;push char to be printed in future
    inc     ecx            ;;one more char...
    jmp     hw_sprintf.clear_stack

;;these labels are convenient way to set flag if it has been encountered
;;and move pointer to next char properly
set_plus_flag:
    set_flag(plus_flag)
    jmp hw_sprintf.loop_specifiers
    
set_minus_flag:
    set_flag(minus_flag)
    jmp hw_sprintf.loop_specifiers

set_zero_flag:
    set_flag(zero_flag)
    jmp hw_sprintf.loop_specifiers

set_space_flag:
    set_flag(space_flag)
    jmp hw_sprintf.loop_specifiers

type_signed:
    mov     byte al, [esi] ;;load next after 'i\d' char
    inc     esi            ;;move (*format)
    push    eax            ;;push char to be printed in future
    inc     ecx            ;;one more char...
    jmp hw_sprintf.type_checked

set_unsigned_flag:
    set_flag(unsign_flag)
    mov     byte al, [esi] ;;load next after 'u' char
    inc     esi            ;;move (*format)
    push    eax            ;;push char to be printed in future
    inc     ecx            ;;one more char...
    jmp hw_sprintf.unsigned_flag_checked

set_long_flag:
    set_flag(long_flag)
    mov     byte al, [esi] ;;load next after 'l' char
    inc     esi            ;;move (*format)
    push    eax            ;;push char to be printed in future
    inc     ecx            ;;one more char...
    jmp hw_sprintf.long_flag_checked

;;this function determines a kind of number, casts int->int64 (if necessary), 
;;sets flag(neg_flag) and prints as unsigned_int_64
;;--------------------------------------------------------------------------
;;all necessary parameters are already on the stack and in registers
;;next_ptr - number to be printed
;;edx - "width"
;;ebx - flags
print_next_number:          
    ;;save caller-saved registers (before call to print_unsigned_long)
    push    eax
    push    ecx
    push    edx

    push    edx     ;;pass arg 4 "width" to print_unsigned_long
    push    ebx     ;;pass arg 3 flags to print_unsigned_long

    mov     eax, [next_ptr] ;;load address of next number
    mov     ecx, [eax]      ;;ECX == low_32_bits
    add     eax, 4
    mov     [next_ptr], eax ;;move pointer to next 32 bits 

;;determine type of number:
    test_flag(long_flag)
    jnz     .int64

.int32:
    test_flag(unsign_flag)
    jnz     .int32_unsigned

.int32_signed:
    test    ecx, ecx                ;;ecx holds int32
    js      .cast_to_signed_long    ;;is ecx < 0??? 
    jmp     .int32_unsigned         ;;else print it as unsigned int32

.cast_to_signed_long:
    ;;int32 is negative, so let's set high part to 0xfff...fff
    xor     edx, edx    ;;edx - high 32 bits == 00...000
    not     edx         ;;edx == 111...111
    jmp     .int64_signed   ;;print as 64-bits signed

.int32_unsigned:
    push    ecx         ;;pass arg2 low32 bits (the whole number) on the stack
    xor     edx, edx    ;;high part == 0
    push    edx         ;;pass arg1 high32 bits print_unsigned_long  
    jmp     .call_printer   ;;stack now:  (0 : low32_bits : flags : width)

.int64:
    mov     edx, [eax]          ;;edx - high_32_bits
                                ;;ecx - low_32_bits 
    add     eax, 4
    mov     [next_ptr], eax     ;;move pointer to next 32 bits
    test_flag(unsign_flag)
    jnz     .int64_unsigned 

.int64_signed:
    push    ecx         ;;pass low32_bits
    push    edx         ;;pass high32_bits

    test    edx, edx        ;;is number negative? (check high part)
    jns     .call_printer   ;;if no, the just print it

.invert_bits_and_inc:   ;;else do transformation(invert bits and +1)
    pop     edx         ;;pop high32_bits for transform
    pop     ecx         ;;pop low32_bits for transform

    pop     ebx     ;;repush flags with mark-up
    set_flag(neg_flag)  ;;mark number as negative
    push    ebx
                        
    ;;number is in (EDX:ECX)
    not     edx         ;;invert high part
    cmp     ecx, 0      ;;if ecx == 0, then ~ecx = 0xfff...ff => +1 to edx
    je      .low_zeros  
    ;;else just do: (~ecx) + 1, and edx is not changed
    not     ecx
    add     ecx, 1
    push    ecx         ;;pass low_32 bits
    push    edx         ;;pass high_32 bits
    jmp     .call_printer

.low_zeros:
    add     edx, 1      ;;eax is still 0, but edx += 1
    push    ecx         ;;pass low_32_bits
    push    edx         ;;pass high_32_bits
    jmp     .call_printer
    
.int64_unsigned:
    push    ecx             ;;pass arg2 low32 bits
    push    edx             ;;pass arg1 high32 bits
    jmp     .call_printer   

.call_printer:
    call    print_unsigned_long ;;stack before call: high_32_bits : low_32_bits : flags : width
    add     edi, eax    ;;move [edi] on result of print_unsigned_long (length of representation)
    add     esp, 16     ;;clear arguments room (4 arguments were passed)

    ;;restore registers after call
    pop     edx
    pop     ecx
    pop     eax

    jmp hw_sprintf.next_number_printed   ;;go back
;;end print_next_number


;;prints unsigned long with checking flag (neg_flag)
;;args: [high32:low32:flags:width]
print_unsigned_long:
    push    ebp
    mov     ebp, esp

    push    ebx     ;;save callee-saved registers
    push    esi
    push    edi

    mov     edx, [ebp + 8]  ;;most-significant 32 bits: let's call it A
    mov     eax, [ebp + 12] ;;less-significant 32 bits: let's call it B
                            ;;so EDX:EAX == A:B

    xor     ecx, ecx    ;;ECX is length of number in digits
    mov     ebx, 10     ;;divisor
.divide_until_zero:
    mov     esi, eax  ;; save value of EAX==B in ESI
                      ;; EDX:EAX == A:B
    xchg    edx, eax  ;; EDX:EAX == B:A
    xor     edx, edx  ;; EDX:EAX == 0:A
    div     ebx       ;; EDX:EAX == A % 10 : A / 10
    xchg    esi, eax  ;; EDX:EAX == A % 10 : B  and ESI == A / 10
    div     ebx       ;; EDX:EAX == (((A % 10) << 32) + B) % 10 : (((A % 10) << 32) + B) / 10
                      ;; EDX:EAX == (....it's a new digit.....) : (..........remainder......)
    
    ;; DL holds new digit
    add     byte dl, '0'
    mov     byte [edi], dl  ;;write chars in reverse order to [edi]
    inc     edi             ;;move (*out) pointer
    inc     ecx             ;;increment number's length

    mov     edx, esi        ;;EDX:EAX == newEDX:newEAX now

    or      esi, eax        ;;check if (EDX:EAX) == 0
    cmp     esi, 0
    jnz     .divide_until_zero ;;if yes, then stop division 

.after_division:
    mov     ebx, [ebp + 16] ;;flags
    mov     edx, [ebp + 20] ;;width

    test_flag(neg_flag)  ;;if number was negative
    jnz     add_neg_sign 

    test_flag(plus_flag)         ;;if '+' is set
    jnz     process_plus_flag

    test_flag(space_flag)            
    jnz     process_space_flag   ;;if ' ' is set 

.sign_proceed:
;;check the binding, minimal width and filling with zeros:
    ;;ecx holds length of number with possible '+-'
    pop     edi     ;;restore [edi] to beginning of (*out)
    pop     esi     ;;restore [esi] to (*format)
    pop     ebx

    cmp     ecx, edx                        ;;compare actual length with minimal "width"
    jge     .got_reverse_representation     ;;if ECX >= "width", then done, else we should proceed '0' and '-'

    sub     edx, ecx            ;;edx is how much room left free

    ;;if '-' flag is not set, then we should fill the gap:
    test_flag(minus_flag)
    jz      process_fill_gap    ;;we should fill the gap (of size edx) with '0' or ' '

.fill_gap_proceed:

    test_flag(minus_flag)      ;;bind to left?
    jnz     process_minus_flag ;;bind to left if necessary and fill the end with ' '
.minus_flag_proceed:
    add     ecx, edx        ;;complete ecx to be fit to minimal width => ecx is a correct length of representation

.got_reverse_representation:
    ;;now [edi...edi+ecx-1] contains right (but reverse) representation => let's reverse it again

    push    eax      ;;save EAX
    push    ecx      ;;save ECX
    push    esi      ;;save ESI
    push    ebx      ;;save EBX
    push    edx      ;;save EDX

    xor     edx, edx ;;clear room for swaps
    mov     eax, ecx ;;eax := buffer size == (max(actual_length, "width"))
    shr     eax, 1   ;;eax := eax / 2   
                     ;;so eax - number of iterations of swap
    mov     esi, edi ;;esi points to 0-th element
    lea     ebx, [edi + ecx - 1]  ;;ebx points to (n-1)-th element

    ;;make loop to reverse array
    ;;for (i=0...n/2):
    ;;  [i] = [n-1-i]

.loop_reversing:
    ;;do swap via the stack
    mov     byte dl, [esi]
    push    edx
    mov     byte dl, [ebx]
    mov     byte [esi], dl
    pop     edx
    mov     byte [ebx], dl
    ;;[esi] and [ebx] are swapped
    inc     esi     ;;move ESI forward
    dec     ebx     ;;move EBX back
    dec     eax     ;;decrement number of iterations
    cmp     eax, 0
    jne     .loop_reversing

.end_loop_reversing:
    pop     edx      ;;restore EDX
    pop     ebx      ;;restore EBX
    pop     esi      ;;restore ESI
    pop     ecx      ;;restore ECX
    pop     eax      ;;restore EAX

    ;;We have got forward representation!
    mov     eax, ecx    ;;move answer to EAX
    mov     esp, ebp
    pop     ebp
    ret                 ;;return total number of chars printed

add_neg_sign:
    mov     byte [edi], '-'     ;;add '-'
    inc     edi                 ;;move (*out)
    inc     ecx                 ;;increment length of number
    jmp     print_unsigned_long.sign_proceed    ;;go back
;;end add_neg_sign

process_plus_flag:
    test_flag(neg_flag)         ;;if number was negative
    jnz     print_unsigned_long.sign_proceed    ;;'-' is already written => go back
    ;;number is positive, so add '+'
    mov     byte [edi], '+'
    inc     edi
    inc     ecx
    jmp     print_unsigned_long.sign_proceed    ;;go back
;;end process_plus_flag

process_space_flag:   
    test_flag(neg_flag)     ;;if number was negative
    jnz     print_unsigned_long.sign_proceed    ;;'-' is already written => go back
    ;;number is positive, so add ' '
    mov     byte [edi], ' '
    inc     edi
    inc     ecx
    jmp     print_unsigned_long.sign_proceed    ;;go back
;;end process_space_flag

process_fill_gap:
    push    eax             ;;save eax (it will be filling char)
    mov     al, ' '         ;;by default we should fill the gap with ' '
    test_flag(zero_flag)    ;;should we check it with '0'?
    jz      .do_fill        ;;if not, then process
    mov     al, '0'         ;;else change al to '0'

.do_fill:
    push    edx  ;;save EDX == ("width" - actual_length) == size of the gap 
    push    esi  ;;save ESI

    lea     esi, [edi + ecx - 1] ;;esi points to the first position before the gap
                                 ;;[edi...edi+ecx-1]:[edi+ecx...edi+width-1]
                                 ;;_reverse_number__:__________gap__________
.loop_fill:
    cmp     edx, 0  ;;how much zeros left?
    je      .end_loop_fill
    mov     byte [esi + edx], al
    dec     edx
    jmp     .loop_fill
        
.end_loop_fill:

    pop     esi  ;;restore ESI and EDX
    pop     edx
    pop     eax  ;;restore EAX

    ;;if 0 flag is set and sign is presend, we should move the sign
    ;;for example: 00000+10 -> +0000010
    test_flag(zero_flag)
    jz      print_unsigned_long.fill_gap_proceed    ;;if '0' is not set, then exit

    ;;check if sign '+'/'-' is not on the end
    cmp     byte [edi+ecx-1], '+'
    je      .move_sign_to_the_end    

    cmp     byte [edi+ecx-1], '-'
    je      .move_sign_to_the_end

    jmp     print_unsigned_long.fill_gap_proceed ;;go back
.move_sign_to_the_end:
    push    eax
    lea     eax, [edi+ecx-1]
    push    ebx
    mov     byte bl, [eax]
    mov     byte [eax], '0'
    add     eax, edx
    mov     byte [eax], bl 
    pop     ebx
    pop     eax
    jmp     print_unsigned_long.fill_gap_proceed
;;end process_zero_flag

process_minus_flag:
    ;;'-' is set, so we should shift number to the left
    push    esi     ;;save ESI
    push    edx     ;;edx - how much times to shift ("width" - actual_length) == size of the gap
    push    ecx     ;;ecx - length of number
    push    ebx     ;;ebx - for help

    xor     ebx, ebx    ;;room for movable char
    lea     esi, [edi + ecx - 1] ;;which char we do move that time (first before gap)
                                 ;;[edi...edi+ecx-1]:[edi+ecx...edi+width-1]
                                 ;;_reverse_number__:__________gap__________
.loop_move_char:
    mov     byte bl, [esi]
    mov     byte [esi + edx], bl    ;;move char from [esi] to [esi + edx]
    dec     ecx     
    dec     esi                     ;;move pointer to the previous char 
    cmp     ecx, 0  ;;how much chars left to be moved?
    jne     .loop_move_char     ;;we moved all the chars

.end_loop_move_char:
    ;;we moved all the chars, so now we should fill the begginning with spaces
    ;;fill [edi...edi+edx-1] with ' '
    mov     ecx, edx    ;;how much chars to be replaced with ' '
.loop_fill_with_spaces:
    mov     byte [edi + ecx - 1], ' '
    dec     ecx
    jnz     .loop_fill_with_spaces

.end_loop_fill_with_spaces:
    ;;We have got perfect reverse representation!

    pop     ebx     ;;restore helpful registers
    pop     ecx
    pop     edx
    pop     esi
    jmp     print_unsigned_long.minus_flag_proceed  ;;go back
;;end process_minus_flag
