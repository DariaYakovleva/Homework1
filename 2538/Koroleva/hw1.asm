%define FLAG_PLUS 1
%define FLAG_SPACE 2
%define FLAG_MINUS 4
%define FLAG_ZERO 8
%define FLAG_LONG_LONG 16
%define FLAG_SIGN 32


section .text
global hw_sprintf

write_unsigned:
	push ebp
	mov ebp, esp

	mov ecx, edi

	mov edi, ebp  ;указатель на начало чиселка
	sub esp, 24   ;выделяем для чиселка память на стеке. 24 байта 
	push esi
	push ecx

	mov ebx, [ebp + 16] ;флажки
	mov esi, [ebp + 8] ;указатель на начало аргументов
	mov ecx, 10   ;база системы счисления

	test ebx, FLAG_LONG_LONG
	jnz .long

	mov eax, [esi]
	add esi, 4

.loop
	mov edx, 0
	div ecx
	add edx, '0'
	dec edi
	mov byte[edi], dl
	cmp eax, 0
	jne .loop
	jmp .flag_plus

.long
	mov eax, [esi]	    ;младшие биты чиселка
	add esi, 4          
	mov edx, [esi]      ;старшие биты чиселка
	push esi

.long_loop
	push eax           
	mov eax, edx
	mov edx, 0
	div ecx
	mov esi, eax
	pop eax
	div ecx	
	add edx, '0'
	dec edi
	mov byte[edi], dl
	mov edx, esi
	
	cmp edx, 0
	jne .long_loop
	pop esi
	jmp .loop
	
.flag_plus
	test ebx, FLAG_PLUS
	jz .flag_space
	test ebx, FLAG_SIGN
	jnz .set_minus
	mov cl, '+'
	dec edi
	mov byte[edi], cl
	jmp .write

.set_minus
	mov cl, '-'
	dec edi
	mov byte[edi], cl

	jmp .write

.flag_space
	test ebx, FLAG_SPACE
	jz .write
	mov cl, ' '
	dec edi
	mov byte[edi], cl

.write
	mov eax, edi
	pop edi

	mov ecx, [ebp + 12]
	mov edx, ebp
	sub edx, eax

	cmp ecx, edx
	jle .write_loop

	sub ecx, edx
	test ebx, FLAG_MINUS
	jnz .write_loop

	test ebx, FLAG_ZERO
	jz .prev_loop

.prev_loop_zero
	mov dl, '0'
	mov byte[edi], dl
	inc edi
	dec ecx
	cmp ecx, 0
	jne .prev_loop_zero
	jmp .write_loop

.prev_loop
	mov dl, ' '
	mov byte[edi], dl
	inc edi
	dec ecx
	cmp ecx, 0
	jne .prev_loop

.write_loop
	mov dl, byte[eax]
	mov byte[edi], dl
	inc edi
	inc eax
	cmp eax, ebp
	jne .write_loop

	test ebx, FLAG_MINUS
	jz .ret
.minus_loop
	mov dl, ' '
	mov byte[edi], dl
	inc edi
	dec ecx
	cmp ecx, 0
	jne .minus_loop

.ret
	mov eax, esi
	pop esi 

	mov esp, ebp
	pop ebp
	ret

write_signed:
	push ebp
	mov ebp, esp

	mov ebx, [ebp + 16]
	mov ecx, [ebp + 8]

	test ebx, FLAG_LONG_LONG
	jnz .long

	mov eax, [ecx]
	bt eax, 31
	jnc .calling
	mov edx, ~0
	jmp .set_minus

.long
	mov eax, [ecx]
	add ecx, 4
	mov edx, [ecx]
	sub ecx, 4
	bt edx, 31
	jnc .calling

.set_minus
	not edx
	not eax
	add eax, 1
	adc edx, 0
	or ebx, FLAG_SIGN

	mov [ecx], eax
	test ebx, FLAG_LONG_LONG
	jz .calling

	add ecx, 4
	mov [ecx], edx
	sub ecx, 4

.calling
	mov edx, [ebp + 12]
	push ebx
	push edx
	push ecx
	call write_unsigned
	pop ecx
	pop edx
	pop ebx
.ret
	pop ebp
	ret

;int string_to_int();
;read string at esi from current symbol, while there are digits 
;and convert to int
;result is writing to eax
string_to_int:
	push ebp
	mov ebp, esp
	mov eax, 0

.loop
	cmp cl, '0'
	jl .ret
	cmp cl, '9'
	jg .ret

	mov ebx, 10
	mul ebx
	sub cl, '0'
	add al, cl

	mov cl, byte[esi]
	inc esi

	jmp .loop

.ret
	pop ebp
	ret	

;write symbols from eax to esi
write_to_out:
	push ebp
	mov ebp, esp
.loop
	mov cl, byte[eax]
	mov byte[edi], cl
	inc eax
	inc edi

	cmp eax, esi
	jne .loop

	pop ebp
	ret

hw_sprintf:
	push ebp
	mov ebp, esp

	mov edi, [ebp + 8]
	mov esi, [ebp + 12]
	lea edx, [ebp + 16]
	mov eax, esi

.loop
	mov ebx, 0
	mov cl, byte[esi]

	cmp cl, 0
	je .ret
	inc esi
	
	push eax

	cmp cl, '%'
	jne .no_format

.format
	mov cl, byte[esi]
	inc esi

	cmp cl, '+'
	jne .space
	or ebx, FLAG_PLUS
	jmp .format

.space
	cmp cl, ' '
	jne .minus
	or ebx, FLAG_SPACE
	jmp .format

.minus 
	cmp cl, '-'
	jne .zero
	or ebx, FLAG_MINUS
	jmp .format

.zero
	cmp cl, '0'
	jne .width
	or ebx, FLAG_ZERO
	jmp .format

.width
	push ebx
	push edx
	call string_to_int
	pop edx
	pop ebx

.size
	cmp cl, 'l'
	jne .type

	mov cl, byte[esi]
	inc esi
	cmp cl, 'l'
	jne .no_format

	or ebx, FLAG_LONG_LONG
	mov cl, byte[esi]
	inc esi

.type
	cmp cl, 'i'
	je .signed

	cmp cl, 'd'
	je .signed

	cmp cl, 'u'
	je .unsigned

	cmp cl, '%'
	je .percent
	jmp .no_format	
	
.signed
	push ebx
	push eax
	push edx
	call write_signed
	pop edx
	mov edx, eax
	pop eax
	pop ebx

	pop eax
	mov eax, esi

	jmp .loop

.unsigned
	push ebx
	push eax
	push edx
	call write_unsigned	
	pop edx
	mov edx, eax
	pop eax
	pop ebx
	

	pop eax ; pointer to string
	mov eax, esi
	jmp .loop

.percent
	;it works!
	mov byte[edi], cl
	inc edi
	pop eax
	mov eax, esi

	jmp .loop	

.no_format
	pop eax
	call write_to_out
	jmp .loop
	
.ret
	mov byte[edi], cl
	inc edi
	pop ebp
	ret



