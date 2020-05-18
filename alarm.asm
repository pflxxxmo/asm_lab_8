;Будильник. CTRL/S - установить время, CTRL/X - выгрузить программу из памяти.
.model tiny
.code
.286
org 100h


start:
jmp transit

;;;;;;;;;;;;;;;;;;;
;Резидентная часть;
;;;;;;;;;;;;;;;;;;;
;метка для обнаружения себя в памяти
label_tsr dw 1111h
;Процедура обработки прерывания для вектора 09
vect09_new proc
	pushf
	pusha
	push ds
	push es
	pushf
	call dword ptr cs:[vect09_old] ;вызов старого обработчика
	
;проверяем нажата ли клавиша CTRL (тестируем второй бит состояния клавиатуры)
unload_key:
	mov ah,02     ;
	int 16h
	test al,04h
	jz  iret_l
;если CTRL нажат, проверяем нажатие X или S
	in al,60h     ;в al код последней нажатой клавиши
	cmp al,2Dh    ;проверка на нажатие клавиши X(scan-code)
	je  unload
	cmp al,1Fh    ;проверка на нажатие клавиши S(scan-code)
	je  next_step
	jmp iret_l
	
next_step:
	call next_step_proc
;и прыгаем на конец
	jmp iret_l
	
;выгружаем из памяти: восстанавливаем адреса старых обработчиков прерываний для векторов 09 и 4A
unload:
	mov ax,2509h                          ;установить адрес обработчика прерывания  09
	mov dx,word ptr cs:[vect09_old]       ;offset(крайняя часть до :)
	mov ds,word ptr cs:[vect09_old+2]     ;сегмент(адрес старого прерывания)
	int 21h
	mov ax,254Ah
	mov dx,word ptr cs:[vect4A_old]
	mov ds,word ptr cs:[vect4A_old+2]
	int 21h
	push cs
	pop ds
;настраиваемся на текущий сегмент и выгружаемся
	push cs
	pop  es
	mov ah,49h                            ;освобождаем блок памяти
	int 21h
	
;возвращаемся
iret_l:
	pop es
	pop ds
	popa
	popf                                  ;возвращаем флаги
	iret                                  ;вернуться из прерывания
vect09_new endp

next_step_proc proc
;восстанавливаем адрес старого обработчика прерывания для вектора 09
 	mov ax,2509h
	mov dx,word ptr cs:[vect09_old]
	mov ds,word ptr cs:[vect09_old+2]           ;забываем про старый будильник если он был установлен
	int 21h
	push cs
	pop ds
;устанавливаем текстовый режима дисплея
	mov ah,0
	mov al,3
	int 10h
;выводим сообщение "Текущее время"
	xor si,si
	mov cx,18       ;1cек=18.2 ticks
	call show_msg1
;читаем текущее время из RTC
    mov AH,02h
	int 1Ah
	mov al,ch		;помещаем часы в al
    call show_time	;вызываем процедуру вывода времени
	mov al,':'
	int 29h
    mov al,cl
    call show_time
    mov al,':'
	int 29h
    mov al,dh
    call show_time
;выводим сообщение "Установить будильник на:"
	xor si,si
	mov cx,25      
	call show_msg2
	jmp M1
;обрабатываем ввод времени
;стираем введенные символы
M0:  
    mov al,08h		;в al помещаем код клавиши BACKSPACE
	int 29h      
    mov al,08h
	int 29h      
;вызываем процедуру ввода часов
M1:
	call input_time
    cmp  ax,24h		;проверяем введеное значение для часов
    jge  M0			;если оно больше или равно 24, повторяем ввод
	mov ch,al		;записываем часы в ch
	mov al,':'
	int 29h
    jmp M3
;стираем введенные символы
M2:    
	mov al,08h		;в al помещаем код клавиши BACKSPACE
	int 29h    
	mov al,08h
	int 29h    
;вызываем процедуру ввода минут
M3:  
	call input_time
	cmp  ax,60h		;проверяем введеное значение для минут
    jge  M2			;если оно больше или равно 60, повторяем ввод
	mov cl,al		;записываем минуты в cl
	mov dh,0h		;записываем секунды в dh
	mov ah,6		;функция установки сигнала тревоги (ah-6,ch-часы,cl-минуты,dh-секунды)
	int 1Ah			;завели будильник
;выводим сообщение "Нажмите любую клавишу"
	xor si,si
	mov cx,29
	call show_msg3
;ожидаем нажатие клавишы
	mov ah,0
	int 16h
;восстанавливаем адрес нового обработчика прерывания для вектора 09
	mov ax,2509h
	lea dx,vect09_new
	int 21h
	ret
next_step_proc endp

;Процедуры вывода сообщений
show_msg1 proc
	loop1:
	mov al,msg_time[si]
	mov ah,14    ;0Eh вывод в консоль символа(видеорежим)
	int 10h
	inc si
	loop loop1
	ret
show_msg1 endp

show_msg2 proc
	loop2:
	mov al,msg_set[si]
	mov ah,14       ;0Eh вывод в консоль символа(видеорежим)
	int 10h
	inc si
	loop loop2
	ret
show_msg2 endp

show_msg3 proc
	loop3:
	mov al,msg_anykey[si]
	mov ah,14         ;0Eh вывод в консоль символа(видеорежим)
	int 10h
	inc si
	loop loop3
	ret
show_msg3 endp

;Процедура вывода времени - преобразование числа в десятичный формат
show_time proc
	mov bl,0
	mov bl,al
	shr al,4		;сдвигаем на 4, чтобы получить первую цифру двузначного числа
	and al,0fh		;получаем 16-тиричную цифру
	add al,'0'		;добавляем код нуля для получения символа
	int 29h     	;выводим  цифру
	mov al,bl		;повторяем для второй цифры двузначного числа
	and al,0fh
	add al,'0'
	int 29h
	ret
show_time endp 

;Процедура ввода времени с клавиатуры
input_time proc
	call one_num	;ввод числа десятков
;в AX получаем введенное число
	shl al,4		;сдвиг числа в регистре влево (до десяток)
    push ax
	call one_num	;ввод числа единиц
    mov bx,ax
    pop ax
    add ax,bx		;в результате в ax получаем введенное двузначное число в формате BCD
	ret
input_time endp

;Процедура ввода однозначного числа с клавиатуры
one_num  proc
P:  
	mov ah,00h
	int 16h
	xor ah,ah
	mov bl,al		;копируем для вывода на экран
	sub ax,'0'		;получаем из кода символа число
	jl P			;если результат вычитания отрицательный, возвращаемся
	cmp ax,9		;сверяем с 9
	jg P			;если больше, возвращаемся
;выведем цифру на экран
	push ax
	mov ah,0eh		;функция вывода числа на экран 
	mov al,bl		;введенный символ
	int 10h
	pop ax
	ret
one_num  endp

;Процедура обработки прерывания для вектора 4A
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
	mov ah,07    ;сбросить сигнал RTC, это позволяет вам отменить один сигнал перед установкой другого
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
;Транзитная часть;
;;;;;;;;;;;;;;;;;;
transit:
;получаем адрес программы обработки прерывания для вектора 09
	mov ax,3509h     ;получить адрес обработчика прерывания
	int 21h
;проверяем загружен ли уже резидент
	mov ax,es:[bx-2]
	cmp ax,cs:label_tsr
	je warning_msg
;сохраняем старые значения векторов
	mov word ptr vect09_old,bx
	mov word ptr vect09_old[2],es
;записываем адрес нового обработчика прерывания для вектора 09
	CLI                   ;запрещить прерывание
	mov ax,2509h
	lea dx,vect09_new
	int 21h
	STI                    ;разрешить прерывание
;сбросим сигнал тревоги в RTC
	mov ah,7
    int 1Ah
;получаем адрес программы обработки прерывания для вектора 4A
	mov ax,354Ah
	int 21h
	mov word ptr vect4A_old,bx
	mov word ptr vect4A_old[2],es
;записываем адрес нового обработчика прерывания для вектора 4A
	CLI
	mov ax,254Ah
	lea dx,vect4A_new
	int 21h
	STI
;выгружаем сегмент окружения (PSP)
	mov ah,49h                  ;освободить распределённый блок памяти
	mov es,word ptr cs:[2Ch]
	int 21h
;выводим сообщение о загрузке резидента
hello_msg:
	lea dx,msg_hello
	mov ah,9
	int 21h
;оставляем транзитную часть
	lea dx,transit
	int 27h
	jmp exit
;сообщение о загруженном резиденте
warning_msg:
	lea dx, msg_bye
	mov ah,9
	int 21h
exit:
	mov ax,4C00h
	int 21h
	
	
;;;;;;;;
;Данные;
;;;;;;;;
vect09_old dd ?
vect4A_old dd ?
msg_time db 'Tekushee vremya - ','$'
msg_anykey db 13,10,'Nazhmite lubuju klavishu...','$'
msg_set DB 13,10,'Ustanovit budilnik na: $'
;messages
msg_hello db 'Dlya zavoda budilnika nazhmite CTRL+S, dlya vigruzki nazhmite CTRL+X',13,10,'$'
msg_bye db 'Rezident uzhe zagruzhen!',13,10,'$'
screen_size equ 4000 ;80x25 *2 для символа и атрибута
              
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
