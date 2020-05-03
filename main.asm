.model small
.stack 100h
opseg segment
    retf
opseg ends
.data
    input_string db 256 dup('$')  ;буфер для хранения строки

    stackOfNum dw 256 dup(0)       ;стек в котором хранятся цифры
    lastNumOfstack dw 0           ;последний цифра стека
    stackOfOp db 256 dup(0)        ;стек в котором хранятся операторы
    lastOpOfstack  dw 0            ;последний оператор стека
 
    num_buf dw 0                  ;буффер для хранения
    
    base dw 10                    

    bad_args_msg   db 'Wrong arguments$'
    parse_warn_msg db 'Allowed operators: + - * /.Calculations are only performed with integers.$'
    done_msg       db 10, 13, 'Successful!$'
    endl           db 10, 13, '$'

    op_addr dw 0, 0
    op_epb  dw 0, 0

    addFname db 'add.exe', 0
    subFname db 'sub.exe', 0
    mulFname db 'mul.exe', 0
    divFname db 'div.exe', 0
.code


main:
    mov ax, @data
    mov ds, ax

    mov bl, es:[80h]  
    add bx, 80h          
    mov si, 82h      
    mov di, offset input_string
    
    cmp si, bx
    jbe parse_string 
    jmp bad_arguments
    parse_string:
    
        cmp BYTE PTR es:[si], ' '     ;сравнение байт по адресу es:[si] с пробелом
        je parsed_string              
                                     
        mov al, es:[si]
        mov [di], al      
              
        inc di                       ;смещаем указатели
        inc si                       
    cmp si, bx                       
    jbe parse_string
    
    parsed_string: 
    ;подготовка оверлейновых переменных
    mov ax, @data
    mov es, ax
    mov ax, opseg  
    mov [op_epb], ax 
    mov [op_epb + 2], ax
    mov [op_addr + 2], ax

    call process_string

    ;берётся последняя цифра из стека
    sub lastNumOfstack, 2     
    mov si, offset stackOfNum
    add si, lastNumOfstack
    mov bx, [si]
    mov num_buf, bx
        
    call itoa 

    mov ax, offset done_msg 
    push ax
    call print_str  
    pop ax

    exit:
    mov ax, 4C00h
    int 21h

bad_arguments proc
    mov ax, offset bad_args_msg 
    push ax
    call print_str  
    pop ax
    jmp exit
endp

process_string proc
    mov si, offset input_string  ; в si строка

string_loop:

    mov al, [si]            ;в al элемент по адресу ds:si
    call op_weight          ;задание приоритета операторам
            
    cmp bx, 0               ;
    je parse_digit          ;
            
            
            ;помещение цифр в стек
    mov di, offset stackOfNum
    add di, lastNumOfstack   
    mov cx, num_buf
    mov [di], cx
    mov num_buf, 0 
    add lastNumOfstack, 2  
                        
    call push_operator      ;помещение операторов в стек
    jmp string_loop_inc  
            
parse_digit: 
            ;проверка на цифры  
            
    cmp al, '0'          ;если меньше 0
    jb parse_warn        ;ошибка
            
    cmp al, '9'          ;если больше 9
    ja parse_warn        ;ошибка
                    
    jmp parse_sub        ;преобразовние в число   
parse_warn:
            ;Предупреждение о ошибке символ не является цифрой
    mov bx, offset parse_warn_msg 
    push bx
    call print_str
    jmp exit  
    pop bx
            
            ;преобразовние в число
parse_sub: 
    xor bx, bx
    sub al, '0'
    mov bl, al
    mov ax, num_buf
    mul base
    add ax, bx
    mov num_buf, ax
        
string_loop_inc:
    inc si
    cmp BYTE PTR [si], '$'  ; проверка на конец строки
    jne string_loop         ; если не конец то переход на метку string_loop
        
        ;вставка последнего накопленного числа в стек
    mov di, offset stackOfNum
    add di, lastNumOfstack   
    mov cx, num_buf
    mov [di], cx 
    add lastNumOfstack, 2
        
        ;все операторы из стека
    mov cx, lastOpOfstack
    cmp cx, 0
    jbe process_done
        
pop_all_op:
    call pop_operator
    cmp lastOpOfstack, 0
    ja pop_all_op

process_done:
    ret
endp    

op_weight proc
        ;al - оператор
        ;bx - приоритет 1 и 2
    mov bx, 0

    cmp al, '+'
    je low_weight

    cmp al, '-'
    je low_weight

    cmp al, '*'
    je big_weight

    cmp al, '/'
    je big_weight
    ret

low_weight:
    mov bx, 1
    ret

big_weight:
    mov bx, 2
    ret
endp       
    
push_operator proc   
        ;al - оператор
    push ax
    mov di, offset stackOfOp   ;адрес стека операторов 
    add di, lastOpOfstack     ;
    dec di
parse_opeator_loop:   
            
    pop ax
    push ax
    call op_weight
    push bx
            
    mov al, [di]
    call op_weight
    mov cx, bx
    pop bx
    ;bx - приоритет нового оператора
    ;cx - приоритет оператора из стека
    cmp bx, cx
    ja push_op
            
    ;bx <= cx, забираем из стека и производим вычисления 
    call pop_operator
        
    dec di                        ;уменьшаем стек
    cmp di, offset stackOfOp       
    jae parse_opeator_loop 
        
push_op:                      ;помещаем операторы в стек с наименьшим приоритетом
    pop ax
    mov di, offset stackOfOp
    add di, lastOpOfstack
    mov [di], al
    inc lastOpOfstack
    ret
endp
    
    ;вычисление
pop_operator proc
    pusha
              
    sub lastNumOfstack, 2     
    mov si, offset stackOfNum
    add si, lastNumOfstack
    mov bx, [si]
        
    sub lastNumOfstack, 2 
    sub si, 2
    mov ax, [si] 
        
    dec lastOpOfstack
    mov si, offset stackOfOp
    add si, lastOpOfstack
    mov cl, [si]

        ;подготовка значений 
    push 0             
    push ax
    push bx

        ;подготовка оверлея
    mov bx, offset op_epb
    mov ax, 4B03h
        
    cmp cl, '+'
    je operator_add  
        
    cmp cl, '-'
    je operator_sub
        
    cmp cl, '*'
    je operator_mul
        
    cmp cl, '/'
    je operator_div      

push_result:
        ;загрузка оверлея
    int 21h 

        ;вызов оверлея
    call DWORD PTR op_addr  ;загрузка оверлея как far процедуру

        ;получение значения
    pop bx
    pop ax
    pop ax
        
        ;помещение результата в стек
    mov si, offset stackOfNum
    add si, lastNumOfstack
    mov [si], ax 
    add lastNumOfstack, 2 
        
    popa
    ret
endp   
    
operator_add proc
    mov dx, offset addFname
    jmp push_result  
    popa
    ret
endp 
     
operator_sub proc
    mov dx, offset subFname
    jmp push_result 
    popa
    ret
endp   
    
operator_mul proc
    mov dx, offset mulFname
    jmp push_result 
    popa
    ret
endp   
    
operator_div proc
    mov dx, offset divFname
    jmp push_result 
    popa
    ret
endp


itoa proc  
    mov ax, num_buf
    test ax, ax         ; logical 'and' but without save result(only flags)
    jns oi1             ; if number < 0 print '-' and its abs
    mov cx, ax
    mov ah, 02h
    mov dl, '-'
    int 21h
    mov ax, cx
    neg ax
oi1:
    xor cx, cx
    mov bx, base ; for decimal numbers
oi2:
    xor dx,dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz oi2
    mov ah, 02h
oi3:
    pop dx
    add dl, '0'
    int 21h
    loop oi3
    ret
endp         


print_str proc     
    push bp
    mov bp, sp   
    pusha 
        
    mov dx, [ss:bp+4]     
    mov ax, 0900h
    int 21h 
        
    mov dx, offset endl
    mov ax, 0900h
    int 21h  
        
    popa
    pop bp      
    ret
endp  
end main