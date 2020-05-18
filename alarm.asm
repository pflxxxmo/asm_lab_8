;���������. CTRL/S - ���������� �����, CTRL/X - ��������� ��������� �� ������.
.model tiny
.code
.286
org 100h


start:
jmp transit

;;;;;;;;;;;;;;;;;;;
;����������� �����;
;;;;;;;;;;;;;;;;;;;


;��������� ��������� ���������� ��� ������� 09
vect09_new proc
	pushf
	pusha
	push ds
	push es
	pushf
	call dword ptr cs:[vect09_old] ;����� ������� �����������
	
;��������� ������ �� ������� CTRL (��������� ������ ��� ��������� ����������)
unload_key:
	mov ah,02     ;
	int 16h
	test al,04h
	jz  iret_l
;���� CTRL �����, ��������� ������� X ��� S
	in al,60h     ;� al ��� ��������� ������� �������
	cmp al,2Dh    ;�������� �� ������� ������� X(scan-code)
	je  unload
	cmp al,1Fh    ;�������� �� ������� ������� S(scan-code)
	je  next_step
	jmp iret_l
	
next_step:
	call next_step_proc
;� ������� �� �����
	jmp iret_l
	
;��������� �� ������: ��������������� ������ ������ ������������ ���������� ��� �������� 09 � 4A
unload:
	mov ax,2509h                          ;���������� ����� ����������� ����������  09
	mov dx,word ptr cs:[vect09_old]       ;offset(������� ����� �� :)
	mov ds,word ptr cs:[vect09_old+2]     ;�������(����� ������� ����������)
	int 21h
	mov ax,254Ah
	mov dx,word ptr cs:[vect4A_old]
	mov ds,word ptr cs:[vect4A_old+2]
	int 21h
	push cs
	pop ds
;������������� �� ������� ������� � �����������
	push cs
	pop  es
	mov ah,49h                            ;����������� ���� ������
	int 21h
	
;������������
iret_l:
	pop es
	pop ds
	popa
	popf                                  ;���������� �����
	iret                                  ;��������� �� ����������
vect09_new endp

next_step_proc proc
;��������������� ����� ������� ����������� ���������� ��� ������� 09
 	mov ax,2509h
	mov dx,word ptr cs:[vect09_old]
	mov ds,word ptr cs:[vect09_old+2]           ;�������� ��� ������ ��������� ���� �� ��� ����������
	int 21h
	push cs
	pop ds
;������������� ��������� ������ �������
	mov ah,0
	mov al,3
	int 10h
;������� ��������� "������� �����"
	xor si,si
	mov cx,18       ;1c��=18.2 ticks
	call show_msg1
;������ ������� ����� �� RTC
    mov AH,02h
	int 1Ah
	mov al,ch		;�������� ���� � al
    call show_time	;�������� ��������� ������ �������
	mov al,':'
	int 29h
    mov al,cl
    call show_time
    mov al,':'
	int 29h
    mov al,dh
    call show_time
;������� ��������� "���������� ��������� ��:"
	xor si,si
	mov cx,25      
	call show_msg2
	jmp M1
;������������ ���� �������
;������� ��������� �������
M0:  
    mov al,08h		;� al �������� ��� ������� BACKSPACE
	int 29h      
    mov al,08h
	int 29h      
;�������� ��������� ����� �����
M1:
	call input_time
    cmp  ax,24h		;��������� �������� �������� ��� �����
    jge  M0			;���� ��� ������ ��� ����� 24, ��������� ����
	mov ch,al		;���������� ���� � ch
	mov al,':'
	int 29h
    jmp M3
;������� ��������� �������
M2:    
	mov al,08h		;� al �������� ��� ������� BACKSPACE
	int 29h    
	mov al,08h
	int 29h    
;�������� ��������� ����� �����
M3:  
	call input_time
	cmp  ax,60h		;��������� �������� �������� ��� �����
    jge  M2			;���� ��� ������ ��� ����� 60, ��������� ����
	mov cl,al		;���������� ������ � cl
	mov dh,0h		;���������� ������� � dh
	mov ah,6		;������� ��������� ������� ������� (ah-6,ch-����,cl-������,dh-�������)
	int 1Ah			;������ ���������
;������� ��������� "������� ����� �������"
	xor si,si
	mov cx,29
	call show_msg3
;������� ������� �������
	mov ah,0
	int 16h
;��������������� ����� ������ ����������� ���������� ��� ������� 09
	mov ax,2509h
	lea dx,vect09_new
	int 21h
	ret
next_step_proc endp

;��������� ������ ���������
show_msg1 proc
	loop1:
	mov al,msg_time[si]
	mov ah,14    ;0Eh ����� � ������� �������(����������)
	int 10h
	inc si
	loop loop1
	ret
show_msg1 endp

show_msg2 proc
	loop2:
	mov al,msg_set[si]
	mov ah,14       ;0Eh ����� � ������� �������(����������)
	int 10h
	inc si
	loop loop2
	ret
show_msg2 endp

show_msg3 proc
	loop3:
	mov al,msg_anykey[si]
	mov ah,14         ;0Eh ����� � ������� �������(����������)
	int 10h
	inc si
	loop loop3
	ret
show_msg3 endp

;��������� ������ ������� - �������������� ����� � ���������� ������
show_time proc
	mov bl,0
	mov bl,al
	shr al,4		;�������� �� 4, ����� �������� ������ ����� ����������� �����
	and al,0fh		;�������� 16-�������� �����
	add al,'0'		;��������� ��� ���� ��� ��������� �������
	int 29h     	;�������  �����
	mov al,bl		;��������� ��� ������ ����� ����������� �����
	and al,0fh
	add al,'0'
	int 29h
	ret
show_time endp 

;��������� ����� ������� � ����������
input_time proc
	call one_num	;���� ����� ��������
;� AX �������� ��������� �����
	shl al,4		;����� ����� � �������� ����� (�� �������)
    push ax
	call one_num	;���� ����� ������
    mov bx,ax
    pop ax
    add ax,bx		;� ���������� � ax �������� ��������� ���������� ����� � ������� BCD
	ret
input_time endp

;��������� ����� ������������ ����� � ����������
one_num  proc
P:  
	mov ah,00h
	int 16h
	xor ah,ah
	mov bl,al		;�������� ��� ������ �� �����
	sub ax,'0'		;�������� �� ���� ������� �����
	jl P			;���� ��������� ��������� �������������, ������������
	cmp ax,9		;������� � 9
	jg P			;���� ������, ������������
;������� ����� �� �����
	push ax
	mov ah,0Eh		;������� ������ ����� �� ����� 
	mov al,bl		;��������� ������
	int 10h
	pop ax
	ret
one_num  endp

;��������� ��������� ���������� ��� ������� 4A
vect4A_new proc
	pushf
	pusha
	push ds
	push es
    call banner
	mov ah,0
	int 16h
	mov ax, 0003h
	int 10h
	mov ah,07    ;�������� ������ RTC, ��� ��������� ��� �������� ���� ������ ����� ���������� �������
	int 1ah
iret_l2:
	pop es
	pop ds
	popa
	popf
	iret
vect4A_new endp

banner proc
    pusha
    push es
    push 0B800h
    pop es

    ;fill blue
    xor di, di       
    fill_screen_loop:         
    
        mov BYTE PTR es:[di], ' '
        mov BYTE PTR es:[di + 1], 00010111b       
            
    add di, 2
    cmp di, screen_size
    jl fill_screen_loop

    xor di, di
    xor si, si      
    draw_banner_loop:         

        mov bh, cs:[banner_text + si]
        mov BYTE PTR es:[di], bh
        mov BYTE PTR es:[di + 1], 00010111b       

        add si, 1        
        add di, 2
        cmp si, banner_size
    jl draw_banner_loop

    pop es
    popa
    ret
banner endp

;;;;;;;;;;;;;;;;;;
;���������� �����;
;;;;;;;;;;;;;;;;;;
transit:
;�������� ����� ��������� ��������� ���������� ��� ������� 09
	mov ax,3509h     ;�������� ����� ����������� ����������
	int 21h
;��������� �������� �� ��� ��������
	mov ax,es:[bx-2]
	cmp ax,cs:label_tsr
	je warning_msg
;��������� ������ �������� ��������
	mov word ptr vect09_old,bx
	mov word ptr vect09_old[2],es
;���������� ����� ������ ����������� ���������� ��� ������� 09
	CLI                   ;��������� ����������
	mov ax,2509h
	lea dx,vect09_new
	int 21h
	STI                    ;��������� ����������
;������� ������ ������� � RTC
	mov ah,7
    int 1Ah
;�������� ����� ��������� ��������� ���������� ��� ������� 4A
	mov ax,354Ah
	int 21h
	mov word ptr vect4A_old,bx
	mov word ptr vect4A_old[2],es
;���������� ����� ������ ����������� ���������� ��� ������� 4A
	CLI
	mov ax,254Ah
	lea dx,vect4A_new
	int 21h
	STI
;��������� ������� ��������� (PSP)
	mov ah,49h                  ;���������� ������������� ���� ������
	mov es,word ptr cs:[2Ch]
	int 21h
;������� ��������� � �������� ���������
hello_msg:
	lea dx,msg_hello
	mov ah,9
	int 21h
;��������� ���������� �����
	lea dx,transit
	int 27h
	jmp exit
;��������� � ����������� ���������
warning_msg:
	lea dx, msg_bye
	mov ah,9
	int 21h
exit:
	mov ax,4C00h
	int 21h
	
	
;;;;;;;;
;������;
;;;;;;;;
;����� ��� ����������� ���� � ������
label_tsr dw 4376h
vect09_old dd ?
vect4A_old dd ?
msg_time db 'Tekushee vremya - ','$'
msg_anykey db 13,10,'Nazhmite lubuju klavishu...','$'
msg_set DB 13,10,'Ustanovit budilnik na: $'
;messages
msg_hello db 'Dlya zavoda budilnika nazhmite CTRL+S, dlya vigruzki nazhmite CTRL+X',13,10,'$'
msg_bye db 'Rezident uzhe zagruzhen!',13,10,'$'
screen_size equ 4000 ;80x25 *2 ��� ������� � ��������
              
banner_text   db  '                                                                                '        
              db  '      ___           ___       ___           ___           ___                   '    
              db  '     /\  \         /\__\     /\  \         /\  \         /\__\                  '
              db  '    /::\  \       /:/  /    /::\  \       /::\  \       /::|  |                 '
              db  '   /:/\:\  \     /:/  /    /:/\:\  \     /:/\:\  \     /:|:|  |                 '
              db  '  /::\~\:\  \   /:/  /    /::\~\:\  \   /::\~\:\  \   /:/|:|__|__               '
              db  ' /:/\:\ \:\__\ /:/__/    /:/\:\ \:\__\ /:/\:\ \:\__\ /:/ |::::\__\              '
              db  ' \/__\:\/:/  / \:\  \    \/__\:\/:/  / \/_|::\/:/  / \/__/~~/:/  /              '
              db  '      \::/  /   \:\  \        \::/  /     |:|::/  /        /:/  /               '
              db  '      /:/  /     \:\  \       /:/  /      |:|\/__/        /:/  /                '
              db  '     /:/  /       \:\__\     /:/  /       |:|  |         /:/  /                 '
              db  '     \/__/         \/__/     \/__/         \|__|         \/__/                  '             
                                                                                                   
banner_height equ 12
banner_size equ 80 * banner_height
	
end start